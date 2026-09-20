// File generated based on google-services.json for ZakatApp
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBGzRGMUgU1j7GUmo50Dae1M2aIDvJNYwE',
    appId: '1:46552772030:android:89405dab7d63fb93115def',
    messagingSenderId: '46552772030',
    projectId: 'zakat-app-6bf78',
    storageBucket: 'zakat-app-6bf78.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBGzRGMUgU1j7GUmo50Dae1M2aIDvJNYwE',
    appId: '1:46552772030:android:89405dab7d63fb93115def',
    messagingSenderId: '46552772030',
    projectId: 'zakat-app-6bf78',
    storageBucket: 'zakat-app-6bf78.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBGzRGMUgU1j7GUmo50Dae1M2aIDvJNYwE',
    appId: '1:46552772030:ios:89405dab7d63fb93115def',
    messagingSenderId: '46552772030',
    projectId: 'zakat-app-6bf78',
    storageBucket: 'zakat-app-6bf78.firebasestorage.app',
    iosBundleId: 'com.example.finalPro',
  );
}
