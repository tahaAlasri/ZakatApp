import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zakat_app/core/database/local_db_service.dart';

export 'dart:typed_data';
export 'package:flutter/material.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:provider/provider.dart';

export 'package:zakat_app/core/constants/zakat_constants.dart';
export 'package:zakat_app/core/utils/formatters.dart';
export 'package:zakat_app/core/utils/app_input_formatters.dart';
export 'package:zakat_app/providers/zakat_provider.dart';
export 'package:zakat_app/providers/hawl_provider.dart';
export 'package:zakat_app/providers/auth_provider.dart';
export 'package:zakat_app/providers/favorites_provider.dart';
export 'package:zakat_app/models/zakat_record.dart';
export 'package:zakat_app/models/favorite_item.dart';
export 'package:zakat_app/models/assistance_request.dart';
export 'package:zakat_app/models/user_model.dart';
export 'package:zakat_app/core/services/pdf_service.dart';
export 'package:zakat_app/core/services/market_price_service.dart';
export 'package:zakat_app/core/services/auth_service.dart';
export 'package:zakat_app/core/services/encryption_service.dart';
export 'package:zakat_app/core/database/local_db_service.dart';
export 'package:zakat_app/core/database/preferences_service.dart';
export 'package:zakat_app/core/widgets/price_transparency_card.dart';
export 'package:zakat_app/views/calculators/money_calc_screen.dart';
export 'package:zakat_app/views/calculators/gold_calc_screen.dart';
export 'package:zakat_app/views/requests/assistance_request_screen.dart';

/// Common test setup for all Zakat App test suites.
/// Call this in setUpAll() before running any tests.
Future<void> initTestEnvironment() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final tempDir = Directory.systemTemp.createTempSync('zakat_test_hive_');
  Hive.init(tempDir.path);
  await initializeDateFormatting('ar', null);
  await LocalDbService.init();
}
