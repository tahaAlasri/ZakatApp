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
import 'package:zakat_app/providers/auth_provider.dart';
import 'package:zakat_app/providers/favorites_provider.dart';
import 'package:zakat_app/providers/hawl_provider.dart';
import 'package:zakat_app/providers/zakat_provider.dart';
import 'package:zakat_app/providers/theme_provider.dart';
import 'package:zakat_app/providers/notification_provider.dart';

import 'package:zakat_app/views/calculators/fitr_calc_screen.dart';
import 'package:zakat_app/views/history/zakat_history_screen.dart';
import 'package:zakat_app/views/auth/login_screen.dart';
import 'package:zakat_app/views/requests/my_requests_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final tempDir = Directory.systemTemp.createTempSync('zakat_diag_test_');
    Hive.init(tempDir.path);
    await initializeDateFormatting('ar', null);
    await PreferencesService.init();
    await LocalDbService.init();
  });

  Widget buildApp(Widget child, {Size size = const Size(320, 568), double textScale = 1.0}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ZakatProvider()),
        ChangeNotifierProvider(create: (_) => HawlProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CloudSyncService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, fontFamily: 'Tajawal'),
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    );
  }

  testWidgets('Diagnostic FitrCalcScreen', (tester) async {
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
    };
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(buildApp(const FitrCalcScreen(), size: const Size(320, 568)));
    await tester.pump();
  });

  testWidgets('Diagnostic ZakatHistoryScreen', (tester) async {
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
    };
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(buildApp(const ZakatHistoryScreen(), size: const Size(320, 568)));
    await tester.pump();
  });

  testWidgets('Diagnostic LoginScreen', (tester) async {
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
    };
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(buildApp(const LoginScreen(), size: const Size(320, 568)));
    await tester.pump();
  });

  testWidgets('Diagnostic MyRequestsScreen', (tester) async {
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
    };
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(buildApp(const MyRequestsScreen(), size: const Size(844, 390)));
    await tester.pump();
  });
}
