import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/constants/app_themes.dart';
import 'core/database/preferences_service.dart';
import 'core/database/local_db_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/cloud_sync_service.dart';
import 'core/services/app_lock_manager.dart';
import 'views/auth/app_lock_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/zakat_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/hawl_provider.dart';
import 'providers/notification_provider.dart';
import 'views/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Arabic date formatting symbols and Hijri calendar
  await initializeDateFormatting('ar', null);
  HijriCalendar.setLocal('ar');

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Initialize Core Local & Cloud Services
  await PreferencesService.init();
  await LocalDbService.init();
  await AuthService.init();
  await NotificationService.init();
  try {
    await PermissionService.requestNotificationPermission();
  } catch (e) {
    debugPrint('Permission error on start: $e');
  }
  final cloudSync = CloudSyncService();
  await cloudSync.init();

  final appLockManager = AppLockManager();
  appLockManager.init();

  final zakatProvider = ZakatProvider();

  // مزامنة تلقائية: عند تحديث الأسعار من لوحة التحكم في CloudSyncService،
  // يتم تلقائياً إعادة تحميل الأسعار في ZakatProvider
  cloudSync.addListener(() {
    zakatProvider.reloadPricesFromPreferences();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: zakatProvider),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => HawlProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider.value(value: cloudSync),
        ChangeNotifierProvider.value(value: appLockManager),
      ],
      child: const ZakatApp(),
    ),
  );
}

class ZakatApp extends StatelessWidget {
  const ZakatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'الهيئة العامة للزكاة',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeProv.themeMode,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final lockManager = Provider.of<AppLockManager>(context);
        final authProvider = Provider.of<AuthProvider>(context);
        final bool shouldShowLock = lockManager.isLocked && authProvider.isAuthenticated;

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.15),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (shouldShowLock)
                  const Positioned.fill(
                    child: AppLockScreen(),
                  ),
              ],
            ),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
