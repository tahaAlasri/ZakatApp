import '../constants/zakat_constants.dart';
import 'zakat_calculation_result.dart';

class TradeCalculator {
  static ZakatCalculationResult calculate({
    required double inventoryValue,
    required double cashInHand,
    required double receivables,
    required double liabilities,
    required double gold24Price,
    double? silverPrice,
    bool useSilverNisab = false,
    String currency = 'ر.ي',
    bool isSolarYear = false,
  }) {
    final netWorth = (inventoryValue + cashInHand + receivables) - liabilities;
    final effectiveSilver = silverPrice ?? 0.0;
    final nisabThreshold = (useSilverNisab && effectiveSilver > 0)
        ? (ZakatConstants.silverNisabGrams * effectiveSilver)
        : (ZakatConstants.goldNisabGrams * gold24Price);

    final appliedPrice = (useSilverNisab && effectiveSilver > 0) ? effectiveSilver : gold24Price;
    final nisabLabel = (useSilverNisab && effectiveSilver > 0)
        ? '595 جرام فضة (الأحظ والأنفع للفقراء والمساكين)'
        : '85 جرام ذهب عيار 24 خالص';

    if (netWorth <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisabThreshold,
        appliedPrice: appliedPrice,
        explanation: 'صافي عروض التجارة لا يبلغ النصاب أو مدين.',
      );
    }

    final reachedNisab = netWorth >= nisabThreshold;
    if (!reachedNisab) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisabThreshold,
        appliedPrice: appliedPrice,
        explanation: 'لم يكتمل النصاب الشرعي لعروض التجارة (المعادل لـ $nisabLabel: ${nisabThreshold.toStringAsFixed(2)} $currency). صافي الوعاء: ${netWorth.toStringAsFixed(2)} $currency.',
      );
    }

    final rate = isSolarYear ? ZakatConstants.solarZakatRate : ZakatConstants.standardZakatRate;
    final rateLabel = isSolarYear ? '2.577% (سنة ميلادية)' : '2.5% (ربع العشر)';
    final zakat = netWorth * rate;
    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakat,
      nisabThreshold: nisabThreshold,
      appliedPrice: appliedPrice,
      explanation: 'اكتمل النصاب الشرعي لعروض التجارة بناءً على $nisabLabel.\nصافي الوعاء الزكوي الخاضع بعد تسوية الديون: ${netWorth.toStringAsFixed(2)} $currency. الواجب إخراجه $rateLabel = ${zakat.toStringAsFixed(2)} $currency.',
    );
  }
}
