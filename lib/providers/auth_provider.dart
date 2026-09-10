import 'package:flutter/material.dart';
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
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = await AuthService.signUp(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
      _user = user;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> loginWithBiometrics() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = await AuthService.signInWithBiometrics();
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
      _errorMessage = 'خطأ في المصادقة بالبصمة';
      _setLoading(false);
      return false;
    }
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
