import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/services/auth_service.dart';
import '../core/database/preferences_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user = AuthService.currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Returns true if this device has a previously registered user or saved account
  bool get hasAccountOnDevice => AuthService.hasRegisteredAccount;

  /// The last known user profile saved on this device
  UserModel? get lastKnownUser => AuthService.lastKnownUser;

  /// Categorized authentication status (guest, localAuthenticated, firebaseAuthenticated, officiallyVerified)
  AuthStatus get authStatus => AuthService.authStatus;

  /// Whether current status allows official request submission (Firebase or officiallyVerified)
  bool get canSubmitOfficialRequest => AuthService.canSubmitOfficialRequest;

  bool get isBiometricEnabled => _user?.isBiometricEnabled ?? PreferencesService.isBiometricEnabled;

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = await AuthService.signIn(email: email, password: password);
      _user = user;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? profileImagePath,
    bool enableBiometrics = false,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = await AuthService.signUp(
        name: name,
        email: email,
        phone: phone,
        password: password,
        profileImagePath: profileImagePath,
      );
      _user = user;
      await PreferencesService.setBiometricEnabled(enableBiometrics);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> loginWithBiometrics({String? hintEmail}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = await AuthService.signInWithBiometrics(hintEmail: hintEmail);
      if (user != null) {
        _user = user;
        _setLoading(false);
        return true;
      } else {
        _errorMessage = 'لم يتم تأكيد البصمة أو تم الإلغاء';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }


  Future<bool> updateProfile({required String name, String? phone}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final updated = await AuthService.updateProfile(name: name, phone: phone);
      if (updated != null) {
        _user = updated;
      }
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'تعذر تحديث الملف الشخصي';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateProfileImage(String? imagePath) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final updated = await AuthService.updateProfileImage(imagePath);
      if (updated != null) {
        _user = updated;
      }
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'تعذر تحديث صورة الحساب';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> pickAndSaveProfileImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        return await updateProfileImage(pickedFile.path);
      }
      return false;
    } catch (e) {
      _errorMessage = 'تعذر التقاط الصورة: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeProfileImage() async {
    return await updateProfileImage(null);
  }

  Future<void> toggleBiometrics(bool enabled) async {
    await PreferencesService.setBiometricEnabled(enabled);
    await AuthService.updateBiometricPreference(enabled);
    if (_user != null) {
      _user = _user!.copyWith(isBiometricEnabled: enabled);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.signOut();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
