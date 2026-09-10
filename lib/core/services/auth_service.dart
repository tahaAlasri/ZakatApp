import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import 'biometrics_service.dart';

class AuthService {
  static const String _keyCurrentUser = 'auth_current_user';
  static const String _keyRegisteredUsers = 'auth_registered_users';

  static UserModel? _currentUser;
  static UserModel? get currentUser => _currentUser;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyCurrentUser);
    if (userJson != null) {
      try {
        _currentUser = UserModel.fromMap(jsonDecode(userJson));
      } catch (_) {
        _currentUser = null;
      }
    }
  }

  static Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    // Simulated network delay for realism
    await Future.delayed(const Duration(milliseconds: 600));

    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_keyRegisteredUsers);
    List<dynamic> users = usersJson != null ? jsonDecode(usersJson) : [];

    // Find user by email
    final existingUserMap = users.firstWhere(
      (u) => u['email'] == email.trim().toLowerCase(),
      orElse: () => null,
    );

    UserModel user;
    if (existingUserMap != null) {
      if (existingUserMap['password'] != password) {
        throw Exception('كلمة المرور غير صحيحة');
      }
      user = UserModel.fromMap(existingUserMap);
    } else {
      // Default demo login or auto-register if first time
      user = UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: email.split('@').first,
        email: email.trim().toLowerCase(),
        phone: '777000111',
      );
      users.add({...user.toMap(), 'password': password});
      await prefs.setString(_keyRegisteredUsers, jsonEncode(users));
    }

    _currentUser = user;
    await prefs.setString(_keyCurrentUser, jsonEncode(user.toMap()));
    return user;
  }

  static Future<UserModel?> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_keyRegisteredUsers);
    List<dynamic> users = usersJson != null ? jsonDecode(usersJson) : [];

    final normalizedEmail = email.trim().toLowerCase();
    final exists = users.any((u) => u['email'] == normalizedEmail);
    if (exists) {
      throw Exception('هذا البريد الإلكتروني مسجل مسبقاً');
    }

    final user = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      email: normalizedEmail,
      phone: phone.trim(),
    );

    users.add({...user.toMap(), 'password': password});
    await prefs.setString(_keyRegisteredUsers, jsonEncode(users));

    _currentUser = user;
    await prefs.setString(_keyCurrentUser, jsonEncode(user.toMap()));
    return user;
  }

  static Future<UserModel?> signInWithBiometrics() async {
    final bool authenticated = await BiometricsService.authenticate(
      localizedReason: 'يرجى المصادقة بالبصمة للدخول لتطبيق زكاتي',
    );

    if (!authenticated) {
      return null;
    }

    // Load last session user or default to primary user
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyCurrentUser);
    if (userJson != null) {
      _currentUser = UserModel.fromMap(jsonDecode(userJson));
      return _currentUser;
    }

    // Default fast profile if no session
    final defaultUser = UserModel(
      id: 'bio_user_1',
      name: 'مستخدم البصمة',
      email: 'user@zakat.app',
      phone: '777000111',
      isBiometricEnabled: true,
    );
    _currentUser = defaultUser;
    await prefs.setString(_keyCurrentUser, jsonEncode(defaultUser.toMap()));
    return defaultUser;
  }

  static Future<void> updateBiometricPreference(bool enabled) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(isBiometricEnabled: enabled);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCurrentUser, jsonEncode(_currentUser!.toMap()));
    }
  }

  static Future<void> signOut() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
  }
}
