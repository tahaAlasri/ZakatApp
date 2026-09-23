import '../constants/zakat_constants.dart';
import 'zakat_calculation_result.dart';

class MoneyCalculator {
  static ZakatCalculationResult calculate({
    required double moneyAmount,
    required double gold24Price,
    required double silverPrice,
    String currency = 'ر.ي',
    double? goldPricePerGram,
    double receivables = 0.0,
    double liabilities = 0.0,
    bool useSilverNisab = false,
    bool isSolarYear = false,
  }) {
    final goldPrice = goldPricePerGram ?? gold24Price;
    final effectivePrice = useSilverNisab ? silverPrice : goldPrice;
    final nisabThreshold = useSilverNisab
        ? (ZakatConstants.silverNisabGrams * silverPrice)
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
        ? '595 جرام فضة خالصة: ${nisabThreshold.toStringAsFixed(2)} $currency (الأحظ للفقراء)'
        : '85 جرام ذهب خالص عيار 24: ${nisabThreshold.toStringAsFixed(2)} $currency';

    if (!reachedNisab) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisabThreshold,
        appliedPrice: effectivePrice,
        explanation: 'لم يكتمل النصاب الشرعي (المعادِل لـ $nisabDescription). صافي الوعاء: ${netWealth.toStringAsFixed(2)} $currency.',
      );
    }

    final rate = isSolarYear ? ZakatConstants.solarZakatRate : ZakatConstants.standardZakatRate;
    final rateLabel = isSolarYear ? '2.577% (سنة ميلادية)' : '2.5% (ربع العشر)';
    final zakat = netWealth * rate;
    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakat,
      nisabThreshold: nisabThreshold,
      appliedPrice: effectivePrice,
      explanation: 'اكتمل النصاب الشرعي ($nisabDescription). صافي الوعاء الخاضع بعد تسوية الديون: ${netWealth.toStringAsFixed(2)} $currency. الواجب إخراجه $rateLabel = ${zakat.toStringAsFixed(2)} $currency',
    );
  }
}
