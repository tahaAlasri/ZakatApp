import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'biometrics_service.dart';
import '../database/preferences_service.dart';

/// مدير القفل التلقائي والأمان (App Lock Manager)
/// يقوم بقفل التطبيق تلقائياً عند خروج المستخدم المسجل بحساب لمدة دقيقة أو أكثر
class AppLockManager extends ChangeNotifier with WidgetsBindingObserver {
  static final AppLockManager _instance = AppLockManager._internal();
  factory AppLockManager() => _instance;
  AppLockManager._internal();

  /// مدة المهلة المحددة للقفل التلقائي (دقيقة واحدة = 60 ثانية)
  static const Duration lockTimeout = Duration(minutes: 1);

  bool _isLocked = false;
  DateTime? _pausedTime;
  bool _isInitialized = false;

  bool get isLocked => _isLocked;

  @visibleForTesting
  void setPausedTimeForTesting(DateTime? time) {
    _pausedTime = time;
  }

  void init() {
    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);

    // فحص ما إذا كان هناك وقت خروج سابق عند استئناف تشغيل التطبيق
    _checkInitialResumeTimeout();
  }

  void _checkInitialResumeTimeout() {
    final user = AuthService.currentUser;
    if (user == null) {
      _isLocked = false;
      return;
    }

    final savedMs = PreferencesService.lastPausedTimestamp;
    if (savedMs != null) {
      final lastPaused = DateTime.fromMillisecondsSinceEpoch(savedMs);
      final elapsed = DateTime.now().difference(lastPaused);
      if (elapsed >= lockTimeout) {
        _isLocked = true;
        notifyListeners();
      }
      PreferencesService.setLastPausedTimestamp(null);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = AuthService.currentUser;

    // إذا لم يكن المستخدم مسجلاً بحساب (وضع الزائر / بداية التثبيت)، لا يتم تفعيل القفل
    if (user == null) {
      _isLocked = false;
      _pausedTime = null;
      PreferencesService.setLastPausedTimestamp(null);
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // تسجيل وقت الخروج فقط إذا لم يكن التطبيق مقفلاً بالفعل
      if (!_isLocked) {
        _pausedTime = DateTime.now();
        PreferencesService.setLastPausedTimestamp(_pausedTime!.millisecondsSinceEpoch);
      }
    } else if (state == AppLifecycleState.resumed) {
      final savedMs = PreferencesService.lastPausedTimestamp;
      final lastTime = _pausedTime ??
          (savedMs != null ? DateTime.fromMillisecondsSinceEpoch(savedMs) : null);

      if (lastTime != null && !_isLocked) {
        final elapsed = DateTime.now().difference(lastTime);
        if (elapsed >= lockTimeout) {
          _isLocked = true;
          notifyListeners();
        }
      }

      _pausedTime = null;
      PreferencesService.setLastPausedTimestamp(null);
    }
  }

  /// محاولة إلغاء القفل عبر المصادقة البيومترية (البصمة)
  Future<bool> unlockWithBiometrics() async {
    final user = AuthService.currentUser;
    if (user == null) {
      _isLocked = false;
      notifyListeners();
      return true;
    }

    try {
      final bool isAvailable = await BiometricsService.isBiometricsAvailable();
      if (!isAvailable) {
        throw Exception('جهازك لا يدعم المصادقة بالبصمة أو لم يتم تفعيلها.');
      }

      final bool success = await BiometricsService.authenticate(
        localizedReason: 'يرجى تأكيد الهوية بالبصمة للدخول لتطبيق الزكاة كـ ${user.name}',
      );

      if (success) {
        _isLocked = false;
        _pausedTime = null;
        await PreferencesService.setLastPausedTimestamp(null);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  /// محاولة إلغاء القفل عبر كلمة مرور الحساب
  Future<bool> unlockWithPassword(String password) async {
    final user = AuthService.currentUser;
    if (user == null) {
      _isLocked = false;
      notifyListeners();
      return true;
    }

    try {
      final signedInUser = await AuthService.signIn(
        email: user.email,
        password: password,
      );

      if (signedInUser != null) {
        _isLocked = false;
        _pausedTime = null;
        await PreferencesService.setLastPausedTimestamp(null);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  /// قفل التطبيق يدوياً
  void lock() {
    if (AuthService.currentUser != null) {
      _isLocked = true;
      notifyListeners();
    }
  }

  /// إلغاء القفل يدوياً (مثلاً عند تسجيل الخروج)
  void unlock() {
    _isLocked = false;
    _pausedTime = null;
    PreferencesService.setLastPausedTimestamp(null);
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
