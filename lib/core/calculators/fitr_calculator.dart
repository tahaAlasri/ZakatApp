import '../constants/zakat_constants.dart';
import 'zakat_calculation_result.dart';

class FitrCalculator {
  static ZakatCalculationResult calculate({
    required int familyMembers,
    double? stapleBagPrice,
    double bagWeightKg = ZakatConstants.defaultWheatBagWeightKg,
    double? cashValuePerPerson,
    double saWeightKg = ZakatConstants.fitrSaWeightKg,
    bool isCashPayment = true,
    String stapleName = 'القمح',
    String currency = 'ر.ي',
  }) {
    if (familyMembers <= 0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'يرجى إدخال عدد صحيح لأفراد الأسرة (فرد واحد على الأقل).',
      );
    }

    final saCountInBag = saWeightKg > 0 ? (bagWeightKg / saWeightKg) : 20.0;

    final effectivePerPerson = cashValuePerPerson ??
        (stapleBagPrice != null && saCountInBag > 0
            ? (stapleBagPrice / saCountInBag)
            : ZakatConstants.defaultFitrCashYER);

    final totalCash = double.parse((familyMembers * effectivePerPerson).toStringAsFixed(2));
    final totalWeightKg = double.parse((familyMembers * saWeightKg).toStringAsFixed(2));
    final bagsEquivalent = bagWeightKg > 0 ? (totalWeightKg / bagWeightKg) : 0.0;

    final String bagsDesc = bagsEquivalent >= 1.0
        ? ' (ما يعادل ${bagsEquivalent.toStringAsFixed(1)} وحدة زنة ${bagWeightKg.toStringAsFixed(0)} كجم)'
        : (bagsEquivalent > 0
            ? ' (ما يعادل ${(bagsEquivalent * 100).toStringAsFixed(0)}% من وحدة زنة ${bagWeightKg.toStringAsFixed(0)} كجم)'
            : '');

    final inKindDesc = '$totalWeightKg كجم من $stapleName ($familyMembers صاع نبوي)$bagsDesc';

    String explanation;
    if (stapleBagPrice != null && stapleBagPrice > 0) {
      explanation = isCashPayment
          ? 'بناءً على سعر $stapleName (زنة ${bagWeightKg.toStringAsFixed(0)} كجم بسعر ${stapleBagPrice.toStringAsFixed(0)} $currency)، فإنه يحتوي على ${saCountInBag.toStringAsFixed(0)} صاعاً نبوياً (بواقع $saWeightKg كجم للصاع).\n'
            'وعليه فإن نصيب الفرد الواحد هو: ${effectivePerPerson.toStringAsFixed(0)} $currency.\n'
            'الواجب إخراجه نقداً عن $familyMembers أفراد هو: ${totalCash.toStringAsFixed(0)} $currency (أو ما يعادل $inKindDesc).'
          : 'الواجب إخراجه عيناً عن $familyMembers أفراد هو: $inKindDesc (بمعدل صاع نبوي ≈ $saWeightKg كجم لكل فرد من طعام أهل البلد).';
    } else {
      explanation = isCashPayment
          ? 'الواجب إخراجه نقداً عن $familyMembers أفراد هو: ${totalCash.toStringAsFixed(0)} $currency (بواقع ${effectivePerPerson.toStringAsFixed(0)} $currency للفرد الواحد، أو ما يعادل $inKindDesc).'
          : 'الواجب إخراجه عيناً عن $familyMembers أفراد هو: $inKindDesc (بمعدل صاع نبوي ≈ $saWeightKg كجم لكل فرد من $stapleName).';
    }

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: totalCash,
      zakatInKindDescription: inKindDesc,
      explanation: explanation,
    );
  }
}
