import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zakat_app/core/database/local_db_service.dart';
import 'package:zakat_app/core/database/preferences_service.dart';
import 'package:zakat_app/core/services/cloud_sync_service.dart';
import 'package:zakat_app/core/services/app_lock_manager.dart';
import 'package:zakat_app/providers/auth_provider.dart';
import 'package:zakat_app/providers/favorites_provider.dart';
import 'package:zakat_app/providers/hawl_provider.dart';
import 'package:zakat_app/providers/zakat_provider.dart';
import 'package:zakat_app/providers/theme_provider.dart';
import 'package:zakat_app/providers/notification_provider.dart';

import 'package:zakat_app/views/home/home_screen.dart';
import 'package:zakat_app/views/dashboard/main_navigation_screen.dart';
import 'package:zakat_app/views/calculators/calculators_grid_screen.dart';
import 'package:zakat_app/views/calculators/gold_calc_screen.dart';
import 'package:zakat_app/views/calculators/silver_calc_screen.dart';
import 'package:zakat_app/views/calculators/money_calc_screen.dart';
import 'package:zakat_app/views/calculators/trade_calc_screen.dart';
import 'package:zakat_app/views/calculators/crops_calc_screen.dart';
import 'package:zakat_app/views/calculators/livestock_calc_screen.dart';
import 'package:zakat_app/views/calculators/fitr_calc_screen.dart';
import 'package:zakat_app/views/calculators/stocks_calc_screen.dart';
import 'package:zakat_app/views/calculators/crypto_calc_screen.dart';
import 'package:zakat_app/views/calculators/minerals_screen.dart';
import 'package:zakat_app/views/calculators/fields_calc_screen.dart';
import 'package:zakat_app/views/hawl/hawl_tracker_screen.dart';
import 'package:zakat_app/views/history/zakat_history_screen.dart';
import 'package:zakat_app/views/analytics/zakat_analytics_screen.dart';
import 'package:zakat_app/views/payment/zakat_payment_screen.dart';
import 'package:zakat_app/views/requests/assistance_request_screen.dart';
import 'package:zakat_app/views/requests/my_requests_screen.dart';
import 'package:zakat_app/views/settings/settings_screen.dart';
import 'package:zakat_app/views/favorites/favorites_screen.dart';
import 'package:zakat_app/views/auth/login_screen.dart';
import 'package:zakat_app/views/auth/register_screen.dart';
import 'package:zakat_app/views/onboarding/onboarding_screen.dart';
import 'package:zakat_app/views/splash/splash_screen.dart';
import 'package:zakat_app/views/notifications/notifications_center_screen.dart';

void main() {
  late ZakatProvider zakatProv;
  late HawlProvider hawlProv;
  late FavoritesProvider favProv;
  late AuthProvider authProv;
  late CloudSyncService cloudSync;
  late ThemeProvider themeProv;
  late NotificationProvider notifProv;
  late AppLockManager appLockManager;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final tempDir = Directory.systemTemp.createTempSync('zakat_responsive_test_');
    Hive.init(tempDir.path);
    await initializeDateFormatting('ar', null);
    await PreferencesService.init();
    await LocalDbService.init();
  });

  setUp(() {
    zakatProv = ZakatProvider();
    hawlProv = HawlProvider();
    favProv = FavoritesProvider();
    authProv = AuthProvider();
    cloudSync = CloudSyncService();
    themeProv = ThemeProvider();
    notifProv = NotificationProvider();
    appLockManager = AppLockManager();
  });

  Widget buildTestApp(Widget child, {double textScale = 1.0, required Size size}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: zakatProv),
        ChangeNotifierProvider.value(value: hawlProv),
        ChangeNotifierProvider.value(value: favProv),
        ChangeNotifierProvider.value(value: authProv),
        ChangeNotifierProvider.value(value: cloudSync),
        ChangeNotifierProvider.value(value: themeProv),
        ChangeNotifierProvider.value(value: notifProv),
        ChangeNotifierProvider.value(value: appLockManager),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, fontFamily: 'Tajawal'),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
  }

  final testViewports = <String, Size>{
    'Ultra Compact Phone (320x568)': const Size(320, 568),
    'Standard Compact Android (360x640)': const Size(360, 640),
    'Modern Standard Phone (390x844)': const Size(390, 844),
    'Large Phone / Pro Max (430x932)': const Size(430, 932),
    'Small Tablet / Foldable (600x960)': const Size(600, 960),
    'Medium Tablet / iPad (800x1280)': const Size(800, 1280),
    'Large Tablet / iPad Pro (1024x1366)': const Size(1024, 1366),
    'Landscape Mode (844x390)': const Size(844, 390),
  };

  void testScreen(String name, Widget Function() builder) {
    group('Screen: $name', () {
      for (final entry in testViewports.entries) {
        testWidgets('Renders cleanly on ${entry.key}', (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(buildTestApp(builder(), size: entry.value));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'Layout overflowed on ${entry.key}');
        });
      }

      testWidgets('Renders cleanly with 1.3x Large Font Scaling', (tester) async {
        const size = Size(360, 640);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestApp(builder(), textScale: 1.3, size: size));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'Layout overflowed with 1.3x text scale');
      });
    });
  }

  // Run comprehensive responsive tests across all 27 screens
  group('Comprehensive Cross-Device Responsive Test Suite', () {
    testScreen('HomeScreen', () => const HomeScreen());
    testScreen('MainNavigationScreen', () => const MainNavigationScreen());
    testScreen('CalculatorsGridScreen', () => const CalculatorsGridScreen());
    testScreen('MoneyCalcScreen', () => const MoneyCalcScreen());
    testScreen('GoldCalcScreen', () => const GoldCalcScreen());
    testScreen('SilverCalcScreen', () => const SilverCalcScreen());
    testScreen('TradeCalcScreen', () => const TradeCalcScreen());
    testScreen('CropsCalcScreen', () => const CropsCalcScreen());
    testScreen('LivestockCalcScreen', () => const LivestockCalcScreen());
    testScreen('FitrCalcScreen', () => const FitrCalcScreen());
    testScreen('StocksCalcScreen', () => const StocksCalcScreen());
    testScreen('CryptoCalcScreen', () => const CryptoCalcScreen());
    testScreen('MineralsScreen', () => const MineralsScreen());
    testScreen('FieldsCalcScreen', () => const FieldsCalcScreen());
    testScreen('HawlTrackerScreen', () => const HawlTrackerScreen());
    testScreen('ZakatHistoryScreen', () => const ZakatHistoryScreen());
    testScreen('ZakatAnalyticsScreen', () => const ZakatAnalyticsScreen());
    testScreen('ZakatPaymentScreen', () => const ZakatPaymentScreen());
    testScreen('AssistanceRequestScreen', () => const AssistanceRequestScreen());
    testScreen('MyRequestsScreen', () => const MyRequestsScreen());
    testScreen('SettingsScreen', () => const SettingsScreen());
    testScreen('FavoritesScreen', () => const FavoritesScreen());
    testScreen('LoginScreen', () => const LoginScreen());
    testScreen('RegisterScreen', () => const RegisterScreen());
    testScreen('OnboardingScreen', () => const OnboardingScreen());
    testScreen('SplashScreen', () => const SplashScreen());
    testScreen('NotificationsCenterScreen', () => const NotificationsCenterScreen());
  });
}
