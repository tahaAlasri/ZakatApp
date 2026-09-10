import 'package:flutter/material.dart';
import '../core/database/local_db_service.dart';
import '../core/database/preferences_service.dart';
import '../core/constants/zakat_constants.dart';
import '../models/zakat_record.dart';

class ZakatCalculationResult {
  final bool reachedNisab;
  final double zakatAmount;
  final String zakatInKindDescription;
  final String explanation;

  ZakatCalculationResult({
    required this.reachedNisab,
    required this.zakatAmount,
    this.zakatInKindDescription = '',
    required this.explanation,
  });
}

class ZakatProvider extends ChangeNotifier {
  double _goldPrice = PreferencesService.goldPrice;
  double _silverPrice = PreferencesService.silverPrice;
  String _currency = PreferencesService.currency;
  List<ZakatRecord> _records = [];

  double get goldPrice => _goldPrice;
  double get silverPrice => _silverPrice;
  String get currency => _currency;
  List<ZakatRecord> get records => _records;

  ZakatProvider() {
    loadRecords();
  }

  void loadRecords() {
    _records = LocalDbService.getAllZakatRecords();
    notifyListeners();
  }

  Future<void> updateGoldPrice(double price) async {
    _goldPrice = price;
    await PreferencesService.setGoldPrice(price);
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

  // --- 1. Zakat on Money (زكاة المال) ---
  ZakatCalculationResult calculateMoneyZakat(double moneyAmount, {double? goldPricePerGram}) {
    final price = goldPricePerGram ?? _goldPrice;
    if (moneyAmount <= 0 || price <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'يرجى إدخال مبلغ وسعر صحيحين',
      );
    }

    final equivalentGoldGrams = moneyAmount / price;
    final reachedNisab = equivalentGoldGrams >= ZakatConstants.goldNisabGrams;

    if (!reachedNisab) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'لم يكتمل النصاب الشرعي (المعادِل لـ 85 جرام ذهب: ${(85 * price).toStringAsFixed(2)} $_currency)',
      );
    }

    final zakat = moneyAmount * ZakatConstants.standardZakatRate; // 2.5%
    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakat,
      explanation: 'اكتمل النصاب الشرعي. الواجب إخراجه ربع العشر (2.5%) = ${zakat.toStringAsFixed(2)} $_currency',
    );
  }

  // --- 2. Zakat on Gold (زكاة الذهب) ---
  ZakatCalculationResult calculateGoldZakat({
    required double grams,
    required int karat, // 24, 21, 18
    double? pricePerGram,
  }) {
    final price = pricePerGram ?? _goldPrice;
    if (grams <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'يرجى إدخال عدد جرامات صحيح',
      );
    }

    // Convert to 24k standard equivalent
    final double pureGrams = (grams * karat) / 24.0;
    final reachedNisab = pureGrams >= ZakatConstants.goldNisabGrams;

    if (!reachedNisab) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'لم يكتمل النصاب الشرعي (نصاب الذهب 85 جراماً من الذهب الخالص)',
      );
    }

    final zakatGrams = pureGrams * ZakatConstants.standardZakatRate;
    final zakatCashValue = zakatGrams * price;

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakatCashValue,
      zakatInKindDescription: '${zakatGrams.toStringAsFixed(2)} جرام ذهب خالص (أو قيمتها: ${zakatCashValue.toStringAsFixed(2)} $_currency)',
      explanation: 'اكتمل النصاب. المقدار الواجب إخراجه ربع العشر (2.5%).',
    );
  }

  // --- 3. Zakat on Silver (زكاة الفضة) ---
  ZakatCalculationResult calculateSilverZakat(double grams, {double? pricePerGram}) {
    final price = pricePerGram ?? _silverPrice;
    if (grams <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'يرجى إدخال عدد جرامات صحيح',
      );
    }

    final reachedNisab = grams >= ZakatConstants.silverNisabGrams;
    if (!reachedNisab) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'لم يكتمل النصاب الشرعي (نصاب الفضة 595 جراماً)',
      );
    }

    final zakatGrams = grams * ZakatConstants.standardZakatRate;
    final zakatCashValue = zakatGrams * price;

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakatCashValue,
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
    final nisabThreshold = ZakatConstants.goldNisabGrams * _goldPrice;

    if (netWorth <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'صافي عروض التجارة لا يبلغ النصاب أو مدين.',
      );
    }

    final reachedNisab = netWorth >= nisabThreshold;
    if (!reachedNisab) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'لم يكتمل النصاب الشرعي لعروض التجارة (المعادل لـ $nisabThreshold $_currency)',
      );
    }

    final zakat = netWorth * ZakatConstants.standardZakatRate;
    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakat,
      explanation: 'صافي الوعاء الزكوي الخاضع: ${netWorth.toStringAsFixed(2)} $_currency. الواجب إخراجه 2.5%.',
    );
  }

  // --- 5. Zakat on Crops & Fruits (الزروع والثمار) ---
  ZakatCalculationResult calculateCropsZakat({
    required double totalCropValue,
    required String irrigationType, // 'natural' or 'artificial' or 'mixed'
  }) {
    if (totalCropValue <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'يرجى إدخال قيمة صحيحة للزروع',
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

    final zakat = totalCropValue * rate;
    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakat,
      explanation: 'نوع السقي: $irrigationDesc. الواجب إخراجه: ${zakat.toStringAsFixed(2)} $_currency (أو ما يعادلها عيناً من المحصول).',
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
      final bintLaboon = count ~/ 40;
      final hiqqah = count ~/ 50;
      resultText = '$bintLaboon بنت لبون أو $hiqqah حِقّة (بحسب التقسيم الأنسب لكل 40 بنت لبون ولكل 50 حقة)';
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
      final tabee = count ~/ 30;
      final musinna = count ~/ 40;
      resultText = '$tabee تبيعاً أو $musinna مسنّة (لكل 30 تبيع، ولكل 40 مسنة)';
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
  }) {
    final netIncome = grossIncome - expenses;
    final nisab = ZakatConstants.goldNisabGrams * _goldPrice;

    if (netIncome <= 0 || netIncome < nisab) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'صافي ريع المستغلات لا يبلغ النصاب (المعادل لـ $nisab $_currency)',
      );
    }

    final zakat = netIncome * ZakatConstants.standardZakatRate; // 2.5%
    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakat,
      explanation: 'الواجب إخراجه ربع العشر (2.5%) من صافي الغلة: ${zakat.toStringAsFixed(2)} $_currency',
    );
  }

  // --- 10. Minerals & Buried Treasures (الركاز والمعادن) ---
  ZakatCalculationResult calculateMineralsZakat({
    required double totalExtractedValue,
    required bool isRikaz, // Rikaz is 20% (الخمس), Minerals are 2.5% or per Sharia state regulation
  }) {
    if (totalExtractedValue <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'يرجى إدخال قيمة صحيحة للركاز أو المعادن',
      );
    }

    final rate = isRikaz ? 0.20 : 0.025;
    final zakat = totalExtractedValue * rate;

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakat,
      explanation: isRikaz
          ? 'الركاز (دفين الجاهلية) يجب فيه الخُمس (20%) فور استخراجه دون اشتراط حول.'
          : 'المعادن المستخرجة يجب فيها ربع العشر (2.5%) عند استخراجها وبلوغها النصاب.',
    );
  }

  // Save calculation to History
  Future<void> saveRecord(ZakatRecord record) async {
    await LocalDbService.saveZakatRecord(record);
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
