import 'package:flutter/material.dart';
import '../core/database/local_db_service.dart';
import '../core/database/preferences_service.dart';
import '../core/services/market_price_service.dart';
import '../core/services/auth_service.dart';
import '../models/zakat_record.dart';

// Re-export calculation result models for backward compatibility
export '../core/calculators/zakat_calculation_result.dart';

import '../core/calculators/zakat_calculation_result.dart';
import '../core/calculators/money_calculator.dart';
import '../core/calculators/gold_silver_calculator.dart';
import '../core/calculators/trade_calculator.dart';
import '../core/calculators/crops_minerals_calculator.dart';
import '../core/calculators/livestock_calculator.dart';
import '../core/calculators/exploited_assets_calculator.dart';
import '../core/calculators/fitr_calculator.dart';
import '../core/calculators/stocks_crypto_calculator.dart';

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

  ZakatProvider() {
    loadRecords();
  }

  void loadRecords({String? userId, bool filterByUser = true}) {
    _records = LocalDbService.getAllZakatRecords(userId: userId, filterByUser: filterByUser);
    notifyListeners();
  }

  void clearInMemoryRecords() {
    _records = [];
    notifyListeners();
  }

  /// Determines if an amount is within a proximity margin of the Nisab threshold (±10%)
  bool isCloseToNisab(double value, double nisab, {double marginRatio = 0.10}) {
    if (value <= 0 || nisab <= 0) return false;
    final lowerBound = nisab * (1.0 - marginRatio);
    final upperBound = nisab * (1.0 + marginRatio);
    return value >= lowerBound && value <= upperBound;
  }

  Future<void> updateGoldPrice(double price) async {
    _gold24Price = price;
    await PreferencesService.setGold24Price(price);
    notifyListeners();
  }

  Future<void> updateGold24Price(double price) async {
    await updateGoldPrice(price);
  }

  Future<void> updateGoldPricesByKarat({
    required double gold24,
    required double gold21,
    required double gold18,
  }) async {
    _gold24Price = gold24;
    _gold21Price = gold21;
    _gold18Price = gold18;
    await PreferencesService.setGold24Price(gold24);
    await PreferencesService.setGold21Price(gold21);
    await PreferencesService.setGold18Price(gold18);
    notifyListeners();
  }

  /// إعادة تحميل الأسعار من التخزين المحلي أو عند تحديث السحابة
  void reloadPricesFromPreferences() {
    _gold24Price = PreferencesService.gold24Price;
    _gold21Price = PreferencesService.gold21Price;
    _gold18Price = PreferencesService.gold18Price;
    _silverPrice = PreferencesService.silverPrice;
    _currency = PreferencesService.currency;
    _marketCity = PreferencesService.marketCity;
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
    double receivables = 0.0,
    double liabilities = 0.0,
    bool useSilverNisab = false,
    bool isSolarYear = false,
  }) {
    return MoneyCalculator.calculate(
      moneyAmount: moneyAmount,
      gold24Price: _gold24Price,
      silverPrice: _silverPrice,
      currency: _currency,
      goldPricePerGram: goldPricePerGram,
      receivables: receivables,
      liabilities: liabilities,
      useSilverNisab: useSilverNisab,
      isSolarYear: isSolarYear,
    );
  }

  // --- 2. Zakat on Gold (زكاة الذهب) ---
  ZakatCalculationResult calculateGoldZakat({
    required double grams,
    required int karat,
    double? pricePerGram,
    bool isPersonalJewelry = false,
    bool madhhabRequiresZakat = false,
  }) {
    return GoldSilverCalculator.calculateGold(
      grams: grams,
      karat: karat,
      gold24Price: _gold24Price,
      gold21Price: _gold21Price,
      gold18Price: _gold18Price,
      currency: _currency,
      pricePerGram: pricePerGram,
      isPersonalJewelry: isPersonalJewelry,
      madhhabRequiresZakat: madhhabRequiresZakat,
    );
  }

  // --- 3. Zakat on Silver (زكاة الفضة) ---
  ZakatCalculationResult calculateSilverZakat(double grams, {double? pricePerGram}) {
    return GoldSilverCalculator.calculateSilver(
      grams: grams,
      silverPrice: _silverPrice,
      currency: _currency,
      pricePerGram: pricePerGram,
    );
  }

  // --- 3b. Combined Gold and Silver by Fractions (ضم الذهب والفضة بالأجزاء - فقه الهادوية) ---
  ZakatCalculationResult calculateCombinedGoldSilverZakat({
    required double goldGrams,
    required int goldKarat,
    required double silverGrams,
    double? gold24Price,
    double? silverPrice,
  }) {
    return GoldSilverCalculator.calculateCombinedGoldSilver(
      goldGrams: goldGrams,
      goldKarat: goldKarat,
      silverGrams: silverGrams,
      gold24Price: gold24Price ?? _gold24Price,
      silverPrice: silverPrice ?? _silverPrice,
      currency: _currency,
    );
  }

  // --- 4. Zakat on Trade & Commerce (عروض التجارة) ---
  ZakatCalculationResult calculateTradeZakat({
    required double inventoryValue,
    required double cashInHand,
    required double receivables,
    required double liabilities,
    double? gold24Price,
    double? silverPrice,
    bool useSilverNisab = false,
    bool isSolarYear = false,
  }) {
    return TradeCalculator.calculate(
      inventoryValue: inventoryValue,
      cashInHand: cashInHand,
      receivables: receivables,
      liabilities: liabilities,
      gold24Price: gold24Price ?? _gold24Price,
      silverPrice: silverPrice ?? _silverPrice,
      useSilverNisab: useSilverNisab,
      currency: _currency,
      isSolarYear: isSolarYear,
    );
  }

  // --- 5. Zakat on Crops & Fruits (الزروع والثمار) ---
  ZakatCalculationResult calculateCropsZakat({
    double? totalCropValue,
    required String irrigationType,
    required double weightInKg,
  }) {
    return CropsMineralsCalculator.calculateCrops(
      totalCropValue: totalCropValue,
      irrigationType: irrigationType,
      weightInKg: weightInKg,
      currency: _currency,
    );
  }

  // --- 6. Zakat on Camels (الإبل) ---
  ZakatCalculationResult calculateCamelsZakat(
    int count, {
    double? sheepPrice,
    double? bintLaboonPrice,
    double? hiqqahPrice,
  }) {
    return LivestockCalculator.calculateCamels(
      count,
      sheepPrice: sheepPrice,
      bintLaboonPrice: bintLaboonPrice,
      hiqqahPrice: hiqqahPrice,
      currency: _currency,
    );
  }

  // --- 7. Zakat on Cows (البقر والجاموس) ---
  ZakatCalculationResult calculateCowsZakat(
    int count, {
    double? tabeePrice,
    double? musinnaPrice,
  }) {
    return LivestockCalculator.calculateCows(
      count,
      tabeePrice: tabeePrice,
      musinnaPrice: musinnaPrice,
      currency: _currency,
    );
  }

  // --- 8. Zakat on Sheep & Goats (الغنم والماعز) ---
  ZakatCalculationResult calculateSheepZakat(
    int count, {
    double? sheepPrice,
  }) {
    return LivestockCalculator.calculateSheep(
      count,
      sheepPrice: sheepPrice,
      currency: _currency,
    );
  }

  // --- 9. Zakat on Exploited Assets / Rentals (زكاة المستغلات كالعقارات المؤجرة) ---
  ZakatCalculationResult calculateExploitedAssetsZakat({
    required double grossIncome,
    required double expenses,
    ExploitedAssetsMethod method = ExploitedAssetsMethod.netRevenue,
    bool isSolarYear = false,
  }) {
    return ExploitedAssetsCalculator.calculate(
      grossIncome: grossIncome,
      expenses: expenses,
      gold24Price: _gold24Price,
      currency: _currency,
      method: method,
      isSolarYear: isSolarYear,
    );
  }

  // --- 10. Minerals & Buried Treasures (الركاز والمعادن) ---
  ZakatCalculationResult calculateMineralsZakat({
    required double totalExtractedValue,
    required bool isRikaz,
    double? customMineralRate,
    double? customNisabThreshold,
  }) {
    return CropsMineralsCalculator.calculateMinerals(
      totalExtractedValue: totalExtractedValue,
      isRikaz: isRikaz,
      gold24Price: _gold24Price,
      currency: _currency,
      customMineralRate: customMineralRate,
      customNisabThreshold: customNisabThreshold,
    );
  }

  // --- 11. Zakat al-Fitr (زكاة الفطر) ---
  ZakatCalculationResult calculateFitrZakat({
    required int familyMembers,
    double? stapleBagPrice,
    double bagWeightKg = 50.0,
    double? cashValuePerPerson,
    double saWeightKg = 2.5,
    bool isCashPayment = true,
    String stapleName = 'القمح',
  }) {
    return FitrCalculator.calculate(
      familyMembers: familyMembers,
      stapleBagPrice: stapleBagPrice,
      bagWeightKg: bagWeightKg,
      cashValuePerPerson: cashValuePerPerson,
      saWeightKg: saWeightKg,
      isCashPayment: isCashPayment,
      stapleName: stapleName,
      currency: _currency,
    );
  }

  // --- 12. Zakat on Stocks & Investments (الأسهم والاستثمارات) ---
  ZakatCalculationResult calculateStocksZakat({
    required double sharesCount,
    required double shareMarketPrice,
    required bool isSpeculation,
    double dividendPerShare = 0.0,
    bool isSolarYear = false,
  }) {
    return StocksCryptoCalculator.calculateStocks(
      sharesCount: sharesCount,
      shareMarketPrice: shareMarketPrice,
      isSpeculation: isSpeculation,
      gold24Price: _gold24Price,
      currency: _currency,
      dividendPerShare: dividendPerShare,
      isSolarYear: isSolarYear,
    );
  }

  // --- 13. Zakat on Cryptocurrency (العملات الرقمية والمشفرة) ---
  ZakatCalculationResult calculateCryptoZakat({
    required double cryptoAmount,
    required double cryptoMarketPriceInFiat,
    bool isSolarYear = false,
  }) {
    return StocksCryptoCalculator.calculateCrypto(
      cryptoAmount: cryptoAmount,
      cryptoMarketPriceInFiat: cryptoMarketPriceInFiat,
      gold24Price: _gold24Price,
      currency: _currency,
      isSolarYear: isSolarYear,
    );
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
