import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RegionalMarketInfo {
  final String id;
  final String name;
  final String currency;
  final double defaultGold24;
  final double defaultGold21;
  final double defaultGold18;
  final double defaultSilver;
  final double usdRate; // Currency per 1 USD for conversion

  const RegionalMarketInfo({
    required this.id,
    required this.name,
    required this.currency,
    required this.defaultGold24,
    required this.defaultGold21,
    required this.defaultGold18,
    required this.defaultSilver,
    required this.usdRate,
  });
}

class PriceSnapshot {
  final double gold24;
  final double gold21;
  final double gold18;
  final double silver;
  final String currency;
  final String source;
  final DateTime updatedAt;
  final bool isFallback;
  final bool isSilverEstimated;
  final bool isExchangeRateFixed;
  final String? silverNote;
  final String? exchangeRateNote;

  const PriceSnapshot({
    required this.gold24,
    required this.gold21,
    required this.gold18,
    required this.silver,
    required this.currency,
    required this.source,
    required this.updatedAt,
    required this.isFallback,
    this.isSilverEstimated = false,
    this.isExchangeRateFixed = false,
    this.silverNote,
    this.exchangeRateNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'gold24': gold24,
      'gold21': gold21,
      'gold18': gold18,
      'silver': silver,
      'currency': currency,
      'source': source,
      'updatedAt': updatedAt.toIso8601String(),
      'isFallback': isFallback,
      'isSilverEstimated': isSilverEstimated,
      'isExchangeRateFixed': isExchangeRateFixed,
      'silverNote': silverNote,
      'exchangeRateNote': exchangeRateNote,
    };
  }

  factory PriceSnapshot.fromMap(Map<dynamic, dynamic> map) {
    return PriceSnapshot(
      gold24: (map['gold24'] as num?)?.toDouble() ?? 0.0,
      gold21: (map['gold21'] as num?)?.toDouble() ?? 0.0,
      gold18: (map['gold18'] as num?)?.toDouble() ?? 0.0,
      silver: (map['silver'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency']?.toString() ?? 'ر.ي',
      source: map['source']?.toString() ?? 'افتراضي',
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isFallback: map['isFallback'] == true,
      isSilverEstimated: map['isSilverEstimated'] == true,
      isExchangeRateFixed: map['isExchangeRateFixed'] == true,
      silverNote: map['silverNote']?.toString(),
      exchangeRateNote: map['exchangeRateNote']?.toString(),
    );
  }
}

class MarketPricesResult {
  final String cityId;
  final String cityName;
  final String currency;
  final double gold24Price;
  final double gold21Price;
  final double gold18Price;
  final double silverPrice;
  final DateTime updatedAt;
  final bool isLiveApi;
  final String message;
  final PriceSnapshot snapshot;

  const MarketPricesResult({
    required this.cityId,
    required this.cityName,
    required this.currency,
    required this.gold24Price,
    required this.gold21Price,
    required this.gold18Price,
    required this.silverPrice,
    required this.updatedAt,
    required this.isLiveApi,
    required this.message,
    required this.snapshot,
  });
}

class MarketPriceService {
  static const List<RegionalMarketInfo> supportedMarkets = [
    RegionalMarketInfo(
      id: 'sanaa',
      name: 'صنعاء (الريال اليمني)',
      currency: 'ر.ي',
      defaultGold24: 62850.0,
      defaultGold21: 55000.0,
      defaultGold18: 47150.0,
      defaultSilver: 700.0,
      usdRate: 535.0,
    ),
    RegionalMarketInfo(
      id: 'aden',
      name: 'عدن (الريال اليمني - السعر الموازي)',
      currency: 'ر.ي',
      defaultGold24: 235000.0,
      defaultGold21: 205000.0,
      defaultGold18: 176000.0,
      defaultSilver: 2500.0,
      usdRate: 1950.0,
    ),
    RegionalMarketInfo(
      id: 'riyadh',
      name: 'الرياض (الريال السعودي)',
      currency: 'ر.س',
      defaultGold24: 330.0,
      defaultGold21: 288.0,
      defaultGold18: 247.0,
      defaultSilver: 3.85,
      usdRate: 3.75,
    ),
    RegionalMarketInfo(
      id: 'cairo',
      name: 'القاهرة (الجنيه المصري)',
      currency: 'ج.م',
      defaultGold24: 4200.0,
      defaultGold21: 3675.0,
      defaultGold18: 3150.0,
      defaultSilver: 48.0,
      usdRate: 48.5,
    ),
    RegionalMarketInfo(
      id: 'global',
      name: 'السوق العالمي (الدولار الأمريكي)',
      currency: '\$',
      defaultGold24: 88.5,
      defaultGold21: 77.4,
      defaultGold18: 66.3,
      defaultSilver: 1.05,
      usdRate: 1.0,
    ),
  ];

  static RegionalMarketInfo getMarketById(String id) {
    return supportedMarkets.firstWhere(
      (m) => m.id == id,
      orElse: () => supportedMarkets.first,
    );
  }

  /// Fetches prices online from free public gold API with timeout and graceful fallback
  static Future<MarketPricesResult> fetchPrices({String cityId = 'sanaa'}) async {
    final market = getMarketById(cityId);

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);

      // Gold spot price query (XAU in USD)
      final request = await client
          .getUrl(Uri.parse('https://api.gold-api.com/price/XAU'))
          .timeout(const Duration(seconds: 4));
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final xauPrice = (json['price'] as num?)?.toDouble();

        if (xauPrice != null && xauPrice > 0) {
          // 1 Troy Ounce = 31.1034768 grams pure gold (24 Karat)
          final usdPerGram24 = xauPrice / 31.1034768;

          double g24 = usdPerGram24 * market.usdRate;
          double g21 = g24 * (21.0 / 24.0);
          double g18 = g24 * (18.0 / 24.0);
          // Silver estimate based on gold/silver ratio (~80:1) or benchmark
          double silver = (g24 / 80.0);

          // Round according to currency magnitude
          if (market.usdRate >= 100) {
            g24 = (g24 / 50).round() * 50.0;
            g21 = (g21 / 50).round() * 50.0;
            g18 = (g18 / 50).round() * 50.0;
            silver = (silver / 10).round() * 10.0;
          } else {
            g24 = double.parse(g24.toStringAsFixed(2));
            g21 = double.parse(g21.toStringAsFixed(2));
            g18 = double.parse(g18.toStringAsFixed(2));
            silver = double.parse(silver.toStringAsFixed(2));
          }

          final now = DateTime.now();
          final isExchangeFixed = market.usdRate != 1.0;
          final exchangeNote = isExchangeFixed
              ? 'تنبيه: سعر صرف العملة مقابل الدولار (${market.usdRate} ${market.currency} / USD) معتمد وفق التسعيرة الإقليمية، وليس تعويماً حراً لحظياً.'
              : null;

          final snapshot = PriceSnapshot(
            gold24: g24,
            gold21: g21,
            gold18: g18,
            silver: silver,
            currency: market.currency,
            source: 'بورصة الذهب العالمية (Gold API) - ${market.name}',
            updatedAt: now,
            isFallback: false,
            isSilverEstimated: true,
            isExchangeRateFixed: isExchangeFixed,
            silverNote: 'تنبيه: سعر الفضة تقديري مبني على نسبة الذهب/الفضة (80:1) وليس تسعيراً مباشراً من بورصة الفضة.',
            exchangeRateNote: exchangeNote,
          );

          return MarketPricesResult(
            cityId: market.id,
            cityName: market.name,
            currency: market.currency,
            gold24Price: g24,
            gold21Price: g21,
            gold18Price: g18,
            silverPrice: silver,
            updatedAt: now,
            isLiveApi: true,
            message: 'تم تحديث الأسعار اللحظية من السوق العالمي بنجاح لـ ${market.name}',
            snapshot: snapshot,
          );
        }
      }
    } catch (_) {
      // Graceful fallback to verified regional benchmark
    }

    final fallbackNow = DateTime.now();
    final isExchangeFixed = market.usdRate != 1.0;
    final fallbackExchangeNote = isExchangeFixed
        ? 'تنبيه: سعر الصرف (${market.usdRate} ${market.currency} / USD) معتمد وفق التسعيرة السائدة الإقليمية.'
        : null;

    final fallbackSnapshot = PriceSnapshot(
      gold24: market.defaultGold24,
      gold21: market.defaultGold21,
      gold18: market.defaultGold18,
      silver: market.defaultSilver,
      currency: market.currency,
      source: 'الأسعار السائدة المعتمدة - ${market.name}',
      updatedAt: fallbackNow,
      isFallback: true,
      isSilverEstimated: false,
      isExchangeRateFixed: isExchangeFixed,
      silverNote: 'سعر الفضة معتمد وفق التسعيرة السائدة لـ ${market.name}.',
      exchangeRateNote: fallbackExchangeNote,
    );

    // Return verified regional benchmark
    return MarketPricesResult(
      cityId: market.id,
      cityName: market.name,
      currency: market.currency,
      gold24Price: market.defaultGold24,
      gold21Price: market.defaultGold21,
      gold18Price: market.defaultGold18,
      silverPrice: market.defaultSilver,
      updatedAt: fallbackNow,
      isLiveApi: false,
      message: 'تم تطبيق الأسعار السائدة المعتمدة لـ ${market.name}',
      snapshot: fallbackSnapshot,
    );
  }
}
