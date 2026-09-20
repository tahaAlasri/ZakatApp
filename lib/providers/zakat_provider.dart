import 'package:flutter/material.dart';
import '../core/database/local_db_service.dart';
import '../core/database/preferences_service.dart';
import '../core/constants/zakat_constants.dart';
import '../core/services/market_price_service.dart';
import '../core/services/auth_service.dart';
import '../models/zakat_record.dart';

class ZakatCalculationResult {
  final bool reachedNisab;
  final double zakatAmount;
  final String zakatInKindDescription;
  final String explanation;
  final double? nisabThreshold;
  final double? appliedPrice;
  final int? goldKarat;

  bool get reachedThreshold => reachedNisab;
  bool get isZakatRequired => reachedNisab;
  double get zakatDue => zakatAmount;

  ZakatCalculationResult({
    required this.reachedNisab,
    required this.zakatAmount,
    this.zakatInKindDescription = '',
    required this.explanation,
    this.nisabThreshold,
    this.appliedPrice,
    this.goldKarat,
  });
}

/// الطرق الفقهية والنظامية المعتمدة لحساب زكاة المستغلات (الأصول المؤجرة)
enum ExploitedAssetsMethod {
  netRevenue(
    'صافي الريع',
    'حساب ربع العشر (2.5%) من صافي الإيرادات بعد خصم مصاريف التشغيل والصيانة والضرائب',
  ),
  grossRevenue(
    'إجمالي الريع',
    'حساب ربع العشر (2.5%) من إجمالي الإيرادات دون خصم المصروفات التشغيلية',
  ),
  accumulatedCash(
    'وعاء نقدي متراكم بعد بلوغ النصاب',
    'مذهب الجمهور: لا زكاة في عين الأصل، وتُضم الغلة للسيولة النقدية بحولان الحول وبلوغ النصاب بنسبة 2.5%',
  ),
  authorityPolicy(
    'سياسة الجهة المعتمدة',
    'احتساب الزكاة على الوعاء المعتمد نظامياً وفق لوائح وتعليمات الهيئة المعتمدة بنسبة 2.5%',
  );

  final String label;
  final String description;
  const ExploitedAssetsMethod(this.label, this.description);
}

class ZakatProvider extends ChangeNotifier {
  double _gold24Price = PreferencesService.gold24Price;
  double _gold21Price = PreferencesService.gold21Price;
  double _gold18Price = PreferencesService.gold18Price;
  double _silverPrice = PreferencesService.silverPrice;
  String _currency = PreferencesService.currency;
  String _marketCity = PreferencesService.marketCity;
  bool _isFetchingPrices = false;
  MarketPricesResult? _lastPricesResult;
  List<ZakatRecord> _records = [];

  // Gold prices by Karat (24k is the pure gold benchmark for Nisab)
  double get goldPrice => _gold24Price; // Default gold benchmark
  double get gold24Price => _gold24Price;
  double get gold21Price => _gold21Price;
  double get gold18Price => _gold18Price;
  double get silverPrice => _silverPrice;
  String get currency => _currency;
  String get marketCity => _marketCity;
  bool get isFetchingPrices => _isFetchingPrices;
  MarketPricesResult? get lastPricesResult => _lastPricesResult;
  List<ZakatRecord> get records => _records;

  PriceSnapshot get currentPriceSnapshot {
    if (_lastPricesResult != null) {
      return _lastPricesResult!.snapshot;
    }
    final market = MarketPriceService.getMarketById(_marketCity);
    return PriceSnapshot(
      gold24: _gold24Price,
      gold21: _gold21Price,
      gold18: _gold18Price,
      silver: _silverPrice,
      currency: _currency,
      source: 'الأسعار السائدة المعتمدة - ${market.name}',
      updatedAt: DateTime.now(),
      isFallback: true,
      isSilverEstimated: false,
      isExchangeRateFixed: market.usdRate != 1.0,
      silverNote: 'سعر الفضة معتمد وفق التسعيرة السائدة لـ ${market.name}.',
      exchangeRateNote: market.usdRate != 1.0
          ? 'تنبيه: سعر الصرف (${market.usdRate} ${market.currency} / USD) معتمد وفق التسعيرة الإقليمية.'
          : null,
    );
  }

  /// Check whether the entered wealth is close to the Nisab threshold (within thresholdRatio e.g. 12%)
  bool isCloseToNisab(double amount, double nisabThreshold, {double thresholdRatio = 0.12}) {
    if (nisabThreshold <= 0 || amount <= 0) return false;
    final diff = (amount - nisabThreshold).abs();
    return (diff / nisabThreshold) <= thresholdRatio;
  }

  ZakatProvider() {
    loadRecords();
  }

  void loadRecords({String? userId}) {
    final currentUserId = userId ?? AuthService.currentUser?.id;
    _records = LocalDbService.getAllZakatRecords(userId: currentUserId);
    notifyListeners();
  }

  /// Clean up in-memory records on logout without deleting user data from device
  void clearInMemoryRecords() {
    _records.clear();
    notifyListeners();
  }

  Future<void> updateGoldPrice(double price) async {
    await updateGold24Price(price);
  }

  Future<void> updateGold24Price(double price) async {
    _gold24Price = price;
    _gold21Price = price * (21.0 / 24.0);
    _gold18Price = price * (18.0 / 24.0);
    await PreferencesService.setGold24Price(_gold24Price);
    await PreferencesService.setGold21Price(_gold21Price);
    await PreferencesService.setGold18Price(_gold18Price);
    notifyListeners();
  }

  Future<void> updateGoldPrices({required double g24, double? g21, double? g18}) async {
    _gold24Price = g24;
    _gold21Price = g21 ?? (g24 * (21.0 / 24.0));
    _gold18Price = g18 ?? (g24 * (18.0 / 24.0));
    await PreferencesService.setGold24Price(_gold24Price);
    await PreferencesService.setGold21Price(_gold21Price);
    await PreferencesService.setGold18Price(_gold18Price);
    notifyListeners();
  }

  Future<void> updateSilverPrice(double price) async {
    _silverPrice = price;
    await PreferencesService.setSilverPrice(price);
    notifyListeners();
  }

  Future<void> updateCurrency(String cur) async {
    _currency = cur;
    await PreferencesService.setCurrency(cur);
    notifyListeners();
  }

  Future<MarketPricesResult> fetchAndApplyMarketPrices({String? cityId}) async {
    _isFetchingPrices = true;
    notifyListeners();

    final targetCity = cityId ?? _marketCity;
    _marketCity = targetCity;
    await PreferencesService.setMarketCity(targetCity);

    final res = await MarketPriceService.fetchPrices(cityId: targetCity);
    _gold24Price = res.gold24Price;
    _gold21Price = res.gold21Price;
    _gold18Price = res.gold18Price;
    _silverPrice = res.silverPrice;
    _currency = res.currency;
    _lastPricesResult = res;

    await PreferencesService.setGold24Price(_gold24Price);
    await PreferencesService.setGold21Price(_gold21Price);
    await PreferencesService.setGold18Price(_gold18Price);
    await PreferencesService.setSilverPrice(_silverPrice);
    await PreferencesService.setCurrency(_currency);

    _isFetchingPrices = false;
    notifyListeners();
    return res;
  }

  // --- 1. Zakat on Money (زكاة المال) ---
  ZakatCalculationResult calculateMoneyZakat(
    double moneyAmount, {
    double? goldPricePerGram,
    double receivables = 0.0, // ديون لك مرجوة السداد (تُضاف للوعاء)
    double liabilities = 0.0, // ديون عليك حالة عاجلة (تُخصم من الوعاء)
    bool useSilverNisab = false, // معيار نصاب الفضة (الأحظ للفقراء)
  }) {
    final goldPrice = goldPricePerGram ?? _gold24Price;
    final effectivePrice = useSilverNisab ? _silverPrice : goldPrice;
    final nisabThreshold = useSilverNisab
        ? (ZakatConstants.silverNisabGrams * _silverPrice)
        : (ZakatConstants.goldNisabGrams * goldPrice);

    final netWealth = (moneyAmount + receivables) - liabilities;

    if (netWealth <= 0 || effectivePrice <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisabThreshold,
        appliedPrice: effectivePrice,
        explanation: netWealth <= 0
            ? 'الوعاء الزكوي بعد تسوية الديون لا يبلغ النصاب أو مدين.'
            : 'يرجى إدخال مبالغ وأسعار صحيحة',
      );
    }

    final reachedNisab = netWealth >= nisabThreshold;
    final nisabDescription = useSilverNisab
        ? '595 جرام فضة خالصة: ${nisabThreshold.toStringAsFixed(2)} $_currency (الأحظ للفقراء)'
        : '85 جرام ذهب خالص عيار 24: ${nisabThreshold.toStringAsFixed(2)} $_currency';

    if (!reachedNisab) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisabThreshold,
        appliedPrice: effectivePrice,
        explanation: 'لم يكتمل النصاب الشرعي (المعادِل لـ $nisabDescription). صافي الوعاء: ${netWealth.toStringAsFixed(2)} $_currency.',
      );
    }

    final zakat = netWealth * ZakatConstants.standardZakatRate; // 2.5%
    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakat,
      nisabThreshold: nisabThreshold,
      appliedPrice: effectivePrice,
      explanation: 'اكتمل النصاب الشرعي ($nisabDescription). صافي الوعاء الخاضع بعد تسوية الديون: ${netWealth.toStringAsFixed(2)} $_currency. الواجب إخراجه ربع العشر (2.5%) = ${zakat.toStringAsFixed(2)} $_currency',
    );
  }

  // --- 2. Zakat on Gold (زكاة الذهب) ---
  ZakatCalculationResult calculateGoldZakat({
    required double grams,
    required int karat, // 24, 21, 18
    double? pricePerGram,
    bool isPersonalJewelry = false,
  }) {
    double price = pricePerGram ?? switch (karat) {
      24 => _gold24Price,
      21 => _gold21Price,
      18 => _gold18Price,
      _ => throw ArgumentError('عيار الذهب غير مدعوم: $karat'),
    };

    if (grams <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        appliedPrice: price,
        goldKarat: karat,
        explanation: 'يرجى إدخال عدد جرامات صحيح',
      );
    }

    if (isPersonalJewelry) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        appliedPrice: price,
        goldKarat: karat,
        explanation: 'وفقاً لمذهب جمهور الفقهاء (المالكية والشافعية والحنابلة)، فإن الحلي المباح المعد للاستعمال والزينة الشخصية للمرأة لا زكاة فيه، وتستحب فيه الصدقة تطوعاً.',
      );
    }

    // Convert to 24k standard equivalent (85 grams of pure gold)
    final double pureGrams = (grams * karat) / 24.0;
    final reachedNisab = pureGrams >= ZakatConstants.goldNisabGrams;
    final nisabCashThreshold = ZakatConstants.goldNisabGrams * _gold24Price;

    if (!reachedNisab) {
      final equivalentKaratGrams = (ZakatConstants.goldNisabGrams * 24.0) / karat;
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisabCashThreshold,
        appliedPrice: price,
        goldKarat: karat,
        explanation: 'لم يكتمل النصاب الشرعي (نصاب الذهب 85 جراماً خالصاً عيار 24، أي ما يعادل ${equivalentKaratGrams.toStringAsFixed(1)} جرام عيار $karat)',
      );
    }

    final zakatPureGrams = pureGrams * ZakatConstants.standardZakatRate;
    final zakatKaratGrams = grams * ZakatConstants.standardZakatRate;
    final zakatCashValue = double.parse((zakatKaratGrams * price).toStringAsFixed(2));

    final inKindText = karat == 24
        ? '${zakatPureGrams.toStringAsFixed(2)} جرام ذهب عيار 24 خالص'
        : '${zakatKaratGrams.toStringAsFixed(2)} جرام عيار $karat (أو ${zakatPureGrams.toStringAsFixed(2)} جرام عيار 24 خالص)';

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakatCashValue,
      nisabThreshold: nisabCashThreshold,
      appliedPrice: price,
      goldKarat: karat,
      zakatInKindDescription: '$inKindText (أو قيمتها: ${zakatCashValue.toStringAsFixed(2)} $_currency)',
      explanation: 'اكتمل النصاب. المقدار الواجب إخراجه ربع العشر (2.5%) عيناً أو ما يعادله نقداً بسعر جرام عيار $karat ($price $_currency).',
    );
  }

  // --- 3. Zakat on Silver (زكاة الفضة) ---
  ZakatCalculationResult calculateSilverZakat(double grams, {double? pricePerGram}) {
    final price = pricePerGram ?? _silverPrice;
    final nisabThreshold = ZakatConstants.silverNisabGrams * price;
    if (grams <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisabThreshold,
        appliedPrice: price,
        explanation: 'يرجى إدخال عدد جرامات صحيح',
      );
    }

    final reachedNisab = grams >= ZakatConstants.silverNisabGrams;
    if (!reachedNisab) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisabThreshold,
        appliedPrice: price,
        explanation: 'لم يكتمل النصاب الشرعي (نصاب الفضة 595 جراماً)',
      );
    }

    final zakatGrams = grams * ZakatConstants.standardZakatRate;
    final zakatCashValue = zakatGrams * price;

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakatCashValue,
      nisabThreshold: nisabThreshold,
      appliedPrice: price,
      zakatInKindDescription: '${zakatGrams.toStringAsFixed(2)} جرام فضة (أو قيمتها: ${zakatCashValue.toStringAsFixed(2)} $_currency)',
      explanation: 'اكتمل النصاب. المقدار الواجب إخراجه ربع العشر (2.5%).',
    );
  }

  // --- 4. Zakat on Trade & Commerce (عروض التجارة) ---
  ZakatCalculationResult calculateTradeZakat({
    required double inventoryValue,
    required double cashInHand,
    required double receivables, // ديون مرجوة السداد
    required double liabilities, // ديون على التجارة تُخصم
  }) {
    final netWorth = (inventoryValue + cashInHand + receivables) - liabilities;
    final nisabThreshold = ZakatConstants.goldNisabGrams * _gold24Price;

    if (netWorth <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisabThreshold,
        appliedPrice: _gold24Price,
        explanation: 'صافي عروض التجارة لا يبلغ النصاب أو مدين.',
      );
    }

    final reachedNisab = netWorth >= nisabThreshold;
    if (!reachedNisab) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisabThreshold,
        appliedPrice: _gold24Price,
        explanation: 'لم يكتمل النصاب الشرعي لعروض التجارة (المعادل لـ $nisabThreshold $_currency)',
      );
    }

    final zakat = netWorth * ZakatConstants.standardZakatRate;
    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakat,
      nisabThreshold: nisabThreshold,
      appliedPrice: _gold24Price,
      explanation: 'صافي الوعاء الزكوي الخاضع: ${netWorth.toStringAsFixed(2)} $_currency. الواجب إخراجه 2.5%.',
    );
  }

  // --- 5. Zakat on Crops & Fruits (الزروع والثمار) ---
  ZakatCalculationResult calculateCropsZakat({
    double? totalCropValue,
    required String irrigationType, // 'natural' or 'artificial' or 'mixed'
    required double weightInKg,
  }) {
    if (weightInKg <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'يجب إدخال وزن المحصول بالكيلوجرام (أكبر من الصفر)',
      );
    }

    // Check Nisab threshold (5 wasq = 300 sa' ≈ 612 kg)
    if (weightInKg < ZakatConstants.cropsNisabKg) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'لم يكتمل النصاب الشرعي للحبوب والثمار (نصابها 5 أوسق = 300 صاع نبوي ≈ ${ZakatConstants.cropsNisabKg.toStringAsFixed(0)} كجم، والوزن المدخل: ${weightInKg.toStringAsFixed(1)} كجم).',
      );
    }

    double rate = ZakatConstants.rainFedRate;
    String irrigationDesc = 'سقيا طبيعية بماء المطر (العشر 10%)';

    if (irrigationType == 'artificial') {
      rate = ZakatConstants.irrigatedRate;
      irrigationDesc = 'سقيا صناعية بآلات ومكائن (نصف العشر 5%)';
    } else if (irrigationType == 'mixed') {
      rate = ZakatConstants.mixedRate;
      irrigationDesc = 'سقيا مشتركة (ثلاثة أرباع العشر 7.5%)';
    }

    final inKindWeight = weightInKg * rate;
    final hasMonetaryValue = totalCropValue != null && totalCropValue > 0;
    final zakatCash = hasMonetaryValue ? (totalCropValue * rate) : 0.0;

    final String inKind = hasMonetaryValue
        ? '${inKindWeight.toStringAsFixed(1)} كجم من المحصول (أو قيمتها: ${zakatCash.toStringAsFixed(2)} $_currency)'
        : '${inKindWeight.toStringAsFixed(1)} كجم من المحصول عيناً';

    final String explanation = hasMonetaryValue
        ? 'نوع السقي: $irrigationDesc. الواجب إخراجه: ${zakatCash.toStringAsFixed(2)} $_currency (أو ${inKindWeight.toStringAsFixed(1)} كجم عيناً).'
        : 'نوع السقي: $irrigationDesc. الواجب إخراجه عيناً: ${inKindWeight.toStringAsFixed(1)} كجم من المحصول (وهو الأصل الشرعي لزكاة الزروع يوم الحصاد).';

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakatCash,
      zakatInKindDescription: inKind,
      explanation: explanation,
    );
  }

  // --- 6. Zakat on Camels (الإبل) ---
  ZakatCalculationResult calculateCamelsZakat(int count) {
    if (count < 5) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'لم يكتمل النصاب الشرعي للإبل (نصابها 5 من الإبل السائمة)',
      );
    }

    String resultText;
    if (count <= 9) {
      resultText = 'شاة واحدة (جذع من الضأن أو ثني من المعز)';
    } else if (count <= 14) {
      resultText = 'شاتان';
    } else if (count <= 19) {
      resultText = 'ثلاث شياه';
    } else if (count <= 24) {
      resultText = 'أربع شياه';
    } else if (count <= 35) {
      resultText = 'بنت مخاض (أنثى أتمت سنة)';
    } else if (count <= 45) {
      resultText = 'بنت لبون (أنثى أتمت سنتين)';
    } else if (count <= 60) {
      resultText = 'حِقّة (أنثى أتمت ثلاث سنين)';
    } else if (count <= 75) {
      resultText = 'جَذَعة (أنثى أتمت أربع سنين)';
    } else if (count <= 90) {
      resultText = 'بنتا لبون (اثنتان كل منهما أتمت سنتين)';
    } else if (count <= 120) {
      resultText = 'حِقّتان (اثنتان كل منهما أتمت ثلاث سنين)';
    } else {
      // Sharia combination for count > 120:
      // القاعدة الفقهية: في كل 40 بنت لبون وفي كل 50 حِقّة، والزائد بين العقود وقص (عفو شرعي لا زكاة فيه)
      final target = count - (count % 10);
      final waqas = count - target;
      final combinations = <({int hiqqah, int bintLaboon})>[];

      for (int hiqqah = 0; hiqqah <= target ~/ 50; hiqqah++) {
        final remaining = target - (hiqqah * 50);
        if (remaining % 40 == 0) {
          final bintLaboon = remaining ~/ 40;
          combinations.add((hiqqah: hiqqah, bintLaboon: bintLaboon));
        }
      }

      if (combinations.isEmpty) {
        return ZakatCalculationResult(
          reachedNisab: true,
          zakatAmount: 0,
          zakatInKindDescription: 'يحتاج إلى مراجعة فقهية',
          explanation: 'العدد ($count من الإبل) يحتاج إلى مراجعة فقهية خاصة لتحديد الفريضة في الوقص.',
        );
      }

      final formattedList = combinations.map((c) {
        final parts = <String>[];
        if (c.hiqqah > 0) {
          if (c.hiqqah == 1) {
            parts.add('حِقّة واحدة (عن 50)');
          } else if (c.hiqqah == 2) {
            parts.add('حِقّتان (عن 100)');
          } else {
            parts.add('${c.hiqqah} حِقاق (عن ${c.hiqqah * 50})');
          }
        }
        if (c.bintLaboon > 0) {
          if (c.bintLaboon == 1) {
            parts.add('بنت لبون واحدة (عن 40)');
          } else if (c.bintLaboon == 2) {
            parts.add('بنتا لبون (عن 80)');
          } else {
            parts.add('${c.bintLaboon} بنات لبون (عن ${c.bintLaboon * 40})');
          }
        }
        return parts.join(' مع ');
      }).toList();

      resultText = formattedList.join('، أو ');
      if (waqas > 0) {
        resultText += ' (والزائد $waqas من الإبل وقص عفو شرعي لا زكاة فيه)';
      }
    }

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: 0,
      zakatInKindDescription: resultText,
      explanation: 'اكتمل النصاب الشرعي للإبل. المقدار الواجب إخراجه عيناً: $resultText',
    );
  }

  // --- 7. Zakat on Cows (البقر والجاموس) ---
  ZakatCalculationResult calculateCowsZakat(int count) {
    if (count < 30) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'لم يكتمل النصاب الشرعي للبقر (نصابها 30 بقرة سائمة)',
      );
    }

    String resultText;
    if (count <= 39) {
      resultText = 'تبيع أو تبيعة (أتم سنة)';
    } else if (count <= 59) {
      resultText = 'مُسنّة (أتمت سنتين)';
    } else if (count <= 69) {
      resultText = 'تبيعان';
    } else if (count <= 79) {
      resultText = 'مسنّة وتبيع';
    } else if (count <= 89) {
      resultText = 'مسنّتان';
    } else if (count <= 99) {
      resultText = 'ثلاثة أتبعة';
    } else if (count <= 119) {
      resultText = 'مسنّة مع تبيعين';
    } else {
      // Sharia combinations for count >= 120:
      // القاعدة الفقهية: في كل 30 تبيع وفي كل 40 مسنة، والزائد بين العقود وقص (عفو شرعي لا زكاة فيه)
      final target = count - (count % 10);
      final waqas = count - target;
      final combinations = <({int tabee, int musinna})>[];

      for (int musinna = 0; musinna <= target ~/ 40; musinna++) {
        final remaining = target - (musinna * 40);
        if (remaining % 30 == 0) {
          final tabee = remaining ~/ 30;
          combinations.add((tabee: tabee, musinna: musinna));
        }
      }

      if (combinations.isEmpty) {
        return ZakatCalculationResult(
          reachedNisab: true,
          zakatAmount: 0,
          zakatInKindDescription: 'يحتاج إلى مراجعة فقهية',
          explanation: 'العدد ($count من البقر) يحتاج إلى مراجعة فقهية خاصة لتحديد الفرض في الوقص.',
        );
      }

      final formattedList = combinations.map((c) {
        final parts = <String>[];
        if (c.musinna > 0) {
          if (c.musinna == 1) {
            parts.add('مسنّة واحدة (عن 40)');
          } else if (c.musinna == 2) {
            parts.add('مسنّتان (عن 80)');
          } else {
            parts.add('${c.musinna} مسنّات (عن ${c.musinna * 40})');
          }
        }
        if (c.tabee > 0) {
          if (c.tabee == 1) {
            parts.add('تبيع واحد (عن 30)');
          } else if (c.tabee == 2) {
            parts.add('تبيعان (عن 60)');
          } else {
            parts.add('${c.tabee} أتبعة (عن ${c.tabee * 30})');
          }
        }
        return parts.join(' مع ');
      }).toList();

      resultText = formattedList.join('، أو ');
      if (waqas > 0) {
        resultText += ' (والزائد $waqas من البقر وقص عفو شرعي لا زكاة فيه)';
      }
    }

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: 0,
      zakatInKindDescription: resultText,
      explanation: 'اكتمل النصاب الشرعي للبقر. المقدار الواجب إخراجه عيناً: $resultText',
    );
  }

  // --- 8. Zakat on Sheep & Goats (الغنم والماعز) ---
  ZakatCalculationResult calculateSheepZakat(int count) {
    if (count < 40) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'لم يكتمل النصاب الشرعي للغنم (نصابها 40 شاة سائمة)',
      );
    }

    String resultText;
    if (count <= 120) {
      resultText = 'شاة واحدة (أتمت سنة أو ثني من المعز)';
    } else if (count <= 200) {
      resultText = 'شاتان';
    } else if (count <= 399) {
      resultText = 'ثلاث شياه';
    } else if (count <= 499) {
      resultText = 'أربع شياه';
    } else if (count <= 599) {
      resultText = 'خمس شياه';
    } else {
      final hundreds = count ~/ 100;
      resultText = '$hundreds شياه (لكل مئة شاة شاة واحدة)';
    }

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: 0,
      zakatInKindDescription: resultText,
      explanation: 'اكتمل النصاب الشرعي للغنم. المقدار الواجب إخراجه عيناً: $resultText',
    );
  }

  // --- 9. Zakat on Exploited Assets / Rentals (زكاة المستغلات كالعقارات المؤجرة) ---
  ZakatCalculationResult calculateExploitedAssetsZakat({
    required double grossIncome,
    required double expenses, // تشغيل وصيانة وضرائب
    ExploitedAssetsMethod method = ExploitedAssetsMethod.netRevenue,
  }) {
    final nisab = ZakatConstants.goldNisabGrams * _gold24Price;

    final double taxableBase = switch (method) {
      ExploitedAssetsMethod.netRevenue => grossIncome - expenses,
      ExploitedAssetsMethod.grossRevenue => grossIncome,
      ExploitedAssetsMethod.accumulatedCash => grossIncome - expenses,
      ExploitedAssetsMethod.authorityPolicy => grossIncome - expenses,
    };

    if (taxableBase <= 0 || taxableBase < nisab) {
      final String reason = switch (method) {
        ExploitedAssetsMethod.netRevenue =>
          'صافي ريع المستغلات لا يبلغ النصاب الشرعي (المعادل لـ ${nisab.toStringAsFixed(2)} $_currency)',
        ExploitedAssetsMethod.grossRevenue =>
          'إجمالي ريع المستغلات لا يبلغ النصاب الشرعي (المعادل لـ ${nisab.toStringAsFixed(2)} $_currency)',
        ExploitedAssetsMethod.accumulatedCash =>
          'الوعاء النقدي المتراكم لا يبلغ النصاب الشرعي (المعادل لـ ${nisab.toStringAsFixed(2)} $_currency) أو لم يحل عليه الحول',
        ExploitedAssetsMethod.authorityPolicy =>
          'الوعاء الخاضع وفق سياسة الجهة المعتمدة لا يبلغ النصاب (المعادل لـ ${nisab.toStringAsFixed(2)} $_currency)',
      };

      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisab,
        appliedPrice: _gold24Price,
        explanation: 'تم الحساب بناءً على طريقة: ${method.label}\n$reason',
      );
    }

    final zakat = taxableBase * ZakatConstants.standardZakatRate; // 2.5%
    final String detail = switch (method) {
      ExploitedAssetsMethod.netRevenue =>
        'الواجب إخراجه ربع العشر (2.5%) من صافي الغلة (${taxableBase.toStringAsFixed(2)} $_currency) بعد خصم المصروفات: ${zakat.toStringAsFixed(2)} $_currency',
      ExploitedAssetsMethod.grossRevenue =>
        'الواجب إخراجه ربع العشر (2.5%) من إجمالي الريع (${taxableBase.toStringAsFixed(2)} $_currency) دون خصم المصروفات: ${zakat.toStringAsFixed(2)} $_currency',
      ExploitedAssetsMethod.accumulatedCash =>
        'وفق مذهب الجمهور: يُضم الفائض المتراكم (${taxableBase.toStringAsFixed(2)} $_currency) للسيولة النقدية، والواجب 2.5% بعد تمام الحول وبلوغ النصاب: ${zakat.toStringAsFixed(2)} $_currency',
      ExploitedAssetsMethod.authorityPolicy =>
        'وفق سياسة الجهة المعتمدة: الواجب 2.5% من الوعاء النظامي المعتمد للمستغلات (${taxableBase.toStringAsFixed(2)} $_currency): ${zakat.toStringAsFixed(2)} $_currency',
    };

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakat,
      nisabThreshold: nisab,
      appliedPrice: _gold24Price,
      explanation: 'تم الحساب بناءً على طريقة: ${method.label}\n$detail',
    );
  }

  // --- 10. Minerals & Buried Treasures (الركاز والمعادن) ---
  ZakatCalculationResult calculateMineralsZakat({
    required double totalExtractedValue,
    required bool isRikaz, // Rikaz is 20% (الخمس), Minerals are 2.5% with Nisab requirement
    double? customMineralRate,
    double? customNisabThreshold,
  }) {
    if (totalExtractedValue <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'يرجى إدخال قيمة صحيحة للركاز أو المعادن',
      );
    }

    final nisab = customNisabThreshold ?? (ZakatConstants.goldNisabGrams * _gold24Price);

    // الركاز: 20% فور الاستخراج وفق السياسة المعتمدة دون اشتراط حول أو نصاب
    if (isRikaz) {
      final rate = customMineralRate ?? 0.20;
      final zakat = totalExtractedValue * rate;
      return ZakatCalculationResult(
        reachedNisab: true,
        zakatAmount: zakat,
        appliedPrice: _gold24Price,
        explanation: 'الركاز (دفين الجاهلية والكنوز القديمة) يجب فيه الخُمس (${(rate * 100).toStringAsFixed(0)}%) فور استخراجه وفق السياسة المعتمدة دون اشتراط حول أو نصاب.',
      );
    }

    // المعادن: يُشترط فيها النصاب الشرعي (85غ ذهب خالص عيار 24)
    if (totalExtractedValue < nisab) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisab,
        appliedPrice: _gold24Price,
        explanation: 'لم تبلغ قيمة المعادن النصاب الشرعي (المعادل لقيمة 85 جرام ذهب خالص عيار 24: ${nisab.toStringAsFixed(2)} $_currency).',
      );
    }

    // النسبة والنصاب وتوقيت الوجوب قابلة للتعديل والضبط بحسب السياسة المعتمدة شرعياً
    final rate = customMineralRate ?? ZakatConstants.standardZakatRate; // 2.5%
    final zakat = totalExtractedValue * rate;

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakat,
      nisabThreshold: nisab,
      appliedPrice: _gold24Price,
      explanation: 'بلغت المعادن المستخرجة النصاب الشرعي (المعادل لـ 85 جرام ذهب خالص عيار 24). الواجب إخراجه ربع العشر (${(rate * 100).toStringAsFixed(1)}%) فور استخراجها وفق السياسة المعتمدة شرعاً: ${zakat.toStringAsFixed(2)} $_currency.',
    );
  }

  // --- 11. Zakat al-Fitr (زكاة الفطر) ---
  ZakatCalculationResult calculateFitrZakat({
    required int familyMembers,
    double? wheatBagPrice,
    double bagWeightKg = ZakatConstants.defaultWheatBagWeightKg,
    double? cashValuePerPerson,
    double saWeightKg = ZakatConstants.fitrSaWeightKg,
    bool isCashPayment = true,
  }) {
    if (familyMembers <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'يرجى إدخال عدد صحيح لأفراد الأسرة (فرد واحد على الأقل).',
      );
    }

    final saCountInBag = saWeightKg > 0 ? (bagWeightKg / saWeightKg) : 20.0;

    // Per person cash value: either calculated from wheat bag price or provided directly
    final effectivePerPerson = cashValuePerPerson ??
        (wheatBagPrice != null && saCountInBag > 0
            ? (wheatBagPrice / saCountInBag)
            : ZakatConstants.defaultFitrCashYER);

    final totalCash = double.parse((familyMembers * effectivePerPerson).toStringAsFixed(2));
    final totalWeightKg = double.parse((familyMembers * saWeightKg).toStringAsFixed(2));
    final bagsEquivalent = bagWeightKg > 0 ? (totalWeightKg / bagWeightKg) : 0.0;

    final String bagsDesc = bagsEquivalent >= 1.0
        ? ' (ما يعادل ${bagsEquivalent.toStringAsFixed(1)} كيس زنة ${bagWeightKg.toStringAsFixed(0)} كجم)'
        : (bagsEquivalent > 0
            ? ' (ما يعادل ${(bagsEquivalent * 100).toStringAsFixed(0)}% من كيس زنة ${bagWeightKg.toStringAsFixed(0)} كجم)'
            : '');

    final inKindDesc = '$totalWeightKg كجم ($familyMembers صاع نبوي)$bagsDesc';

    String explanation;
    if (wheatBagPrice != null && wheatBagPrice > 0) {
      explanation = isCashPayment
          ? 'بناءً على سعر كيس القمح (زنة ${bagWeightKg.toStringAsFixed(0)} كجم بسعر ${wheatBagPrice.toStringAsFixed(0)} $_currency)، فإن الكيس يحتوي على ${saCountInBag.toStringAsFixed(0)} صاعاً نبوياً (بواقع $saWeightKg كجم للصاع).\n'
            'وعليه فإن نصيب الفرد الواحد هو: ${effectivePerPerson.toStringAsFixed(0)} $_currency.\n'
            'الواجب إخراجه نقداً عن $familyMembers أفراد هو: ${totalCash.toStringAsFixed(0)} $_currency (أو ما يعادل $inKindDesc من طعام أهل البلد كالقمح أو الأرز).'
          : 'الواجب إخراجه عيناً عن $familyMembers أفراد هو: $inKindDesc (بمعدل صاع نبوي ≈ $saWeightKg كجم لكل فرد من طعام أهل البلد كالقمح أو الأرز أو التمر).';
    } else {
      explanation = isCashPayment
          ? 'الواجب إخراجه نقداً عن $familyMembers أفراد هو: ${totalCash.toStringAsFixed(0)} $_currency (بواقع ${effectivePerPerson.toStringAsFixed(0)} $_currency للفرد الواحد، أو ما يعادل $inKindDesc من غالب قوت البلد كالأرز أو القمح).'
          : 'الواجب إخراجه عيناً عن $familyMembers أفراد هو: $inKindDesc (بمعدل صاع نبوي ≈ $saWeightKg كجم لكل فرد من طعام أهل البلد كالأرز أو القمح أو التمر).';
    }

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: totalCash,
      zakatInKindDescription: inKindDesc,
      explanation: explanation,
    );
  }

  // --- 12. Zakat on Stocks & Investments (الأسهم والاستثمارات) ---
  ZakatCalculationResult calculateStocksZakat({
    required double sharesCount,
    required double shareMarketPrice,
    required bool isSpeculation, // true = مضاربة وتجارة (سعر سوقي), false = استثمار طويل الأجل
    double dividendPerShare = 0.0, // أرباح موزعة أو وعاء زكوي للسهم الاستثماري
  }) {
    if (sharesCount <= 0 || shareMarketPrice <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'يرجى إدخال عدد أسهم وسعر صحيحين (أكبر من الصفر)',
      );
    }

    final nisabThreshold = ZakatConstants.goldNisabGrams * _gold24Price;
    final totalMarketValue = sharesCount * shareMarketPrice;

    if (isSpeculation) {
      // أسهم المضاربة: عروض تجارة، تُزكى قيمتها السوقية بالكامل
      if (totalMarketValue < nisabThreshold) {
        return ZakatCalculationResult(
          reachedNisab: false,
          zakatAmount: 0,
          nisabThreshold: nisabThreshold,
          appliedPrice: _gold24Price,
          explanation: 'القيمة السوقية لأسهم المضاربة (${totalMarketValue.toStringAsFixed(2)} $_currency) لم تبلغ النصاب الشرعي (${nisabThreshold.toStringAsFixed(2)} $_currency).',
        );
      }
      final zakat = totalMarketValue * ZakatConstants.standardZakatRate;
      return ZakatCalculationResult(
        reachedNisab: true,
        zakatAmount: zakat,
        nisabThreshold: nisabThreshold,
        appliedPrice: _gold24Price,
        explanation: 'أسهم مضاربة (عروض تجارة): الوعاء الزكوي هو القيمة السوقية الإجمالية (${totalMarketValue.toStringAsFixed(2)} $_currency). الواجب إخراجه 2.5% = ${zakat.toStringAsFixed(2)} $_currency.',
      );
    } else {
      // أسهم الاستثمار طويل الأجل: الزكاة على صافي الأرباح الموزعة أو الأصول المتداولة الزكوية
      final effectiveBase = dividendPerShare > 0 ? (sharesCount * dividendPerShare) : (totalMarketValue * 0.10);
      if (effectiveBase < nisabThreshold) {
        return ZakatCalculationResult(
          reachedNisab: false,
          zakatAmount: 0,
          nisabThreshold: nisabThreshold,
          appliedPrice: _gold24Price,
          explanation: 'الوعاء الخاضع لأسهم الاستثمار (${effectiveBase.toStringAsFixed(2)} $_currency) لم يبلغ النصاب الشرعي (${nisabThreshold.toStringAsFixed(2)} $_currency).',
        );
      }
      final zakat = effectiveBase * ZakatConstants.standardZakatRate;
      return ZakatCalculationResult(
        reachedNisab: true,
        zakatAmount: zakat,
        nisabThreshold: nisabThreshold,
        appliedPrice: _gold24Price,
        explanation: 'أسهم استثمار طويل الأجل: تُحسب الزكاة على العائد/الأصول الزكوية (${effectiveBase.toStringAsFixed(2)} $_currency) بنسبة 2.5% = ${zakat.toStringAsFixed(2)} $_currency.',
      );
    }
  }

  // Save calculation to History
  Future<void> saveRecord(ZakatRecord record) async {
    final snapshot = currentPriceSnapshot;
    final recordWithUser = (record.userId == null && AuthService.currentUser?.id != null)
        ? record.copyWith(userId: AuthService.currentUser?.id)
        : record;
    final recordToSave = (recordWithUser.priceSource == 'يدوي')
        ? recordWithUser.copyWith(
            priceSource: snapshot.source,
            priceUpdatedAt: snapshot.updatedAt,
          )
        : recordWithUser;
    await LocalDbService.saveZakatRecord(recordToSave);
    loadRecords();
  }

  // Delete calculation
  Future<void> deleteRecord(String id) async {
    await LocalDbService.deleteZakatRecord(id);
    loadRecords();
  }

  // Clear all
  Future<void> clearAll() async {
    await LocalDbService.clearAllZakatRecords();
    loadRecords();
  }
}
