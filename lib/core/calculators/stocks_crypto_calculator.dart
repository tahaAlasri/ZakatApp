import '../constants/zakat_constants.dart';
import 'zakat_calculation_result.dart';

class StocksCryptoCalculator {
  static ZakatCalculationResult calculateStocks({
    required double sharesCount,
    required double shareMarketPrice,
    required bool isSpeculation,
    required double gold24Price,
    String currency = 'ر.ي',
    double dividendPerShare = 0.0,
    bool isSolarYear = false,
  }) {
    if (sharesCount <= 0 || shareMarketPrice <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'يرجى إدخال عدد أسهم وسعر صحيحين (أكبر من الصفر)',
      );
    }

    final nisabThreshold = ZakatConstants.goldNisabGrams * gold24Price;
    final totalMarketValue = sharesCount * shareMarketPrice;
    final rate = isSolarYear ? ZakatConstants.solarZakatRate : ZakatConstants.standardZakatRate;
    final rateLabel = isSolarYear ? '2.577%' : '2.5%';

    if (isSpeculation) {
      if (totalMarketValue < nisabThreshold) {
        return ZakatCalculationResult(
          reachedNisab: false,
          zakatAmount: 0,
          nisabThreshold: nisabThreshold,
          appliedPrice: gold24Price,
          explanation: 'القيمة السوقية لأسهم المضاربة (${totalMarketValue.toStringAsFixed(2)} $currency) لم تبلغ النصاب الشرعي (${nisabThreshold.toStringAsFixed(2)} $currency).',
        );
      }
      final zakat = totalMarketValue * rate;
      return ZakatCalculationResult(
        reachedNisab: true,
        zakatAmount: zakat,
        nisabThreshold: nisabThreshold,
        appliedPrice: gold24Price,
        explanation: 'أسهم مضاربة (عروض تجارة): الوعاء الزكوي هو القيمة السوقية الإجمالية (${totalMarketValue.toStringAsFixed(2)} $currency). الواجب إخراجه $rateLabel = ${zakat.toStringAsFixed(2)} $currency.',
      );
    } else {
      final effectiveBase = dividendPerShare > 0 ? (sharesCount * dividendPerShare) : (totalMarketValue * 0.10);
      if (effectiveBase < nisabThreshold) {
        return ZakatCalculationResult(
          reachedNisab: false,
          zakatAmount: 0,
          nisabThreshold: nisabThreshold,
          appliedPrice: gold24Price,
          explanation: 'الوعاء الخاضع لأسهم الاستثمار (${effectiveBase.toStringAsFixed(2)} $currency) لم يبلغ النصاب الشرعي (${nisabThreshold.toStringAsFixed(2)} $currency).',
        );
      }
      final zakat = effectiveBase * rate;
      return ZakatCalculationResult(
        reachedNisab: true,
        zakatAmount: zakat,
        nisabThreshold: nisabThreshold,
        appliedPrice: gold24Price,
        explanation: 'أسهم استثمار طويل الأجل: تُحسب الزكاة على العائد/الأصول الزكوية (${effectiveBase.toStringAsFixed(2)} $currency) بنسبة $rateLabel = ${zakat.toStringAsFixed(2)} $currency.',
      );
    }
  }

  static ZakatCalculationResult calculateCrypto({
    required double cryptoAmount,
    required double cryptoMarketPriceInFiat,
    required double gold24Price,
    String currency = 'ر.ي',
    bool isSolarYear = false,
  }) {
    if (cryptoAmount <= 0 || cryptoMarketPriceInFiat <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'يرجى إدخال كمية وسعر سوقي صحيحين (أكبر من الصفر).',
      );
    }

    final totalFiatValue = cryptoAmount * cryptoMarketPriceInFiat;
    final nisabThreshold = ZakatConstants.goldNisabGrams * gold24Price;

    if (totalFiatValue < nisabThreshold) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisabThreshold,
        appliedPrice: gold24Price,
        explanation: 'القيمة الإجمالية للعملات الرقمية (${totalFiatValue.toStringAsFixed(2)} $currency) لم تبلغ النصاب الشرعي (${nisabThreshold.toStringAsFixed(2)} $currency).',
      );
    }

    final rate = isSolarYear ? ZakatConstants.solarZakatRate : ZakatConstants.standardZakatRate;
    final rateLabel = isSolarYear ? '2.577% (سنة ميلادية)' : '2.5%';
    final zakat = totalFiatValue * rate;

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakat,
      nisabThreshold: nisabThreshold,
      appliedPrice: gold24Price,
      explanation: 'اكتمل النصاب. الوعاء الزكوي للأصول الرقمية هو قيمتها السوقية الحالية (${totalFiatValue.toStringAsFixed(2)} $currency). الواجب إخراجه $rateLabel = ${zakat.toStringAsFixed(2)} $currency.',
    );
  }
}
