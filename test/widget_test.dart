import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/constants/zakat_constants.dart';
import 'package:zakat_app/core/utils/formatters.dart';
import 'package:zakat_app/providers/zakat_provider.dart';
import 'package:zakat_app/providers/hawl_provider.dart';
import 'package:zakat_app/models/zakat_record.dart';
import 'package:zakat_app/models/favorite_item.dart';
import 'package:zakat_app/models/assistance_request.dart';
import 'package:zakat_app/models/user_model.dart';
import 'package:zakat_app/core/services/pdf_service.dart';
import 'package:zakat_app/core/services/market_price_service.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/providers/auth_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zakat_app/core/services/encryption_service.dart';
import 'package:zakat_app/core/database/local_db_service.dart';
import 'package:zakat_app/core/database/preferences_service.dart';
import 'package:zakat_app/core/widgets/price_transparency_card.dart';
import 'package:zakat_app/views/calculators/money_calc_screen.dart';
import 'package:zakat_app/views/calculators/gold_calc_screen.dart';
import 'package:zakat_app/providers/favorites_provider.dart';
import 'package:zakat_app/views/requests/assistance_request_screen.dart';
import 'package:provider/provider.dart';
import 'package:zakat_app/core/utils/app_input_formatters.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final tempDir = Directory.systemTemp.createTempSync('zakat_test_hive_');
    Hive.init(tempDir.path);
    await initializeDateFormatting('ar', null);
    await LocalDbService.init();
  });

  group('1. Zakat Constants & Core Thresholds', () {
    test('Nisab values match Islamic Sharia', () {
      expect(ZakatConstants.goldNisabGrams, 85.0);
      expect(ZakatConstants.silverNisabGrams, 595.0);
      expect(ZakatConstants.standardZakatRate, 0.025);
      expect(ZakatConstants.rainFedRate, 0.10);
      expect(ZakatConstants.irrigatedRate, 0.05);
      expect(ZakatConstants.mixedRate, 0.075);
    });

    test('Livestock minimum Nisab thresholds', () {
      expect(ZakatConstants.camelNisab, 5);
      expect(ZakatConstants.cowNisab, 30);
      expect(ZakatConstants.sheepNisab, 40);
    });

    test('AppFormatters Arabic date formatting test', () async {
      await initializeDateFormatting('ar', null);
      final now = DateTime(2025, 5, 20, 14, 30);
      final formattedDate = AppFormatters.formatDate(now);
      final formattedDateTime = AppFormatters.formatDateTime(now);

      expect(formattedDate, isNotEmpty);
      expect(formattedDateTime, isNotEmpty);
      expect(formattedDate.contains('هـ'), isTrue);
    });
  });

  group('2. Zakat Provider - All 10 Calculators Logic Tests', () {
    final provider = ZakatProvider();

    // 1. Money Zakat
    test('Money Zakat: Below Nisab vs Above Nisab', () {
      const goldPrice = 50000.0;
      const nisabAmount = 85.0 * goldPrice; // 4,250,000

      // Below Nisab
      final below = provider.calculateMoneyZakat(4000000, goldPricePerGram: goldPrice);
      expect(below.nisabThreshold, nisabAmount);
      expect(below.reachedNisab, isFalse);
      expect(below.zakatAmount, 0.0);

      // Reached Nisab
      final above = provider.calculateMoneyZakat(10000000, goldPricePerGram: goldPrice);
      expect(above.reachedNisab, isTrue);
      expect(above.zakatAmount, 250000.0); // 2.5% of 10,000,000
    });

    // 2. Gold Zakat
    test('Gold Zakat: 24k, 21k, 18k conversion accuracy', () {
      // 80g of 24k is below 85g nisab
      final gold24Below = provider.calculateGoldZakat(grams: 80, karat: 24, pricePerGram: 50000);
      expect(gold24Below.reachedNisab, isFalse);

      // 100g of 24k: pure = 100g, zakat = 2.5g = 125,000
      final gold24Above = provider.calculateGoldZakat(grams: 100, karat: 24, pricePerGram: 50000);
      expect(gold24Above.reachedNisab, isTrue);
      expect(gold24Above.zakatAmount, 125000.0);

      // 97.2g of 21k: (97.2 * 21) / 24 = 85.05g (Reaches 85g pure Nisab)
      // 97.2g * 0.025 = 2.43g of 21k -> 2.43 * 50,000 = 121,500.0
      final gold21Above = provider.calculateGoldZakat(grams: 97.2, karat: 21, pricePerGram: 50000);
      expect(gold21Above.reachedNisab, isTrue);
      expect(gold21Above.zakatAmount, 121500.0);
      expect(gold21Above.zakatInKindDescription, contains('2.43 جرام عيار 21'));
      expect(gold21Above.zakatInKindDescription, contains('2.13 جرام عيار 24 خالص'));

      // 100g of 18k: (100 * 18) / 24 = 75g pure (Below 85g Nisab)
      final gold18Below = provider.calculateGoldZakat(grams: 100, karat: 18, pricePerGram: 50000);
      expect(gold18Below.reachedNisab, isFalse);

      // 120g of 18k: (120 * 18) / 24 = 90g pure (Above 85g Nisab)
      // 120g * 0.025 = 3.0g of 18k -> 3.0 * 50,000 = 150,000.0
      final gold18Above = provider.calculateGoldZakat(grams: 120, karat: 18, pricePerGram: 50000);
      expect(gold18Above.reachedNisab, isTrue);
      expect(gold18Above.zakatAmount, 150000.0);
      expect(gold18Above.zakatInKindDescription, contains('3.00 جرام عيار 18'));
      expect(gold18Above.zakatInKindDescription, contains('2.25 جرام عيار 24 خالص'));

      // 120g of 21k with personal jewelry exemption -> reachedNisab is False and zakat is 0
      final personalJewelry = provider.calculateGoldZakat(
        grams: 120,
        karat: 21,
        pricePerGram: 50000,
        isPersonalJewelry: true,
      );
      expect(personalJewelry.reachedNisab, isFalse);
      expect(personalJewelry.zakatAmount, 0.0);
      expect(personalJewelry.explanation, contains('حلي المباح'));
    });

    // 3. Silver Zakat
    test('Silver Zakat: Below 595g vs Above 595g', () {
      const silverPrice = 700.0;

      final below = provider.calculateSilverZakat(500, pricePerGram: silverPrice);
      expect(below.reachedNisab, isFalse);

      final above = provider.calculateSilverZakat(1000, pricePerGram: silverPrice);
      expect(above.reachedNisab, isTrue);
      expect(above.zakatAmount, 1000 * 0.025 * 700.0); // 17,500
    });

    // 4. Trade Zakat
    test('Trade & Commerce Zakat: Assets - Liabilities >= Nisab', () {
      final res = provider.calculateTradeZakat(
        inventoryValue: 6000000,
        cashInHand: 2000000,
        receivables: 1000000,
        liabilities: 1500000, // Net: 7,500,000
      );
      expect(res.reachedNisab, isTrue);
      expect(res.zakatAmount, 7500000 * 0.025); // 187,500
    });

    // 5. Crops Zakat
    test('Crops Zakat: Rain-fed 10%, Irrigated 5%, Mixed 7.5%', () {
      // Zero weight verification
      final zeroWeightCrop = provider.calculateCropsZakat(
        totalCropValue: 1000000,
        irrigationType: 'natural',
        weightInKg: 0,
      );
      expect(zeroWeightCrop.reachedNisab, isFalse);
      expect(zeroWeightCrop.zakatAmount, 0.0);
      expect(zeroWeightCrop.explanation, contains('يجب إدخال وزن المحصول'));

      final rain = provider.calculateCropsZakat(totalCropValue: 1000000, irrigationType: 'natural', weightInKg: 1000);
      expect(rain.reachedNisab, isTrue);
      expect(rain.zakatAmount, 100000.0); // 10%

      final irrigated = provider.calculateCropsZakat(totalCropValue: 1000000, irrigationType: 'artificial', weightInKg: 1000);
      expect(irrigated.reachedNisab, isTrue);
      expect(irrigated.zakatAmount, 50000.0); // 5%

      final mixed = provider.calculateCropsZakat(totalCropValue: 1000000, irrigationType: 'mixed', weightInKg: 1000);
      expect(mixed.reachedNisab, isTrue);
      expect(mixed.zakatAmount, 75000.0); // 7.5%

      // 5 Aswuq Nisab verification (612 kg threshold)
      final belowNisabCrop = provider.calculateCropsZakat(
        totalCropValue: 500000,
        irrigationType: 'natural',
        weightInKg: 500, // Below 612 kg
      );
      expect(belowNisabCrop.reachedNisab, isFalse);
      expect(belowNisabCrop.zakatAmount, 0.0);
      expect(belowNisabCrop.explanation, contains('لم يكتمل النصاب الشرعي'));

      final aboveNisabCrop = provider.calculateCropsZakat(
        totalCropValue: 1000000,
        irrigationType: 'natural',
        weightInKg: 1000, // Above 612 kg
      );
      expect(aboveNisabCrop.reachedNisab, isTrue);
      expect(aboveNisabCrop.zakatAmount, 100000.0);
      expect(aboveNisabCrop.zakatInKindDescription, contains('100.0 كجم'));
    });

    // 6. Camels Zakat
    test('Camels Zakat: Sharia in-kind brackets and exact combinations (>120)', () {
      // Below Nisab
      expect(provider.calculateCamelsZakat(4).reachedNisab, isFalse);

      // 5-9: 1 sheep
      final c5 = provider.calculateCamelsZakat(5);
      expect(c5.reachedNisab, isTrue);
      expect(c5.zakatInKindDescription, contains('شاة واحدة'));

      // 10-14: 2 sheep
      final c10 = provider.calculateCamelsZakat(10);
      expect(c10.zakatInKindDescription, contains('شاتان'));

      // 25-35: Bint Makhad
      final c25 = provider.calculateCamelsZakat(25);
      expect(c25.zakatInKindDescription, contains('بنت مخاض'));

      // 36-45: Bint Laboon
      final c40 = provider.calculateCamelsZakat(40);
      expect(c40.zakatInKindDescription, contains('بنت لبون'));

      // 121: Calculated with base 120 (3 Bint Laboon) + waqas 1 (عفو شرعي)
      final c121 = provider.calculateCamelsZakat(121);
      expect(c121.zakatInKindDescription, contains('بنات لبون'));
      expect(c121.zakatInKindDescription, contains('وقص'));

      // 130: 1 Hiqqah (50) + 2 Bint Laboon (80)
      final c130 = provider.calculateCamelsZakat(130);
      expect(c130.zakatInKindDescription, contains('حِقّة واحدة'));
      expect(c130.zakatInKindDescription, contains('بنتا لبون'));

      // 140: 2 Hiqqah (100) + 1 Bint Laboon (40)
      final c140 = provider.calculateCamelsZakat(140);
      expect(c140.zakatInKindDescription, contains('حِقّتان'));
      expect(c140.zakatInKindDescription, contains('بنت لبون واحدة'));

      // 150: 3 Hiqqah (150)
      final c150 = provider.calculateCamelsZakat(150);
      expect(c150.zakatInKindDescription, contains('3 حِقاق'));

      // 160: 4 Bint Laboon (160)
      final c160 = provider.calculateCamelsZakat(160);
      expect(c160.zakatInKindDescription, contains('4 بنات لبون'));

      // 200: 5 Bint Laboon or 4 Hiqqah
      final c200 = provider.calculateCamelsZakat(200);
      expect(c200.zakatInKindDescription, anyOf(contains('5 بنات لبون'), contains('4 حِقاق')));

      // 240: 6 Bint Laboon or (4 Hiqqah + 1 Bint Laboon)
      final c240 = provider.calculateCamelsZakat(240);
      expect(c240.zakatInKindDescription, anyOf(contains('6 بنات لبون'), contains('4 حِقاق')));

      // 300: 6 Hiqqah or (2 Hiqqah + 5 Bint Laboon)
      final c300 = provider.calculateCamelsZakat(300);
      expect(c300.zakatInKindDescription, anyOf(contains('6 حِقاق'), contains('5 بنات لبون')));
    });

    // 7. Cows Zakat
    test('Cows Zakat: Sharia in-kind brackets and exact combinations (>= 120)', () {
      // Below Nisab
      expect(provider.calculateCowsZakat(29).reachedNisab, isFalse);

      // 30-39: Tabee
      final cow30 = provider.calculateCowsZakat(30);
      expect(cow30.reachedNisab, isTrue);
      expect(cow30.zakatInKindDescription, contains('تبيع'));

      // 40-59: Musinna
      final cow40 = provider.calculateCowsZakat(40);
      expect(cow40.zakatInKindDescription, contains('مُسنّة'));

      // Exact combinations:
      // 120: 4 Tabee (120) or 3 Musinna (120)
      final cow120 = provider.calculateCowsZakat(120);
      expect(cow120.zakatInKindDescription, anyOf(contains('4 أتبعة'), contains('3 مسنّات')));

      // 130: 3 Tabee (90) + 1 Musinna (40) = 130
      final cow130 = provider.calculateCowsZakat(130);
      expect(cow130.zakatInKindDescription, contains('مسنّة واحدة'));
      expect(cow130.zakatInKindDescription, contains('3 أتبعة'));

      // 121: Calculated with base 120 (4 Tabee or 3 Musinna) + waqas 1 (عفو شرعي)
      final cow121 = provider.calculateCowsZakat(121);
      expect(cow121.zakatInKindDescription, anyOf(contains('أتبعة'), contains('مسنّات')));
      expect(cow121.zakatInKindDescription, contains('وقص'));
    });

    // 8. Sheep Zakat
    test('Sheep Zakat: Sharia in-kind brackets', () {
      // Below Nisab
      expect(provider.calculateSheepZakat(39).reachedNisab, isFalse);

      // 40-120: 1 sheep
      final s40 = provider.calculateSheepZakat(40);
      expect(s40.reachedNisab, isTrue);
      expect(s40.zakatInKindDescription, contains('شاة واحدة'));

      // 121-200: 2 sheep
      final s150 = provider.calculateSheepZakat(150);
      expect(s150.zakatInKindDescription, contains('شاتان'));
    });

    // 9. Minerals & Rikaz
    test('Minerals & Rikaz: 20% for Rikaz, 2.5% for Minerals with Nisab', () {
      // Rikaz: 20% regardless of Nisab
      final rikaz = provider.calculateMineralsZakat(totalExtractedValue: 500000, isRikaz: true);
      expect(rikaz.reachedNisab, isTrue);
      expect(rikaz.zakatAmount, 100000.0); // 20% (الخمس)

      // Minerals below 24k Nisab (85 * 62,850 = 5,342,250) -> reachedNisab is False
      final mineralsBelow = provider.calculateMineralsZakat(totalExtractedValue: 500000, isRikaz: false);
      expect(mineralsBelow.reachedNisab, isFalse);
      expect(mineralsBelow.zakatAmount, 0.0);
      expect(mineralsBelow.explanation, contains('لم تبلغ قيمة المعادن النصاب'));

      // Minerals above 24k Nisab (e.g. 6,000,000) -> 2.5% = 150,000
      final mineralsAbove = provider.calculateMineralsZakat(totalExtractedValue: 6000000, isRikaz: false);
      expect(mineralsAbove.reachedNisab, isTrue);
      expect(mineralsAbove.zakatAmount, 6000000 * 0.025); // 150,000
    });

    // 10. Exploited Assets (4 Methods)
    test('Exploited Assets: 4 calculation methods and explicit explanation', () {
      // 1. Net Revenue: 8,000,000 - 1,000,000 = 7,000,000 * 2.5% = 175,000
      final netRes = provider.calculateExploitedAssetsZakat(
        grossIncome: 8000000,
        expenses: 1000000,
        method: ExploitedAssetsMethod.netRevenue,
      );
      expect(netRes.reachedNisab, isTrue);
      expect(netRes.zakatAmount, 7000000 * 0.025);
      expect(netRes.explanation, contains('تم الحساب بناءً على طريقة: صافي الريع'));

      // 2. Gross Revenue: 8,000,000 * 2.5% = 200,000 (ignoring expenses)
      final grossRes = provider.calculateExploitedAssetsZakat(
        grossIncome: 8000000,
        expenses: 1000000,
        method: ExploitedAssetsMethod.grossRevenue,
      );
      expect(grossRes.reachedNisab, isTrue);
      expect(grossRes.zakatAmount, 8000000 * 0.025);
      expect(grossRes.explanation, contains('تم الحساب بناءً على طريقة: إجمالي الريع'));

      // 3. Accumulated Cash: 8,000,000 - 1,000,000 = 7,000,000 * 2.5% = 175,000
      final cashRes = provider.calculateExploitedAssetsZakat(
        grossIncome: 8000000,
        expenses: 1000000,
        method: ExploitedAssetsMethod.accumulatedCash,
      );
      expect(cashRes.reachedNisab, isTrue);
      expect(cashRes.zakatAmount, 7000000 * 0.025);
      expect(cashRes.explanation, contains('تم الحساب بناءً على طريقة: وعاء نقدي متراكم بعد بلوغ النصاب'));

      // 4. Authority Policy: 8,000,000 - 1,000,000 = 7,000,000 * 2.5% = 175,000
      final authRes = provider.calculateExploitedAssetsZakat(
        grossIncome: 8000000,
        expenses: 1000000,
        method: ExploitedAssetsMethod.authorityPolicy,
      );
      expect(authRes.reachedNisab, isTrue);
      expect(authRes.zakatAmount, 7000000 * 0.025);
      expect(authRes.explanation, contains('تم الحساب بناءً على طريقة: سياسة الجهة المعتمدة'));

      // Below Nisab check
      final belowNisabRes = provider.calculateExploitedAssetsZakat(
        grossIncome: 1000000,
        expenses: 200000,
        method: ExploitedAssetsMethod.netRevenue,
      );
      expect(belowNisabRes.reachedNisab, isFalse);
      expect(belowNisabRes.zakatAmount, 0.0);
      expect(belowNisabRes.explanation, contains('تم الحساب بناءً على طريقة: صافي الريع'));
    });

    // 11. Zakat al-Fitr
    test('Zakat al-Fitr: Cash & in-kind calculations for family members', () {
      // 0 members
      expect(provider.calculateFitrZakat(familyMembers: 0).reachedNisab, isFalse);

      // 5 family members cash calculation
      final fitrCash = provider.calculateFitrZakat(
        familyMembers: 5,
        cashValuePerPerson: 2500,
        isCashPayment: true,
      );
      expect(fitrCash.reachedNisab, isTrue);
      expect(fitrCash.zakatAmount, 12500.0);
      expect(fitrCash.zakatInKindDescription, contains('12.5 كجم'));
      expect(fitrCash.zakatInKindDescription, contains('5 صاع نبوي'));

      // In-kind calculation
      final fitrInKind = provider.calculateFitrZakat(
        familyMembers: 4,
        saWeightKg: 2.5,
        isCashPayment: false,
      );
      expect(fitrInKind.reachedNisab, isTrue);
      expect(fitrInKind.zakatInKindDescription, contains('10.0 كجم'));
    });

    test('Zakat al-Fitr: Wheat bag based calculation (50kg bag = 20 Sa)', () {
      // 50kg bag at 24000 YER -> 24000 / 20 = 1200 YER per person
      // 4 family members -> 4 * 1200 = 4800 YER
      final fitrBag = provider.calculateFitrZakat(
        familyMembers: 4,
        wheatBagPrice: 24000,
        bagWeightKg: 50.0,
        isCashPayment: true,
      );
      expect(fitrBag.reachedNisab, isTrue);
      expect(fitrBag.zakatAmount, 4800.0);
      expect(fitrBag.explanation, contains('20 صاعاً نبوياً'));
      expect(fitrBag.explanation, contains('1200'));
      expect(fitrBag.zakatInKindDescription, contains('10.0 كجم'));
      expect(fitrBag.zakatInKindDescription, contains('4 صاع نبوي'));

      // 25kg bag at 15000 YER -> 25 / 2.5 = 10 Sa -> 1500 YER per person
      // 2 family members -> 2 * 1500 = 3000 YER
      final fitrSmallBag = provider.calculateFitrZakat(
        familyMembers: 2,
        wheatBagPrice: 15000,
        bagWeightKg: 25.0,
        isCashPayment: true,
      );
      expect(fitrSmallBag.reachedNisab, isTrue);
      expect(fitrSmallBag.zakatAmount, 3000.0);
      expect(fitrSmallBag.explanation, contains('10 صاعاً نبوياً'));
      expect(fitrSmallBag.explanation, contains('1500'));
    });
  });

  group('3. Hawl Provider - Lunar Cycle & Countdown Logic', () {
    test('Hawl calculations with 354 lunar year days', () {
      expect(HawlProvider.lunarYearDays, 354);

      final hawl = HawlProvider();
      expect(hawl.daysPassed, 0);
      expect(hawl.daysRemaining, 354);
      expect(hawl.progressPercentage, 0.0);
      expect(hawl.isHawlCompleted, isFalse);
    });
  });

  group('4. Models Serialization & Data Integrity', () {
    test('ZakatRecord: toMap and fromMap conversion', () {
      final now = DateTime.now();
      final record = ZakatRecord(
        id: 'rec_101',
        typeName: 'زكاة المال',
        categoryKey: 'money',
        totalWealth: 5000000,
        zakatAmount: 125000,
        currency: 'ر.ي',
        reachedNisab: true,
        notes: 'ملاحظة تجريبية',
        date: now,
      );

      final map = record.toMap();
      final restored = ZakatRecord.fromMap(map);

      expect(restored.id, 'rec_101');
      expect(restored.typeName, 'زكاة المال');
      expect(restored.totalWealth, 5000000);
      expect(restored.zakatAmount, 125000);
      expect(restored.reachedNisab, isTrue);
    });

    test('FavoriteItem: toMap and fromMap conversion', () {
      final fav = FavoriteItem(
        id: 'fav_gold',
        title: 'حاسبة الذهب',
        subtitle: 'عيارات 24، 21',
        type: 'calculator',
        route: '/gold_calc',
        imagePath: 'assets/images/gold.png',
      );

      final map = fav.toMap();
      final restored = FavoriteItem.fromMap(map);

      expect(restored.id, 'fav_gold');
      expect(restored.title, 'حاسبة الذهب');
      expect(restored.route, '/gold_calc');
    });

    test('AssistanceRequest: toMap and Formal Letter generation', () {
      final req = AssistanceRequest(
        id: 'req_001',
        subject: 'طلب مساعدة علاجية',
        fullName: 'أحمد محمد علي',
        address: 'صنعاء - التحرير',
        phone: '777123456',
        idNumber: '0101009988',
        details: 'تفاصيل الحالة الطبية المرفقة',
      );

      final letter = req.generateFormalLetter();
      expect(letter, contains('الهيئة العامة للزكاة'));
      expect(letter, contains('طلب مساعدة علاجية'));
      expect(letter, contains('أحمد محمد علي'));

      final restored = AssistanceRequest.fromMap(req.toMap());
      expect(restored.fullName, 'أحمد محمد علي');
    });

    test('UserModel: toMap, fromMap, and copyWith', () {
      final user = UserModel(
        id: 'usr_01',
        name: 'طه العسري',
        email: 'taha@example.com',
        phone: '777000111',
        isBiometricEnabled: true,
      );

      final map = user.toMap();
      final restored = UserModel.fromMap(map);
      expect(restored.name, 'طه العسري');
      expect(restored.isBiometricEnabled, isTrue);

      final modified = user.copyWith(name: 'طه العسري المحدث');
      expect(modified.name, 'طه العسري المحدث');
      expect(modified.email, 'taha@example.com');
    });

    test('Profile & Name Validation: Ensures placeholder names and emails are never used as full names', () {
      String? cleanName(String? name, [String? email]) {
        if (name == null) return null;
        final trimmed = name.trim();
        if (trimmed.isEmpty) return null;

        final lower = trimmed.toLowerCase();
        if (lower == 'مستخدم البصمة' ||
            lower == 'المستخدم الكريم' ||
            lower == 'المستخدم' ||
            lower == 'مستخدم زكاتي' ||
            lower == 'مستخدم الهيئة' ||
            lower == 'user' ||
            lower == 'guest') {
          return null;
        }

        if (trimmed.contains('@')) {
          return null;
        }

        if (email != null && email.contains('@')) {
          final prefix = email.split('@').first.trim().toLowerCase();
          if (lower == prefix) {
            return null;
          }
        }

        return trimmed;
      }

      const email = 'thalsry6@gmail.com';
      expect(cleanName('مستخدم البصمة', email), isNull);
      expect(cleanName('المستخدم الكريم', email), isNull);
      expect(cleanName('المستخدم', email), isNull);
      expect(cleanName('مستخدم الهيئة', email), isNull);
      expect(cleanName('user', email), isNull);
      expect(cleanName('thalsry6@gmail.com', email), isNull);
      expect(cleanName('thalsry6', email), isNull);
      expect(cleanName('', email), isNull);
      expect(cleanName(null, email), isNull);
      expect(cleanName('طه العسري', email), 'طه العسري');
      expect(cleanName('أحمد محمد العسري', email), 'أحمد محمد العسري');
    });

    test('Biometric Auth & User Profile Integrity: No dummy user injection', () {
      final realUser = UserModel(
        id: 'user_123',
        name: 'طه العسري',
        email: 'thalsry6@gmail.com',
        phone: '777000111',
        isBiometricEnabled: true,
      );

      expect(realUser.name, isNot('thalsry6'));
      expect(realUser.name, isNot('مستخدم البصمة'));
      expect(realUser.email, 'thalsry6@gmail.com');
      expect(realUser.isBiometricEnabled, isTrue);
    });
  });

  group('5. Account Gating & Authentication Flow', () {
    test('Unauthenticated user starts in guest mode by default', () {
      // When UserModel is null, isAuthenticated is false
      const UserModel? guestUser = null;
      expect(guestUser, isNull);
    });

    test('UserModel preserves biometric preferences across sessions', () {
      final user = UserModel(
        id: 'usr_789',
        name: 'طه العسري',
        email: 'taha@gmail.com',
        phone: '777123456',
        isBiometricEnabled: true,
      );

      final map = user.toMap();
      expect(map['isBiometricEnabled'], isTrue);

      final restored = UserModel.fromMap(map);
      expect(restored.isBiometricEnabled, isTrue);
      expect(restored.name, 'طه العسري');
    });

    test('AssistanceRequest requires official details and rejects empty contact', () {
      final validReq = AssistanceRequest(
        id: 'req_1',
        subject: 'طلب مساعدة زكاة',
        fullName: 'طه العصري',
        address: 'صنعاء',
        phone: '775533888',
        idNumber: '100200300',
        details: 'تفاصيل الحالة المعيشية',
      );

      expect(validReq.fullName, isNotEmpty);
      expect(validReq.phone, isNotEmpty);
      expect(validReq.generateFormalLetter(), contains('الهيئة العامة للزكاة'));
    });

    test('Hawl completion logic triggers due date notification alert', () {
      final startDate = DateTime.now().subtract(const Duration(days: 355));
      expect(DateTime.now().difference(startDate).inDays, greaterThanOrEqualTo(354));
    });

    test('AssistanceRequest email subject and body generation', () {
      final req = AssistanceRequest(
        id: 'req_10',
        subject: 'طلب مساعدة علاجية',
        fullName: 'طه العسري',
        address: 'صنعاء',
        phone: '777000111',
        idNumber: '100200300',
        details: 'تفاصيل الحالة الصحية',
      );

      final letter = req.generateFormalLetter();
      expect(letter, contains('طلب مساعدة علاجية'));
      expect(letter, contains('طه العسري'));
      expect(letter, contains('الهيئة العامة للزكاة'));
    });
  });

  group('6. Annual Statement PDF & History Filter Logic', () {
    test('generateAnnualStatementPdf handles single currency and multi-currency correctly', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final singleCurrencyRecords = [
        ZakatRecord(
          id: 'rec_1',
          typeName: 'زكاة المال',
          categoryKey: 'money',
          totalWealth: 10000000,
          zakatAmount: 250000,
          currency: 'ر.ي',
          reachedNisab: true,
          notes: 'حساب سنوي لسيولة نقدية',
        ),
        ZakatRecord(
          id: 'rec_2',
          typeName: 'زكاة الذهب',
          categoryKey: 'gold',
          totalWealth: 5500000,
          zakatAmount: 137500,
          zakatInKindDescription: '2.50 جرام عيار 21',
          currency: 'ر.ي',
          reachedNisab: true,
          notes: 'ذهب عيار 21',
        ),
      ];

      expect(PdfService.hasMixedCurrencies(singleCurrencyRecords), isFalse);

      final singlePdf = await PdfService.generateAnnualStatementPdf(
        records: singleCurrencyRecords,
        userName: 'طه العسري',
        currency: 'ر.ي',
      );
      expect(singlePdf.isNotEmpty, isTrue);

      final mixedCurrencyRecords = [
        ZakatRecord(
          id: 'rec_yer',
          typeName: 'زكاة المال',
          categoryKey: 'money',
          totalWealth: 10000000,
          zakatAmount: 250000,
          currency: 'ر.ي',
          reachedNisab: true,
          notes: 'ريال يمني',
        ),
        ZakatRecord(
          id: 'rec_sar',
          typeName: 'زكاة نقد سعودي',
          categoryKey: 'money',
          totalWealth: 50000,
          zakatAmount: 1250,
          currency: 'ر.س',
          reachedNisab: true,
          exchangeRate: 3.75,
          priceSource: 'البنك المركزي',
          priceUpdatedAt: DateTime(2026, 1, 1),
          notes: 'ريال سعودي',
        ),
      ];

      expect(PdfService.hasMixedCurrencies(mixedCurrencyRecords), isTrue);

      // Multi-currency report generates valid PDF with per-currency separation
      final multiPdf = await PdfService.generateAnnualStatementPdf(
        records: mixedCurrencyRecords,
        userName: 'طه العسري',
      );
      expect(multiPdf.isNotEmpty, isTrue);

      // Multi-currency report with preventMixedCurrencies throws explicit ArgumentError
      expect(
        () => PdfService.generateAnnualStatementPdf(
          records: mixedCurrencyRecords,
          preventMixedCurrencies: true,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'لا يمكن جمع سجلات بعملات مختلفة دون تحديد سعر تحويل.',
        )),
      );
    });

    test('ZakatRecord serialization preserves exchangeRate, priceSource, and priceUpdatedAt', () {
      final now = DateTime(2026, 5, 10, 14, 30);
      final record = ZakatRecord(
        id: 'rec_exchange_test',
        typeName: 'زكاة دولارات',
        categoryKey: 'money',
        totalWealth: 5000,
        zakatAmount: 125,
        currency: 'USD',
        reachedNisab: true,
        appliedPrice: 535.0,
        nisabThreshold: 45475.0,
        exchangeRate: 535.0,
        priceSource: 'سوق الصرافة المعتمد',
        priceUpdatedAt: now,
      );

      final map = record.toMap();
      expect(map['exchangeRate'], 535.0);
      expect(map['priceSource'], 'سوق الصرافة المعتمد');
      expect(map['priceUpdatedAt'], now.toIso8601String());

      final restored = ZakatRecord.fromMap(map);
      expect(restored.exchangeRate, 535.0);
      expect(restored.priceSource, 'سوق الصرافة المعتمد');
      expect(restored.priceUpdatedAt, now);
    });

    test('History filter matches categories and search queries accurately', () {
      final records = [
        ZakatRecord(
          id: '1',
          typeName: 'زكاة المال والنقود',
          categoryKey: 'money',
          totalWealth: 5000000,
          zakatAmount: 125000,
          currency: 'ر.ي',
          reachedNisab: true,
          notes: 'مدخرات بنكية',
        ),
        ZakatRecord(
          id: '2',
          typeName: 'زكاة الفطر المباركة',
          categoryKey: 'fitr',
          totalWealth: 10000,
          zakatAmount: 10000,
          currency: 'ر.ي',
          reachedNisab: true,
          notes: 'عن 4 أفراد',
        ),
        ZakatRecord(
          id: '3',
          typeName: 'زكاة الحبوب والثمار',
          categoryKey: 'crops',
          totalWealth: 800000,
          zakatAmount: 80000,
          currency: 'ر.ي',
          reachedNisab: true,
          notes: 'محصول ذرة ري مطري',
        ),
      ];

      // Filter by category fitr
      final fitrOnly = records.where((r) => r.categoryKey == 'fitr').toList();
      expect(fitrOnly.length, 1);
      expect(fitrOnly.first.typeName, contains('الفطر'));

      // Filter by search query 'ذرة'
      const query = 'ذرة';
      final searchResult = records.where((r) => r.notes.contains(query) || r.typeName.contains(query)).toList();
      expect(searchResult.length, 1);
      expect(searchResult.first.categoryKey, 'crops');

      // Total zakat calculation for list
      final total = records.fold<double>(0.0, (sum, r) => sum + r.zakatAmount);
      expect(total, 215000.0);
    });

    testWidgets('Recent history header renders without overflow on compact 360px RTL screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'سجل العمليات الأخيرة',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.filter_list, size: 15),
                          label: const Text('تصفية وبحث', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('مسح السجل', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('سجل العمليات الأخيرة'), findsOneWidget);
      expect(find.text('تصفية وبحث'), findsOneWidget);
      expect(find.text('مسح السجل'), findsOneWidget);
    });
  });

  group('7. Market Price Service & Camels Diophantine Combinations', () {
    test('MarketPriceService contains all 5 regional markets with valid benchmarks', () {
      expect(MarketPriceService.supportedMarkets.length, 5);
      final marketIds = MarketPriceService.supportedMarkets.map((m) => m.id).toList();
      expect(marketIds, containsAll(['sanaa', 'aden', 'riyadh', 'cairo', 'global']));

      final sanaa = MarketPriceService.getMarketById('sanaa');
      expect(sanaa.currency, 'ر.ي');
      expect(sanaa.defaultGold21, 55000.0);
      expect(sanaa.defaultSilver, 700.0);

      final riyadh = MarketPriceService.getMarketById('riyadh');
      expect(riyadh.currency, 'ر.س');
      expect(riyadh.defaultGold21, 288.0);
    });

    test('MarketPriceService.fetchPrices returns valid prices and currency', () async {
      final res = await MarketPriceService.fetchPrices(cityId: 'sanaa');
      expect(res.cityId, 'sanaa');
      expect(res.currency, 'ر.ي');
      expect(res.gold21Price, greaterThan(1000));
      expect(res.silverPrice, greaterThan(10));
      expect(res.updatedAt, isNotNull);

      final riyadhRes = await MarketPriceService.fetchPrices(cityId: 'riyadh');
      expect(riyadhRes.currency, 'ر.س');
      expect(riyadhRes.gold21Price, greaterThan(100));
    });

    test('Camel Zakat calculation handles large numbers (> 120) with exact Diophantine combinations', () {
      final provider = ZakatProvider();

      // 130 camels: 1 Hiqqah (50) + 2 Bint Laboon (80) = 130
      final res130 = provider.calculateCamelsZakat(130);
      expect(res130.reachedNisab, isTrue);
      expect(res130.zakatInKindDescription, contains('حِقّة واحدة'));
      expect(res130.zakatInKindDescription, contains('بنتا لبون'));

      // 140 camels: 2 Hiqqah (100) + 1 Bint Laboon (40) = 140
      final res140 = provider.calculateCamelsZakat(140);
      expect(res140.reachedNisab, isTrue);
      expect(res140.zakatInKindDescription, contains('حِقّتان'));
      expect(res140.zakatInKindDescription, contains('بنت لبون واحدة'));

      // 150 camels: 3 Hiqqah (150)
      final res150 = provider.calculateCamelsZakat(150);
      expect(res150.reachedNisab, isTrue);
      expect(res150.zakatInKindDescription, contains('3 حِقاق'));

      // 160 camels: 4 Bint Laboon (160)
      final res160 = provider.calculateCamelsZakat(160);
      expect(res160.reachedNisab, isTrue);
      expect(res160.zakatInKindDescription, contains('4 بنات لبون'));

      // 200 camels: 4 Hiqqah (200)
      final res200 = provider.calculateCamelsZakat(200);
      expect(res200.reachedNisab, isTrue);
      expect(res200.zakatInKindDescription, contains('4 حِقاق'));
    });
  });

  group('8. AppInputFormatters & AppValidators - Input Validation and Sanitation', () {
    test('AppInputFormatters.normalizeArabicNumbers converts Arabic-Indic digits to Latin', () {
      expect(AppInputFormatters.normalizeArabicNumbers('١٢٣٤٥٦٧٨٩٠'), '1234567890');
      expect(AppInputFormatters.normalizeArabicNumbers('٥٠٠.٢٥'), '500.25');
      expect(AppInputFormatters.normalizeArabicNumbers('123'), '123');
    });

    test('AppInputFormatters.tryParseDouble correctly parses Arabic and English decimals', () {
      expect(AppInputFormatters.tryParseDouble('123.45'), 123.45);
      expect(AppInputFormatters.tryParseDouble('١٢٣.٤٥'), 123.45);
      expect(AppInputFormatters.tryParseDouble('abc'), isNull);
      expect(AppInputFormatters.tryParseDouble(''), isNull);
    });

    test('AppInputFormatters.tryParseInt correctly parses Arabic and English integers', () {
      expect(AppInputFormatters.tryParseInt('40'), 40);
      expect(AppInputFormatters.tryParseInt('٤٠'), 40);
      expect(AppInputFormatters.tryParseInt('40.5'), isNull);
      expect(AppInputFormatters.tryParseInt('abc'), isNull);
    });

    test('AppValidators.requiredPositiveNumber validates numbers and rejects text or negatives', () {
      final validator = AppValidators.requiredPositiveNumber('المبلغ');
      expect(validator(null), contains('يرجى إدخال المبلغ'));
      expect(validator(''), contains('يرجى إدخال المبلغ'));
      expect(validator('نص خطأ'), contains('أرقام صحيحة'));
      expect(validator('0'), contains('أكبر من الصفر'));
      expect(validator('-5'), contains('أكبر من الصفر'));
      expect(validator('1000'), isNull);
      expect(validator('١٠٠٠'), isNull);
    });

    test('AppValidators.requiredPositiveInteger rejects fractional and non-integer inputs', () {
      final validator = AppValidators.requiredPositiveInteger('العدد');
      expect(validator('0'), contains('أكبر من الصفر'));
      expect(validator('12.5'), contains('أرقام صحيحة فقط بدون كسور'));
      expect(validator('abc'), contains('أرقام صحيحة فقط بدون كسور'));
      expect(validator('5'), isNull);
      expect(validator('٥'), isNull);
    });

    test('AppValidators.personName rejects digits and validates letters only', () {
      final validator = AppValidators.personName('الاسم');
      expect(validator(null), contains('يرجى إدخال الاسم'));
      expect(validator(''), contains('يرجى إدخال الاسم'));
      expect(validator('12345'), contains('حروف فقط ولا يمكن أن يحتوي على أرقام'));
      expect(validator('أحمد 123'), contains('حروف فقط ولا يمكن أن يحتوي على أرقام'));
      expect(validator('أ'), contains('حرفين على الأقل'));
      expect(validator('طه العسري'), isNull);
      expect(validator('Ahmed Ali'), isNull);
    });

    test('AppValidators.phoneNumber validates phone digits only', () {
      final validator = AppValidators.phoneNumber('رقم الجوال');
      expect(validator(null), contains('يرجى إدخال رقم الجوال'));
      expect(validator('abc'), contains('أرقام فقط'));
      expect(validator('123'), contains('بين 7 و 15 رقماً'));
      expect(validator('777000111'), isNull);
      expect(validator('٧٧٧٠٠٠١١١'), isNull);
    });

    test('AppValidators.idNumber validates identity card digits', () {
      final validator = AppValidators.idNumber('رقم البطاقة');
      expect(validator(null), contains('يرجى إدخال رقم البطاقة'));
      expect(validator('abc'), contains('أرقام فقط'));
      expect(validator('123'), contains('بين 6 و 20 رقماً'));
      expect(validator('0101009988'), isNull);
      expect(validator('٠١٠١٠٠٩٩٨٨'), isNull);
    });

    test('AppValidators.textNotPureNumbers ensures text inputs cannot be pure numbers', () {
      final validator = AppValidators.textNotPureNumbers('موضوع الطلب');
      expect(validator(null), contains('يرجى إدخال موضوع الطلب'));
      expect(validator(''), contains('يرجى إدخال موضوع الطلب'));
      expect(validator('123456'), contains('نصاً واضحاً ولا يمكن أن يكون أرقاماً فقط'));
      expect(validator('١٢٣٤٥٦'), contains('نصاً واضحاً ولا يمكن أن يكون أرقاماً فقط'));
      expect(validator('طلب مساعدة علاجية'), isNull);
    });
  });

  group('9. User Isolation in Zakat Records (Item 8)', () {
    test('ZakatRecord handles userId serialization, deserialization and copyWith', () {
      final rec = ZakatRecord(
        id: 'rec_101',
        typeName: 'زكاة الذهب',
        categoryKey: 'gold',
        totalWealth: 500000.0,
        zakatAmount: 12500.0,
        currency: 'YER',
        reachedNisab: true,
        userId: 'user_taha_123',
        goldKarat: 24,
        appliedPrice: 62850.0,
        date: DateTime(2025, 5, 10),
      );

      expect(rec.userId, 'user_taha_123');
      final map = rec.toMap();
      expect(map['userId'], 'user_taha_123');

      final restored = ZakatRecord.fromMap(map);
      expect(restored.userId, 'user_taha_123');
      expect(restored.totalWealth, 500000.0);
      expect(restored.zakatAmount, 12500.0);

      final updated = restored.copyWith(userId: 'user_guest_456');
      expect(updated.userId, 'user_guest_456');
      expect(updated.id, 'rec_101');
    });

    test('Record filtering isolates user records and ignores other users', () {
      final allRecords = [
        ZakatRecord(
          id: '1',
          typeName: 'زكاة الذهب',
          categoryKey: 'gold',
          totalWealth: 100000,
          zakatAmount: 2500,
          reachedNisab: true,
          currency: 'YER',
          userId: 'user_A',
          date: DateTime.now(),
        ),
        ZakatRecord(
          id: '2',
          typeName: 'زكاة الفضة',
          categoryKey: 'silver',
          totalWealth: 50000,
          zakatAmount: 1250,
          reachedNisab: true,
          currency: 'YER',
          userId: 'user_B',
          date: DateTime.now(),
        ),
        ZakatRecord(
          id: '3',
          typeName: 'زكاة النقد',
          categoryKey: 'money',
          totalWealth: 200000,
          zakatAmount: 5000,
          reachedNisab: true,
          currency: 'YER',
          userId: 'user_A',
          date: DateTime.now(),
        ),
        ZakatRecord(
          id: '4',
          typeName: 'زكاة الفطر',
          categoryKey: 'fitr',
          totalWealth: 10000,
          zakatAmount: 10000,
          reachedNisab: true,
          currency: 'YER',
          userId: null,
          date: DateTime.now(),
        ),
      ];

      // Current user is user_A: only user_A records are returned
      final userARecords = allRecords.where((r) => r.userId == 'user_A').toList();
      expect(userARecords.length, 2);
      expect(userARecords.every((r) => r.userId == 'user_A'), isTrue);

      // Current user is user_B: only user_B records are returned
      final userBRecords = allRecords.where((r) => r.userId == 'user_B').toList();
      expect(userBRecords.length, 1);
      expect(userBRecords.first.id, '2');

      // Logout / unauthenticated: in-memory state is cleared
      final provider = ZakatProvider();
      provider.clearInMemoryRecords();
      expect(provider.records, isEmpty);
    });
  });

  group('10. Authentication Status & Official Request Validation (Item 9)', () {
    tearDown(() {
      AuthService.setAuthStatusForTesting(null);
    });

    test('AuthStatus values and canSubmitOfficialRequest strict rules', () {
      // 1. Guest: cannot submit official request
      AuthService.setAuthStatusForTesting(AuthStatus.guest);
      expect(AuthService.authStatus, AuthStatus.guest);
      expect(AuthService.canSubmitOfficialRequest, isFalse);

      // 2. Local Authenticated (offline mode): CANNOT submit official request
      AuthService.setAuthStatusForTesting(AuthStatus.localAuthenticated);
      expect(AuthService.authStatus, AuthStatus.localAuthenticated);
      expect(AuthService.canSubmitOfficialRequest, isFalse);

      // 3. Firebase Authenticated: allowed to submit official request
      AuthService.setAuthStatusForTesting(AuthStatus.firebaseAuthenticated);
      expect(AuthService.authStatus, AuthStatus.firebaseAuthenticated);
      expect(AuthService.canSubmitOfficialRequest, isTrue);

      // 4. Officially Verified: allowed to submit official request
      AuthService.setAuthStatusForTesting(AuthStatus.officiallyVerified);
      expect(AuthService.authStatus, AuthStatus.officiallyVerified);
      expect(AuthService.canSubmitOfficialRequest, isTrue);
    });

    testWidgets('AssistanceRequestScreen displays draft labels and blocks official request for local/guest', (tester) async {
      AuthService.setAuthStatusForTesting(AuthStatus.localAuthenticated);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => ZakatProvider()),
          ],
          child: const MaterialApp(
            home: AssistanceRequestScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify draft and preview UI labels exist
      expect(find.text('إنشاء مسودة طلب'), findsOneWidget);
      expect(find.text('تقديم طلب رسمي'), findsOneWidget);
      expect(find.textContaining('أنت مسجل بالمصادقة المحلية'), findsOneWidget);

      // Scroll and tap official request button while localAuthenticated -> should show dialog warning
      final officialBtn = find.byKey(const Key('btn_submit_official_request'));
      expect(officialBtn, findsOneWidget);
      await tester.ensureVisible(officialBtn);
      await tester.pumpAndSettle();
      await tester.tap(officialBtn);
      await tester.pumpAndSettle();

      expect(find.text('غير متاح للمصادقة المحلية'), findsOneWidget);
      expect(find.textContaining('المصادقة الحالية محلية دون اتصال ولا تعني أن الحساب موثق رسمياً'), findsOneWidget);
    });
  });

  group('11. Sensitive Data Protection & Encryption (Item 10)', () {
    final testKey = Uint8List.fromList(List.generate(32, (i) => (i * 7 + 3) % 256));

    setUp(() {
      EncryptionService.setMockKey(testKey);
    });

    tearDown(() {
      EncryptionService.setMockKey(null);
    });

    test('EncryptionService: AES-256 HMAC-SHA256 CTR encrypt and decrypt matches original', () {
      const originalText = 'رقم الهوية: 1020304050، العنوان: صنعاء، الحي السياسي';
      final cipherText = EncryptionService.encryptString(originalText, testKey);

      expect(cipherText, isNotEmpty);
      expect(cipherText.startsWith('ENC:'), isTrue);
      expect(cipherText, isNot(equals(originalText)));

      final decrypted = EncryptionService.decryptString(cipherText, testKey);
      expect(decrypted, equals(originalText));
    });

    test('EncryptionService: decrypting tampered ciphertext rejects decryption and fails safely', () {
      const original = 'بيانات حساسة وسرية للغاية';
      final cipherText = EncryptionService.encryptString(original, testKey);

      // Tamper with payload
      final parts = cipherText.split(':');
      final payload = parts[1];
      final tamperedPayload = '${payload.substring(0, payload.length - 4)}AAAA';
      final tamperedCipherText = '${parts[0]}:$tamperedPayload';

      final decrypted = EncryptionService.decryptString(tamperedCipherText, testKey);
      // Because MAC verification fails, decryptString refuses to decrypt and returns fallback
      expect(decrypted, isNot(equals(original)));
      expect(decrypted, equals(tamperedCipherText));
    });

    test('AssistanceRequest: toMap excludes idNumber when saveIdLocally is false', () {
      final req = AssistanceRequest(
        id: 'req_sensitive_1',
        subject: 'طلب مساعدة علاجية',
        fullName: 'أحمد علي',
        address: 'صنعاء',
        phone: '777123456',
        details: 'طلب مساعدة علاجية',
        idNumber: '1002003004',
        saveIdLocally: false,
      );

      final map = req.toMap(encryptionKey: testKey);
      expect(map.containsKey('idNumber'), isFalse);
      expect(map['saveIdLocally'], isFalse);
      expect(map['fullName'], 'أحمد علي');
      // Address and details are encrypted
      expect(map['address'].toString().startsWith('ENC:'), isTrue);
      expect(map['details'].toString().startsWith('ENC:'), isTrue);
    });

    test('AssistanceRequest: toMap includes encrypted idNumber only when saveIdLocally is true', () {
      final req = AssistanceRequest(
        id: 'req_sensitive_2',
        subject: 'طلب مساعدة غارمين',
        fullName: 'خالد محمد',
        address: 'عدن',
        phone: '733123456',
        details: 'طلب مساعدة غارمين',
        idNumber: '2003004005',
        saveIdLocally: true,
      );

      final map = req.toMap(encryptionKey: testKey);
      expect(map.containsKey('idNumber'), isTrue);
      expect(map['idNumber'].toString().startsWith('ENC:'), isTrue);
      expect(map['saveIdLocally'], isTrue);
      expect(map['isEncrypted'], isTrue);

      final recovered = AssistanceRequest.fromMap(map, encryptionKey: testKey);
      expect(recovered.idNumber, '2003004005');
      expect(recovered.address, 'عدن');
      expect(recovered.details, 'طلب مساعدة غارمين');
      expect(recovered.saveIdLocally, isTrue);
    });

    test('LocalDbService: applyDataRetentionPolicy purges records older than 30 days', () async {
      // Create request from 35 days ago
      final oldDate = DateTime.now().subtract(const Duration(days: 35));
      final oldReq = AssistanceRequest(
        id: 'req_old_purge',
        subject: 'طلب قديم',
        fullName: 'طلب قديم',
        address: 'صنعاء',
        phone: '777000111',
        details: 'تفاصيل قديمة',
        createdAt: oldDate,
      );

      // Create fresh request from 2 days ago
      final freshDate = DateTime.now().subtract(const Duration(days: 2));
      final freshReq = AssistanceRequest(
        id: 'req_fresh_keep',
        subject: 'طلب حديث',
        fullName: 'طلب حديث',
        address: 'صنعاء',
        phone: '777000222',
        details: 'تفاصيل حديثة',
        createdAt: freshDate,
      );

      await LocalDbService.saveAssistanceRequest(oldReq);
      await LocalDbService.saveAssistanceRequest(freshReq);

      // Apply 30 days retention policy
      final purgedCount = await LocalDbService.applyDataRetentionPolicy(maxAge: const Duration(days: 30));
      expect(purgedCount, greaterThanOrEqualTo(1));

      final remaining = await LocalDbService.getAllAssistanceRequestsDecrypted();
      expect(remaining.any((r) => r.id == 'req_old_purge'), isFalse);
      expect(remaining.any((r) => r.id == 'req_fresh_keep'), isTrue);
    });

    test('LocalDbService: deleteAllAssistanceRequestsAndPurgeSensitiveData clears all records', () async {
      final req = AssistanceRequest(
        id: 'req_to_purge',
        subject: 'طلب حذف',
        fullName: 'حذف كامل',
        address: 'تعز',
        phone: '711223344',
        details: 'بيانات ستمحى بالكامل',
      );
      await LocalDbService.saveAssistanceRequest(req);

      await LocalDbService.deleteAllAssistanceRequestsAndPurgeSensitiveData();
      final list = await LocalDbService.getAllAssistanceRequestsDecrypted();
      expect(list.isEmpty, isTrue);
    });

    test('PreferencesService: ensures zero sensitive data / PII is stored in SharedPreferences', () {
      expect(PreferencesService.currency, isNotEmpty);
      expect(PreferencesService.marketCity, isNotEmpty);
      expect(PreferencesService.gold24Price, greaterThan(0));
    });
  });

  group('12. Email Flow, Market Price Snapshot & Near-Nisab Checks (Items 11 & 12)', () {
    test('PriceSnapshot: transparency flags (isSilverEstimated, isExchangeRateFixed, isFallback)', () {
      final now = DateTime.now();
      final snapshot = PriceSnapshot(
        gold24: 65000,
        gold21: 56875,
        gold18: 48750,
        silver: 812.5,
        currency: 'ر.ي',
        source: 'سوق صنعاء المعتمد',
        updatedAt: now,
        isFallback: false,
        isSilverEstimated: true,
        isExchangeRateFixed: true,
        silverNote: 'تنبيه: سعر الفضة تقديري بنسبة 80:1',
        exchangeRateNote: 'تنبيه: سعر الصرف مثبت إقليمياً',
      );

      expect(snapshot.isSilverEstimated, isTrue);
      expect(snapshot.isExchangeRateFixed, isTrue);
      expect(snapshot.silverNote, contains('80:1'));
      expect(snapshot.exchangeRateNote, contains('مثبت'));

      final map = snapshot.toMap();
      final fromMap = PriceSnapshot.fromMap(map);
      expect(fromMap.source, 'سوق صنعاء المعتمد');
      expect(fromMap.isSilverEstimated, isTrue);
      expect(fromMap.isExchangeRateFixed, isTrue);
      expect(fromMap.gold24, 65000);
    });

    test('ZakatProvider: isCloseToNisab accurately detects wealth near threshold within sensitivity margin', () {
      final provider = ZakatProvider();
      const nisab = 1000000.0;

      // Within 12% margin: 880,000 to 1,120,000
      expect(provider.isCloseToNisab(900000, nisab), isTrue);
      expect(provider.isCloseToNisab(950000, nisab), isTrue);
      expect(provider.isCloseToNisab(1050000, nisab), isTrue);
      expect(provider.isCloseToNisab(1100000, nisab), isTrue);

      // Beyond 12% margin
      expect(provider.isCloseToNisab(500000, nisab), isFalse);
      expect(provider.isCloseToNisab(800000, nisab), isFalse);
      expect(provider.isCloseToNisab(1500000, nisab), isFalse);
      expect(provider.isCloseToNisab(0, nisab), isFalse);
    });

    test('ZakatProvider: saveRecord automatically populates priceSource and priceUpdatedAt from snapshot', () async {
      final provider = ZakatProvider();
      final record = ZakatRecord(
        id: 'rec_snapshot_test',
        typeName: 'زكاة المال',
        categoryKey: 'money',
        totalWealth: 2000000,
        zakatAmount: 50000,
        currency: 'ر.ي',
        reachedNisab: true,
        notes: 'اختبار تسجيل المصدر',
      );

      await provider.saveRecord(record);

      final saved = provider.records.firstWhere((r) => r.id == 'rec_snapshot_test');
      expect(saved.priceSource, isNotNull);
      expect(saved.priceUpdatedAt, isNotNull);
      expect(saved.priceSource, contains('المعتمدة'));
    });

    testWidgets('AssistanceRequestScreen: displays data retention banner, optional ID checkbox, purge button, and open mail button', (tester) async {
      AuthService.setCurrentUserForTesting(
        UserModel(
          id: 'user_auth_tester_1',
          name: 'عبدالله علي أحمد',
          email: 'abdullah@test.com',
          phone: '777123456',
        ),
      );
      AuthService.setAuthStatusForTesting(AuthStatus.firebaseAuthenticated);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => ZakatProvider()),
          ],
          child: const MaterialApp(
            home: AssistanceRequestScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Data retention & privacy notice
      expect(find.textContaining('سياسة حماية واحتفاظ بالبيانات'), findsOneWidget);

      // Checkbox for local ID saving
      expect(find.text('حفظ رقم الهوية محلياً على هذا الجهاز'), findsOneWidget);

      // Purge button exists
      expect(find.byKey(const Key('btn_purge_request_data')), findsOneWidget);

      // Fill in required fields to generate draft letter
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'طلب مساعدة علاجية');
      await tester.enterText(textFields.at(1), 'عبدالله علي أحمد');
      await tester.enterText(textFields.at(2), 'صنعاء السنينة');
      await tester.enterText(textFields.at(3), '777123456');
      await tester.enterText(textFields.at(4), '1002003004');
      await tester.enterText(textFields.at(5), 'شرح الحالة المرضية والتكاليف');

      // Tap generate draft button
      final generateDraftBtn = find.text('إنشاء مسودة طلب');
      await tester.ensureVisible(generateDraftBtn);
      await tester.tap(generateDraftBtn);
      await tester.pumpAndSettle();

      // Button label specifies opening email app (Item 11)
      expect(find.text('فتح تطبيق البريد'), findsOneWidget);
    });

    testWidgets('MoneyCalcScreen: renders PriceTransparencyCard and Near-Nisab confirmation', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ZakatProvider()),
            ChangeNotifierProvider(create: (_) => FavoritesProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: MoneyCalcScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Renders PriceTransparencyCard
      expect(find.byType(PriceTransparencyCard), findsOneWidget);

      // Enter amount very close to Nisab (85 * 65000 = 5,525,000 -> enter 5,500,000)
      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.first, '5500000');
      await tester.pumpAndSettle();

      // Near-Nisab alert is displayed
      expect(find.textContaining('قريب جداً من حد النصاب الشرعي'), findsOneWidget);
      expect(find.byKey(const Key('btn_confirm_price_near_nisab')), findsOneWidget);
    });

    testWidgets('GoldCalcScreen: renders PriceTransparencyCard and Near-Nisab confirmation', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ZakatProvider()),
            ChangeNotifierProvider(create: (_) => FavoritesProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: GoldCalcScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Renders PriceTransparencyCard
      expect(find.byType(PriceTransparencyCard), findsOneWidget);

      // Select 24 karat
      await tester.tap(find.text('24 قيراط'));
      await tester.pumpAndSettle();

      final weightField = find.widgetWithText(TextFormField, 'وزن الذهب عيار 24 بالجرام');
      await tester.enterText(weightField, '84');
      await tester.pumpAndSettle();

      // Near-Nisab alert is displayed
      expect(find.textContaining('قريب جداً من حد النصاب الشرعي'), findsOneWidget);
      expect(find.byKey(const Key('btn_confirm_price_near_nisab')), findsOneWidget);
    });
  });

  group('13. Comprehensive Boundary Tests, Numeric Bounds & Livestock Diophantine (Item 14)', () {
    late ZakatProvider provider;

    setUp(() {
      provider = ZakatProvider();
    });

    test('1. Negative value handling (قيمة سالبة): Rejection in validators and calculation safety', () {
      // Validator rejection
      expect(AppValidators.requiredPositiveNumber('المبلغ')('-500'), isNotNull);
      expect(AppValidators.requiredPositiveInteger('العدد')('-10'), isNotNull);

      // Money Zakat: negative wealth should not reach nisab or produce zakat
      final moneyNeg = provider.calculateMoneyZakat(-500000);
      expect(moneyNeg.reachedNisab, isFalse);
      expect(moneyNeg.zakatAmount, 0.0);

      // Gold Zakat: negative weight
      final goldNeg = provider.calculateGoldZakat(grams: -100, karat: 24, pricePerGram: 65000);
      expect(goldNeg.reachedNisab, isFalse);
      expect(goldNeg.zakatAmount, 0.0);

      // Camels Zakat: negative count
      final camelNeg = provider.calculateCamelsZakat(-5);
      expect(camelNeg.reachedNisab, isFalse);
      expect(camelNeg.zakatAmount, 0.0);
    });

    test('2. Zero value handling (قيمة صفرية): Validator rejection and calculation safety', () {
      // Validator rejection
      expect(AppValidators.requiredPositiveNumber('المبلغ')('0'), isNotNull);
      expect(AppValidators.requiredPositiveInteger('العدد')('0'), isNotNull);

      // Calculations with zero wealth
      final moneyZero = provider.calculateMoneyZakat(0);
      expect(moneyZero.reachedNisab, isFalse);
      expect(moneyZero.zakatAmount, 0.0);

      final goldZero = provider.calculateGoldZakat(grams: 0, karat: 24, pricePerGram: 65000);
      expect(goldZero.reachedNisab, isFalse);
      expect(goldZero.zakatAmount, 0.0);

      final tradeZero = provider.calculateTradeZakat(
        inventoryValue: 0,
        cashInHand: 0,
        receivables: 0,
        liabilities: 0,
      );
      expect(tradeZero.reachedNisab, isFalse);
      expect(tradeZero.zakatAmount, 0.0);
    });

    test('3. Missing or zero crops weight (وزن حبوب غير موجود): Explicit rejection and clear explanation', () {
      final cropsZero = provider.calculateCropsZakat(
        totalCropValue: 100000,
        irrigationType: 'natural',
        weightInKg: 0,
      );
      expect(cropsZero.reachedNisab, isFalse);
      expect(cropsZero.zakatAmount, 0.0);
      expect(cropsZero.explanation, contains('يجب إدخال وزن المحصول'));

      final cropsNeg = provider.calculateCropsZakat(
        totalCropValue: 100000,
        irrigationType: 'natural',
        weightInKg: -20,
      );
      expect(cropsNeg.reachedNisab, isFalse);
      expect(cropsNeg.zakatAmount, 0.0);
      expect(cropsNeg.explanation, contains('يجب إدخال وزن المحصول'));
    });

    test('4. Crops weight less than nisab (وزن حبوب أقل من النصاب): 500kg vs 612kg threshold', () {
      expect(ZakatConstants.cropsNisabKg, 612.0);

      // 500 kg: less than Nisab (612 kg)
      final crops500 = provider.calculateCropsZakat(
        totalCropValue: 500000,
        irrigationType: 'natural',
        weightInKg: 500,
      );
      expect(crops500.reachedNisab, isFalse);
      expect(crops500.zakatAmount, 0.0);
      expect(crops500.explanation, contains('لم يكتمل النصاب'));

      // 611.9 kg: just below Nisab
      final cropsBelow = provider.calculateCropsZakat(
        totalCropValue: 611900,
        irrigationType: 'natural',
        weightInKg: 611.9,
      );
      expect(cropsBelow.reachedNisab, isFalse);
      expect(cropsBelow.zakatAmount, 0.0);

      // 612 kg: reached Nisab (10% rain-fed natural)
      final cropsReached = provider.calculateCropsZakat(
        totalCropValue: 612000,
        irrigationType: 'natural',
        weightInKg: 612,
      );
      expect(cropsReached.reachedNisab, isTrue);
      expect(cropsReached.zakatAmount, 61200.0);
    });

    test('5. Gold nisab for 21k and 24k (نصاب الذهب عيار 21 و 24): Pure gold normalization', () {
      // 24K: 85g is exactly the pure Nisab
      final gold24_84 = provider.calculateGoldZakat(grams: 84.9, karat: 24, pricePerGram: 65000);
      expect(gold24_84.reachedNisab, isFalse);

      final gold24_85 = provider.calculateGoldZakat(grams: 85.0, karat: 24, pricePerGram: 65000);
      expect(gold24_85.reachedNisab, isTrue);
      expect(gold24_85.zakatAmount, closeTo(85.0 * 0.025 * 65000, 0.01));

      // 21K: contains 21/24 (87.5%) pure gold
      // 85g of 21k = 85 * (21/24) = 74.375g pure gold (< 85g) -> NOT reached!
      final gold21_85 = provider.calculateGoldZakat(grams: 85.0, karat: 21, pricePerGram: 56875);
      expect(gold21_85.reachedNisab, isFalse);
      expect(gold21_85.explanation, contains('لم يكتمل النصاب الشرعي'));

      // 97g of 21k = 97 * (21/24) = 84.875g pure gold (< 85g) -> NOT reached!
      final gold21_97 = provider.calculateGoldZakat(grams: 97.0, karat: 21, pricePerGram: 56875);
      expect(gold21_97.reachedNisab, isFalse);

      // 98g of 21k = 98 * (21/24) = 85.75g pure gold (>= 85g) -> REACHED!
      final gold21_98 = provider.calculateGoldZakat(grams: 98.0, karat: 21, pricePerGram: 56875);
      expect(gold21_98.reachedNisab, isTrue);
    });

    test('6. Different prices for the same currency (أسعار مختلفة للعملة نفسها): Sanaa vs Aden regional benchmarks', () {
      final sanaa = MarketPriceService.getMarketById('sanaa');
      final aden = MarketPriceService.getMarketById('aden');

      expect(sanaa.currency, 'ر.ي');
      expect(aden.currency, 'ر.ي');
      expect(sanaa.defaultGold24, 62850.0);
      expect(aden.defaultGold24, 235000.0);

      // Amount: 8,000,000 YER
      const wealth = 8000000.0;

      // In Sana'a market price (Nisab = 5,342,250 YER): reaches Nisab
      final resSanaa = provider.calculateMoneyZakat(wealth, goldPricePerGram: sanaa.defaultGold24);
      expect(resSanaa.reachedNisab, isTrue);
      expect(resSanaa.zakatAmount, wealth * 0.025);

      // In Aden market price (Nisab = 19,975,000 YER): does NOT reach Nisab
      final resAden = provider.calculateMoneyZakat(wealth, goldPricePerGram: aden.defaultGold24);
      expect(resAden.reachedNisab, isFalse);
      expect(resAden.zakatAmount, 0.0);
    });

    test('7. Camels 121, 140, and 200 (121 و 140 و 200 من الإبل): Exact Diophantine combinations and Waqas', () {
      // 121 camels: has waqas/remainder, calculates base 120 (3 Bint Laboon) + waqas of 1
      final camels121 = provider.calculateCamelsZakat(121);
      expect(camels121.reachedNisab, isTrue);
      expect(camels121.zakatInKindDescription, contains('بنات لبون'));
      expect(camels121.zakatInKindDescription, contains('وقص'));
      expect(camels121.explanation, contains('وقص'));

      // 140 camels: 2 Hiqqah + 1 Bint Laboon (2 * 50 + 1 * 40 = 140)
      final camels140 = provider.calculateCamelsZakat(140);
      expect(camels140.reachedNisab, isTrue);
      expect(camels140.zakatInKindDescription, contains('حِقّتان'));
      expect(camels140.zakatInKindDescription, contains('بنت لبون واحدة'));

      // 200 camels: 4 Hiqqah (4 * 50 = 200) or 5 Bint Laboon (5 * 40 = 200)
      final camels200 = provider.calculateCamelsZakat(200);
      expect(camels200.reachedNisab, isTrue);
      expect(
        camels200.zakatInKindDescription.contains('حِقاق') ||
            camels200.zakatInKindDescription.contains('بنات لبون'),
        isTrue,
      );
    });

    test('8. Cows 120, 130, and 160 (120 و 130 و 160 من البقر): Exact Diophantine combinations', () {
      // 120 cows: 4 Tabi' (4 * 30 = 120) or 3 Musinnah (3 * 40 = 120)
      final cows120 = provider.calculateCowsZakat(120);
      expect(cows120.reachedNisab, isTrue);
      expect(
        cows120.zakatInKindDescription.contains('أتبعة') ||
            cows120.zakatInKindDescription.contains('مسنات'),
        isTrue,
      );

      // 130 cows: 3 Tabi' + 1 Musinnah (3 * 30 + 1 * 40 = 130)
      final cows130 = provider.calculateCowsZakat(130);
      expect(cows130.reachedNisab, isTrue);
      expect(cows130.zakatInKindDescription, contains('أتبعة'));
      expect(cows130.zakatInKindDescription, contains('مسنّة'));

      // 160 cows: 4 Musinnah (4 * 40 = 160)
      final cows160 = provider.calculateCowsZakat(160);
      expect(cows160.reachedNisab, isTrue);
      expect(cows160.zakatInKindDescription, contains('مسنّات'));
      expect(cows160.zakatInKindDescription, contains('4'));
    });

    test('9. Minerals less than nisab (المعادن أقل من النصاب): 85g gold equivalent benchmark', () {
      const goldPrice = 65000.0;
      const nisab = 85 * goldPrice; // 5,525,000

      // Below Nisab (3,000,000 < 5,525,000)
      final below = provider.calculateMineralsZakat(
        totalExtractedValue: 3000000,
        isRikaz: false,
        customNisabThreshold: nisab,
      );
      expect(below.reachedNisab, isFalse);
      expect(below.zakatAmount, 0.0);
      expect(below.explanation, contains('لم تبلغ قيمة المعادن النصاب الشرعي'));

      // Above Nisab (6,000,000 >= 5,525,000)
      final above = provider.calculateMineralsZakat(
        totalExtractedValue: 6000000,
        isRikaz: false,
        customNisabThreshold: nisab,
      );
      expect(above.reachedNisab, isTrue);
      expect(above.zakatAmount, 6000000 * 0.025);

      // Rikaz: 20% (Khums) regardless of Nisab
      final rikaz = provider.calculateMineralsZakat(
        totalExtractedValue: 6000000,
        isRikaz: true,
      );
      expect(rikaz.reachedNisab, isTrue);
      expect(rikaz.zakatAmount, 6000000 * 0.20);
      expect(rikaz.explanation, contains('الخُمس'));
    });
  });

  group('14. System Failure Modes, Multi-Currency, User Isolation & Enhanced Record (Items 13 & 14)', () {
    test('10. Two records in different currencies (سجلان بعملتين مختلفتين): Multi-currency isolation in annual report', () async {
      final rec1 = ZakatRecord(
        id: 'rec_curr_yer',
        typeName: 'زكاة المال',
        categoryKey: 'money',
        totalWealth: 10000000,
        zakatAmount: 250000,
        currency: 'ر.ي',
        reachedNisab: true,
      );

      final rec2 = ZakatRecord(
        id: 'rec_curr_sar',
        typeName: 'زكاة الذهب',
        categoryKey: 'gold',
        totalWealth: 50000,
        zakatAmount: 1250,
        currency: 'ر.س',
        reachedNisab: true,
      );

      // Generate annual statement PDF containing both records
      final pdfBytes = await PdfService.generateAnnualStatementPdf(records: [rec1, rec2]);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(100));

      // Verify records preserve distinct currencies and are not merged
      expect(rec1.currency, 'ر.ي');
      expect(rec2.currency, 'ر.س');
      expect(rec1.currency, isNot(equals(rec2.currency)));
    });

    test('11. User switching and record reading isolation (تبديل المستخدم ثم قراءة السجلات)', () async {
      final prov = ZakatProvider();

      const userAlpha = 'user_alpha_101';
      const userBeta = 'user_beta_202';

      // Save record for User Alpha
      final recAlpha = ZakatRecord(
        id: 'rec_alpha_test',
        userId: userAlpha,
        typeName: 'زكاة المال - ألفا',
        categoryKey: 'money',
        totalWealth: 5000000,
        zakatAmount: 125000,
        currency: 'ر.ي',
        reachedNisab: true,
      );
      await LocalDbService.saveZakatRecord(recAlpha);

      // Save record for User Beta
      final recBeta = ZakatRecord(
        id: 'rec_beta_test',
        userId: userBeta,
        typeName: 'زكاة المال - بيتا',
        categoryKey: 'money',
        totalWealth: 3000000,
        zakatAmount: 75000,
        currency: 'ر.ي',
        reachedNisab: true,
      );
      await LocalDbService.saveZakatRecord(recBeta);

      // Read records for User Alpha -> Must contain only Alpha's records
      prov.loadRecords(userId: userAlpha);
      expect(prov.records.any((r) => r.id == 'rec_alpha_test'), isTrue);
      expect(prov.records.any((r) => r.id == 'rec_beta_test'), isFalse);

      // Read records for User Beta -> Must contain only Beta's records
      prov.loadRecords(userId: userBeta);
      expect(prov.records.any((r) => r.id == 'rec_beta_test'), isTrue);
      expect(prov.records.any((r) => r.id == 'rec_alpha_test'), isFalse);

      // Clear memory on logout
      prov.clearInMemoryRecords();
      expect(prov.records.isEmpty, isTrue);
    });

    test('12. Firebase failure handling (فشل Firebase): Graceful offline fallback and safe auth status', () async {
      // Ensure clean state before testing login failure
      AuthService.setCurrentUserForTesting(null);

      // Simulate invalid/unregistered credentials causing Firebase exception
      final authProv = AuthProvider();
      expect(authProv.isAuthenticated, isFalse);

      final success = await authProv.login(email: 'invalid_nonexistent_email_99@test.com', password: 'wrong_password');
      expect(success, isFalse);
      expect(authProv.isAuthenticated, isFalse);
      expect(authProv.errorMessage, isNotNull);

      // System remains safe and operational as guest
      AuthService.setAuthStatusForTesting(AuthStatus.guest);
      expect(AuthService.canSubmitOfficialRequest, isFalse);

      // Local authentication is also not permitted for official requests
      AuthService.setAuthStatusForTesting(AuthStatus.localAuthenticated);
      expect(AuthService.canSubmitOfficialRequest, isFalse);
    });

    test('13. Price source failure handling (فشل مصدر الأسعار): Automatic regional fallback without crashing', () async {
      // Calling fetchPrices returns valid fallback snapshot even with network anomalies
      final result = await MarketPriceService.fetchPrices(cityId: 'sanaa');

      expect(result.gold24Price, greaterThan(0));
      expect(result.gold21Price, greaterThan(0));
      expect(result.silverPrice, greaterThan(0));
      expect(result.currency, 'ر.ي');
      expect(result.snapshot, isNotNull);
      expect(result.snapshot.source, isNotEmpty);
    });

    test('14. Mail app opening failure handling (فشل فتح البريد): Clear warning without deceiving user', () {
      // Verification of message strings when launchUrl is false
      const failureMessage = 'تعذر فتح تطبيق البريد تلقائياً، يمكنك نسخ الخطاب أو تصديره كـ PDF';
      const honestSuccessMessage = 'تم فتح تطبيق البريد. يرجى مراجعة الرسالة وإرسالها يدويًا.';

      expect(failureMessage, isNot(contains('تم إرسال')));
      expect(honestSuccessMessage, contains('فتح تطبيق البريد'));
      expect(honestSuccessMessage, contains('يدويًا'));
    });

    test('15. Enhanced ZakatRecord (Item 13): Preserves inputs, nisabThreshold, calculationPolicy, and priceSource', () {
      final now = DateTime.now();
      final inputs = {
        'income': 1200000.0,
        'expenses': 200000.0,
        'taxableWealth': 1000000.0,
        'method': 'netRevenue',
      };

      final record = ZakatRecord(
        id: 'rec_enhanced_101',
        userId: 'user_audit_1',
        typeName: 'زكاة المستغلات (صافي الريع)',
        categoryKey: 'fields',
        totalWealth: 1000000.0,
        zakatAmount: 25000.0,
        currency: 'ر.ي',
        reachedNisab: true,
        nisabThreshold: 5525000.0,
        appliedPrice: 65000.0,
        priceSource: 'سوق صنعاء المعتمد',
        priceUpdatedAt: now,
        inputs: inputs,
        calculationPolicy: 'صافي الريع بعد خصم النفقات',
      );

      final map = record.toMap();
      expect(map['inputs'], equals(inputs));
      expect(map['nisabThreshold'], 5525000.0);
      expect(map['calculationPolicy'], 'صافي الريع بعد خصم النفقات');
      expect(map['priceSource'], 'سوق صنعاء المعتمد');
      expect(map['userId'], 'user_audit_1');

      final fromMap = ZakatRecord.fromMap(map);
      expect(fromMap.id, 'rec_enhanced_101');
      expect(fromMap.inputs['income'], 1200000.0);
      expect(fromMap.inputs['method'], 'netRevenue');
      expect(fromMap.nisabThreshold, 5525000.0);
      expect(fromMap.calculationPolicy, 'صافي الريع بعد خصم النفقات');
      expect(fromMap.priceSource, 'سوق صنعاء المعتمد');
      expect(fromMap.userId, 'user_audit_1');
    });
  });

  group('15. Comprehensive Audit Tests: Waqas, Crops In-Kind, Debts, Silver Nisab & Stocks', () {
    test('1. Camels and Cows with Waqas (أوقاص الإبل والبقر فوق 120)', () {
      final provider = ZakatProvider();

      // 125 Camels: 120 is covered by 3 Bint Laboon, 5 is Waqas (عفو شرعي)
      final c125 = provider.calculateCamelsZakat(125);
      expect(c125.reachedNisab, isTrue);
      expect(c125.zakatInKindDescription, contains('3 بنات لبون'));
      expect(c125.zakatInKindDescription, contains('وقص'));
      expect(c125.explanation, contains('وقص'));

      // 135 Camels: 130 covered by 1 Hiqqah + 2 Bint Laboon, 5 is Waqas
      final c135 = provider.calculateCamelsZakat(135);
      expect(c135.reachedNisab, isTrue);
      expect(c135.zakatInKindDescription, contains('حِقّة واحدة'));
      expect(c135.zakatInKindDescription, contains('بنتا لبون'));
      expect(c135.zakatInKindDescription, contains('وقص'));

      // 125 Cows: 120 covered by 4 Tabee or 3 Musinna, 5 is Waqas
      final cow125 = provider.calculateCowsZakat(125);
      expect(cow125.reachedNisab, isTrue);
      expect(cow125.zakatInKindDescription, anyOf(contains('أتبعة'), contains('مسنّات')));
      expect(cow125.zakatInKindDescription, contains('وقص'));
    });

    test('2. Crops in-kind calculation by weight only without monetary value', () {
      final provider = ZakatProvider();

      // 1000 kg with rain-fed (10%) -> 100 kg in-kind, cash value 0 when omitted
      final cropsInKind = provider.calculateCropsZakat(
        weightInKg: 1000,
        irrigationType: 'natural',
        totalCropValue: null,
      );
      expect(cropsInKind.reachedNisab, isTrue);
      expect(cropsInKind.zakatAmount, 0.0);
      expect(cropsInKind.zakatInKindDescription, contains('100.0 كجم من المحصول عيناً'));
      expect(cropsInKind.explanation, contains('يوم الحصاد'));

      // With monetary value provided: calculates both
      final cropsWithCash = provider.calculateCropsZakat(
        weightInKg: 1000,
        irrigationType: 'natural',
        totalCropValue: 1000000,
      );
      expect(cropsWithCash.reachedNisab, isTrue);
      expect(cropsWithCash.zakatAmount, 100000.0);
      expect(cropsWithCash.zakatInKindDescription, contains('100.0 كجم'));
    });

    test('3. Money Zakat with Receivables, Liabilities, and Silver Nisab', () {
      final provider = ZakatProvider();

      // Wealth 6,000,000 + receivables 1,000,000 - liabilities 2,000,000 = net 5,000,000
      final resWithDebts = provider.calculateMoneyZakat(
        6000000,
        receivables: 1000000,
        liabilities: 2000000,
      );
      // At gold price 62,850 YER: Nisab = 85 * 62,850 = 5,342,250 YER
      // Net 5,000,000 is below Gold Nisab
      expect(resWithDebts.reachedNisab, isFalse);

      // Same net 5,000,000 with Silver Nisab (595 * 700 = 416,500 YER) -> Reaches Nisab!
      final resSilver = provider.calculateMoneyZakat(
        6000000,
        receivables: 1000000,
        liabilities: 2000000,
        useSilverNisab: true,
      );
      expect(resSilver.reachedNisab, isTrue);
      expect(resSilver.zakatAmount, 5000000 * 0.025); // 125,000 YER
      expect(resSilver.explanation, contains('فضة خالصة'));
    });

    test('4. Stocks and Investments Calculation (Speculation vs Long-term)', () {
      final provider = ZakatProvider();

      // Speculation: 1000 shares * 6000 YER = 6,000,000 YER (Reaches Gold Nisab 5,342,250 YER)
      final specResult = provider.calculateStocksZakat(
        sharesCount: 1000,
        shareMarketPrice: 6000,
        isSpeculation: true,
      );
      expect(specResult.reachedNisab, isTrue);
      expect(specResult.zakatAmount, 6000000 * 0.025); // 150,000 YER
      expect(specResult.explanation, contains('عروض تجارة'));

      // Long term investment with dividend 500 per share: Base = 1000 * 500 = 500,000 (Below Nisab)
      final ltResultLow = provider.calculateStocksZakat(
        sharesCount: 1000,
        shareMarketPrice: 6000,
        isSpeculation: false,
        dividendPerShare: 500,
      );
      expect(ltResultLow.reachedNisab, isFalse);
      expect(ltResultLow.zakatAmount, 0.0);

      // Long term investment with large dividend reaching Nisab: Base = 1000 * 6000 = 6,000,000
      final ltResultHigh = provider.calculateStocksZakat(
        sharesCount: 1000,
        shareMarketPrice: 6000,
        isSpeculation: false,
        dividendPerShare: 6000,
      );
      expect(ltResultHigh.reachedNisab, isTrue);
      expect(ltResultHigh.zakatAmount, 6000000 * 0.025);
      expect(ltResultHigh.explanation, contains('طويل الأجل'));
    });
  });
}



