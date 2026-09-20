import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import 'biometrics_service.dart';
import '../database/preferences_service.dart';

enum AuthStatus {
  guest,
  localAuthenticated,
  firebaseAuthenticated,
  officiallyVerified,
}

class AuthService {
  static const String _keyCurrentUser = 'auth_current_user';
  static const String _keyRegisteredUsers = 'auth_registered_users';
  static const String _keyLastKnownUser = 'auth_last_known_user';

  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static AuthStatus? _overrideAuthStatus;

  @visibleForTesting
  static void setAuthStatusForTesting(AuthStatus? status) {
    _overrideAuthStatus = status;
  }

  @visibleForTesting
  static void setCurrentUserForTesting(UserModel? user) {
    _currentUser = user;
  }

  /// Categorized authentication status of the current session
  static AuthStatus get authStatus {
    if (_overrideAuthStatus != null) return _overrideAuthStatus!;
    final user = _currentUser;
    if (user == null) {
      return AuthStatus.guest;
    }
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser != null) {
      if (fbUser.emailVerified) {
        return AuthStatus.officiallyVerified;
      }
      return AuthStatus.firebaseAuthenticated;
    }
    return AuthStatus.localAuthenticated;
  }

  /// Strict rule: Official requests can only be submitted if authenticated via Firebase or officially verified.
  /// Local authentication (offline mode) is NOT allowed for official requests.
  static bool get canSubmitOfficialRequest =>
      authStatus == AuthStatus.firebaseAuthenticated ||
      authStatus == AuthStatus.officiallyVerified;

  /// Cryptographic SHA-256 password hasher with salt for secure offline storage
  static String _hashPassword(String password, String email) {
    const salt = 'ZakatApp_SecuredSalt_2025_#';
    final bytes = utf8.encode('$salt:${email.trim().toLowerCase()}:$password');
    return sha256.convert(bytes).toString();
  }

  static UserModel? _currentUser;
  static UserModel? get currentUser => _currentUser;

  static UserModel? _lastKnownUser;
  static UserModel? get lastKnownUser => _lastKnownUser;

  /// Returns true if an account was previously registered or logged in on this device
  static bool get hasRegisteredAccount => _lastKnownUser != null;

  /// Returns true if currently authenticated with Firebase
  static bool get isFirebaseAuthenticated => _firebaseAuth.currentUser != null;

  /// Validates that a name is a legitimate user full name and NOT:
  /// - null or empty
  /// - a placeholder like 'مستخدم البصمة', 'المستخدم', 'المستخدم الكريم', 'مستخدم زكاتي'
  /// - an email address (contains '@')
  /// - an email prefix matching the user's email (e.g. 'taha' for 'taha@gmail.com')
  static String? _cleanName(String? name, [String? email]) {
    if (name == null) return null;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
    // Reject generic/placeholder names
    if (lower == 'مستخدم البصمة' ||
        lower == 'المستخدم الكريم' ||
        lower == 'المستخدم' ||
        lower == 'مستخدم زكاتي' ||
        lower == 'مستخدم الهيئة' ||
        lower == 'user' ||
        lower == 'guest') {
      return null;
    }

    // Reject if it's an email address
    if (trimmed.contains('@')) {
      return null;
    }

    // Reject if it equals the email's prefix
    if (email != null && email.contains('@')) {
      final prefix = email.split('@').first.trim().toLowerCase();
      if (lower == prefix) {
        return null;
      }
    }

    return trimmed;
  }

  /// Helper to find user from local registry by email or latest
  static UserModel? _findUserInRegistry(SharedPreferences prefs, [String? email]) {
    try {
      final usersJson = prefs.getString(_keyRegisteredUsers);
      if (usersJson == null) return null;
      final List<dynamic> users = jsonDecode(usersJson);
      if (users.isEmpty) return null;

      if (email != null && email.trim().isNotEmpty) {
        final normalized = email.trim().toLowerCase();
        final match = users.firstWhere(
          (u) => (u['email'] as String?)?.trim().toLowerCase() == normalized,
          orElse: () => null,
        );
        if (match != null) {
          final candidate = UserModel.fromMap(Map<String, dynamic>.from(match));
          final clean = _cleanName(candidate.name, candidate.email);
          if (clean != null) {
            return candidate.copyWith(name: clean);
          }
        }
      }

      // Return the most recently registered user with a valid name
      for (int i = users.length - 1; i >= 0; i--) {
        final u = users[i];
        final candidate = UserModel.fromMap(Map<String, dynamic>.from(u));
        final clean = _cleanName(candidate.name, candidate.email);
        if (clean != null) {
          return candidate.copyWith(name: clean);
        }
      }
    } catch (e) {
      debugPrint('Error finding user in registry: $e');
    }
    return null;
  }

  /// Helper to save user in local registered users list securely
  static Future<void> _saveUserToRegistry(SharedPreferences prefs, UserModel user, [String? password]) async {
    try {
      final usersJson = prefs.getString(_keyRegisteredUsers);
      List<dynamic> users = usersJson != null ? jsonDecode(usersJson) : [];
      final normalizedEmail = user.email.trim().toLowerCase();

      String? existingPasswordHash;
      final existingIdx = users.indexWhere((u) => (u['email'] as String?)?.trim().toLowerCase() == normalizedEmail);
      if (existingIdx != -1) {
        existingPasswordHash = (users[existingIdx]['password_hash'] ?? users[existingIdx]['password']) as String?;
        users.removeAt(existingIdx);
      }

      final map = user.toMap();
      if (password != null && password.isNotEmpty) {
        map['password_hash'] = _hashPassword(password, normalizedEmail);
      } else if (existingPasswordHash != null && existingPasswordHash.isNotEmpty) {
        map['password_hash'] = existingPasswordHash.length == 64 && !existingPasswordHash.contains(' ')
            ? existingPasswordHash
            : _hashPassword(existingPasswordHash, normalizedEmail);
      }
      map.remove('password'); // Purge any plaintext password for security
      users.add(map);
      await prefs.setString(_keyRegisteredUsers, jsonEncode(users));
    } catch (e) {
      debugPrint('Error saving user to registry: $e');
    }
  }

  /// Helper to save user session and persistent last-known profile
  static Future<void> _saveSession(SharedPreferences prefs, UserModel user) async {
    _currentUser = user;
    _lastKnownUser = user;
    final jsonStr = jsonEncode(user.toMap());
    await prefs.setString(_keyCurrentUser, jsonStr);
    await prefs.setString(_keyLastKnownUser, jsonStr);
  }

  /// Get last known user stored on device (persists even after logout)
  static UserModel? _getLastKnownUser(SharedPreferences prefs) {
    try {
      final jsonStr = prefs.getString(_keyLastKnownUser);
      if (jsonStr != null) {
        final user = UserModel.fromMap(Map<String, dynamic>.from(jsonDecode(jsonStr)));
        final clean = _cleanName(user.name, user.email);
        if (clean != null) {
          return user.copyWith(name: clean);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _lastKnownUser = _getLastKnownUser(prefs) ?? _findUserInRegistry(prefs);

    // Check if Firebase already has an active session
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser != null) {
      final email = fbUser.email ?? '';
      String? name = _cleanName(fbUser.displayName, email);

      final regUser = _findUserInRegistry(prefs, email);
      if (name == null && regUser != null) {
        name = _cleanName(regUser.name, email);
      }

      if (name == null) {
        final lastUser = _getLastKnownUser(prefs);
        if (lastUser != null && lastUser.email.toLowerCase() == email.toLowerCase()) {
          name = _cleanName(lastUser.name, email);
        }
      }

      // If we found a clean name from registry but Firebase lacked it, sync it to Firebase
      if (name != null && _cleanName(fbUser.displayName, email) == null) {
        try {
          await fbUser.updateDisplayName(name);
          await fbUser.reload();
        } catch (_) {}
      }

      final user = UserModel(
        id: fbUser.uid,
        name: name ?? 'المستخدم',
        email: email,
        phone: (regUser?.phone.isNotEmpty == true) ? regUser!.phone : (fbUser.phoneNumber ?? '777000111'),
        profileImagePath: regUser?.profileImagePath,
        isBiometricEnabled: regUser?.isBiometricEnabled ?? PreferencesService.isBiometricEnabled,
      );
      await _saveSession(prefs, user);
      return;
    }

    // Load cached session if available
    final userJson = prefs.getString(_keyCurrentUser);
    if (userJson != null) {
      try {
        var user = UserModel.fromMap(Map<String, dynamic>.from(jsonDecode(userJson)));
        if (_cleanName(user.name, user.email) == null) {
          final regUser = _findUserInRegistry(prefs, user.email);
          final cleanName = _cleanName(regUser?.name, user.email) ??
              _cleanName(_getLastKnownUser(prefs)?.name, user.email) ??
              'المستخدم';
          user = user.copyWith(
            name: cleanName,
            phone: regUser?.phone ?? user.phone,
            profileImagePath: regUser?.profileImagePath ?? user.profileImagePath,
          );
          await _saveSession(prefs, user);
        }
        _currentUser = user;
      } catch (_) {
        _currentUser = null;
      }
    }
  }

  /// Sign in with Firebase Authentication (with graceful offline fallback)
  static Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();

    try {
      // 1. Attempt Firebase Authentication
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final fbUser = credential.user;
      String? name = _cleanName(fbUser?.displayName, normalizedEmail);

      final regUser = _findUserInRegistry(prefs, normalizedEmail);
      if (name == null && regUser != null) {
        name = _cleanName(regUser.name, normalizedEmail);
      }

      if (name == null) {
        final lastUser = _getLastKnownUser(prefs);
        if (lastUser != null && lastUser.email.toLowerCase() == normalizedEmail) {
          name = _cleanName(lastUser.name, normalizedEmail);
        }
      }

      // If we recovered a valid name, sync it back to Firebase
      if (name != null && fbUser != null && _cleanName(fbUser.displayName, normalizedEmail) == null) {
        try {
          await fbUser.updateDisplayName(name);
          await fbUser.reload();
        } catch (_) {}
      }

      final resolvedName = name ?? 'المستخدم';
      final phone = (regUser != null && regUser.phone.isNotEmpty)
          ? regUser.phone
          : (fbUser?.phoneNumber ?? '777000111');
      final imagePath = regUser?.profileImagePath;

      final user = UserModel(
        id: fbUser?.uid ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: resolvedName,
        email: fbUser?.email ?? normalizedEmail,
        phone: phone,
        profileImagePath: imagePath,
        isBiometricEnabled: PreferencesService.isBiometricEnabled,
      );

      await _saveSession(prefs, user);
      await _saveUserToRegistry(prefs, user, password);
      await PreferencesService.setSavedEmail(normalizedEmail);

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException on signIn: ${e.code} - ${e.message}');
      if (e.code == 'user-not-found') {
        throw Exception('لم يتم العثور على حساب مسجل بهذا البريد الإلكتروني');
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('كلمة المرور غير صحيحة');
      } else if (e.code == 'invalid-email') {
        throw Exception('صيغة البريد الإلكتروني غير صحيحة');
      } else if (e.code == 'user-disabled') {
        throw Exception('تم تعطيل هذا الحساب من قبل الإدارة');
      }

      // If network issue, fallback to local registered database
      return await _fallbackLocalSignIn(email: normalizedEmail, password: password, prefs: prefs);
    } catch (e) {
      debugPrint('General error on signIn, attempting local fallback: $e');
      return await _fallbackLocalSignIn(email: normalizedEmail, password: password, prefs: prefs);
    }
  }

  /// Register / Sign up with Firebase Authentication
  static Future<UserModel?> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? profileImagePath,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final prefs = await SharedPreferences.getInstance();

    try {
      // 1. Attempt Firebase Authentication Registration
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser != null) {
        await fbUser.updateDisplayName(cleanName);
        await fbUser.reload();
      }

      final user = UserModel(
        id: fbUser?.uid ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: cleanName,
        email: normalizedEmail,
        phone: phone.trim(),
        profileImagePath: profileImagePath,
        isBiometricEnabled: true,
      );

      await _saveUserToRegistry(prefs, user, password);
      await _saveSession(prefs, user);
      await PreferencesService.setSavedEmail(normalizedEmail);

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException on signUp: ${e.code} - ${e.message}');
      if (e.code == 'email-already-in-use') {
        throw Exception('هذا البريد الإلكتروني مسجل مسبقاً في Firebase');
      } else if (e.code == 'weak-password') {
        throw Exception('كلمة المرور ضعيفة جداً، يرجى اختيار كلمة مرور أقوى');
      } else if (e.code == 'invalid-email') {
        throw Exception('صيغة البريد الإلكتروني غير صحيحة');
      }

      // Fallback local registration if network unreachable
      return await _fallbackLocalSignUp(
        name: cleanName,
        email: normalizedEmail,
        phone: phone,
        password: password,
        prefs: prefs,
        profileImagePath: profileImagePath,
      );
    } catch (e) {
      debugPrint('General error on signUp, attempting local fallback: $e');
      return await _fallbackLocalSignUp(
        name: cleanName,
        email: normalizedEmail,
        phone: phone,
        password: password,
        prefs: prefs,
        profileImagePath: profileImagePath,
      );
    }
  }

  /// Sign In with Biometrics (Local Authentication)
  static Future<UserModel?> signInWithBiometrics({String? hintEmail}) async {
    final bool isAvailable = await BiometricsService.isBiometricsAvailable();
    if (!isAvailable) {
      throw Exception('جهازك لا يدعم المصادقة بالبصمة أو لم يتم تفعيلها في إعدادات النظام');
    }

    final prefs = await SharedPreferences.getInstance();

    // Determine candidate user registered on this device
    final emailCandidate = (hintEmail != null && hintEmail.trim().isNotEmpty)
        ? hintEmail.trim().toLowerCase()
        : PreferencesService.savedEmail.trim().toLowerCase();

    UserModel? candidateUser;
    if (emailCandidate.isNotEmpty) {
      candidateUser = _findUserInRegistry(prefs, emailCandidate);
    }
    candidateUser ??= _getLastKnownUser(prefs);
    candidateUser ??= _findUserInRegistry(prefs);

    if (candidateUser == null) {
      throw Exception('لا يوجد حساب مسجل على هذا الجهاز، يرجى تسجيل الدخول بالبريد أولاً لتمكين الدخول بالبصمة');
    }

    final cleanName = _cleanName(candidateUser.name, candidateUser.email) ?? 'المستخدم';

    final bool authenticated = await BiometricsService.authenticate(
      localizedReason: 'يرجى المصادقة بالبصمة للدخول لتطبيق الهيئة العامة للزكاة كـ $cleanName',
    );

    if (!authenticated) {
      return null;
    }

    final user = candidateUser.copyWith(
      name: cleanName,
      isBiometricEnabled: true,
    );

    await _saveSession(prefs, user);
    await PreferencesService.setSavedEmail(user.email);
    return user;
  }

  /// Update user profile name and/or phone
  static Future<UserModel?> updateProfile({
    required String name,
    String? phone,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return _currentUser;

    final prefs = await SharedPreferences.getInstance();

    // 1. Update Firebase display name if logged in
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser != null) {
      try {
        await fbUser.updateDisplayName(cleanName);
        await fbUser.reload();
      } catch (e) {
        debugPrint('Error updating Firebase displayName: $e');
      }
    }

    // 2. Update current or create active session
    final updated = (_currentUser ??
        _getLastKnownUser(prefs) ??
        UserModel(
          id: fbUser?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
          name: cleanName,
          email: fbUser?.email ?? PreferencesService.savedEmail,
          phone: phone?.trim() ?? '777000111',
        )).copyWith(
      name: cleanName,
      phone: phone?.trim() ?? _currentUser?.phone,
    );

    await _saveSession(prefs, updated);
    await _saveUserToRegistry(prefs, updated);

    return updated;
  }

  /// Update user profile photo path
  static Future<UserModel?> updateProfileImage(String? imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    final user = _currentUser ?? _getLastKnownUser(prefs);
    if (user == null) return null;

    final updated = user.copyWith(profileImagePath: imagePath);
    await _saveSession(prefs, updated);
    await _saveUserToRegistry(prefs, updated);

    return updated;
  }

  static Future<void> updateBiometricPreference(bool enabled) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(isBiometricEnabled: enabled);
      final prefs = await SharedPreferences.getInstance();
      await _saveSession(prefs, _currentUser!);
      await _saveUserToRegistry(prefs, _currentUser!);
    }
  }

  /// Sign out from Firebase and clear active session (preserves last-known user profile)
  static Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}
    _currentUser = null;
    _overrideAuthStatus = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
    // Note: _keyLastKnownUser is kept intentionally so biometrics can restore the user
  }

  // --- Local Fallback Helpers ---
  static Future<UserModel?> _fallbackLocalSignIn({
    required String email,
    required String password,
    required SharedPreferences prefs,
  }) async {
    final usersJson = prefs.getString(_keyRegisteredUsers);
    List<dynamic> users = usersJson != null ? jsonDecode(usersJson) : [];
    final normalizedEmail = email.trim().toLowerCase();

    final existingUserMap = users.firstWhere(
      (u) => (u['email'] as String?)?.toLowerCase() == normalizedEmail,
      orElse: () => null,
    );

    if (existingUserMap != null) {
      final inputHash = _hashPassword(password, normalizedEmail);
      final storedHash = existingUserMap['password_hash'] as String?;
      final legacyPassword = existingUserMap['password'] as String?;

      final bool isMatch = (storedHash != null && storedHash == inputHash) ||
          (legacyPassword != null && legacyPassword == password);

      if (!isMatch) {
        throw Exception('كلمة المرور غير صحيحة');
      }

      // Automatically migrate legacy plaintext password to secure hash
      if (legacyPassword != null) {
        existingUserMap['password_hash'] = inputHash;
        existingUserMap.remove('password');
        await prefs.setString(_keyRegisteredUsers, jsonEncode(users));
      }

      final candidate = UserModel.fromMap(Map<String, dynamic>.from(existingUserMap));
      final clean = _cleanName(candidate.name, candidate.email) ?? 'المستخدم';
      final user = candidate.copyWith(name: clean);
      await _saveSession(prefs, user);
      await PreferencesService.setSavedEmail(user.email);
      return user;
    }

    throw Exception('لم يتم العثور على حساب مسجل محلياً بهذا البريد');
  }

  static Future<UserModel?> _fallbackLocalSignUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required SharedPreferences prefs,
    String? profileImagePath,
  }) async {
    final usersJson = prefs.getString(_keyRegisteredUsers);
    List<dynamic> users = usersJson != null ? jsonDecode(usersJson) : [];

    final exists = users.any((u) => (u['email'] as String?)?.toLowerCase() == email.toLowerCase());
    if (exists) {
      throw Exception('هذا البريد الإلكتروني مسجل مسبقاً');
    }

    final user = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      email: email,
      phone: phone.trim(),
      profileImagePath: profileImagePath,
      isBiometricEnabled: true,
    );

    await _saveUserToRegistry(prefs, user, password);
    await _saveSession(prefs, user);
    await PreferencesService.setSavedEmail(email);
    return user;
  }
}
