import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricsService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }

  static Future<bool> authenticate({String localizedReason = 'يرجى تأكيد الهوية باستخدام البصمة للدخول'}) async {
    try {
      final bool isAvailable = await isBiometricsAvailable();
      if (!isAvailable) {
        throw Exception('جهازك لا يدعم مستشعر البصمة أو لم يتم تفعيل قفل الشاشة في إعدادات النظام');
      }

      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      if (e.code == 'NotEnrolled') {
        throw Exception('لم يتم تسجيل بصمة في إعدادات الهاتف بعد. يرجى إضافة بصمة إصبع في إعدادات الجهاز أولاً.');
      } else if (e.code == 'LockedOut') {
        throw Exception('تم قفل مستشعر البصمة مؤقتاً بسبب كثرة المحاولات، يرجى المحاولة لاحقاً أو استخدام كلمة المرور.');
      } else if (e.code == 'PermanentlyLockedOut') {
        throw Exception('تم قفل مستشعر البصمة نهائياً، يرجى فتح قفل الهاتف برمز المرور أو النمط.');
      } else if (e.code == 'PasscodeNotSet') {
        throw Exception('يرجى تعيين قفل شاشة (PIN أو نمط أو بصمة) في إعدادات الجهاز للمتابعة.');
      } else if (e.code == 'NotAvailable') {
        throw Exception('مستشعر البصمة غير متاح حالياً على هذا الجهاز.');
      }
      return false;
    }
  }
}
