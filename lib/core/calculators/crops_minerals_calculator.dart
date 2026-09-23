import '../constants/zakat_constants.dart';
import 'zakat_calculation_result.dart';

class CropsMineralsCalculator {
  static ZakatCalculationResult calculateCrops({
    double? totalCropValue,
    required String irrigationType, // 'natural' or 'artificial' or 'mixed'
    required double weightInKg,
    String currency = 'ر.ي',
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
        ? '${inKindWeight.toStringAsFixed(1)} كجم من المحصول (أو قيمتها: ${zakatCash.toStringAsFixed(2)} $currency)'
        : '${inKindWeight.toStringAsFixed(1)} كجم من المحصول عيناً';

    final String explanation = hasMonetaryValue
        ? 'نوع السقي: $irrigationDesc. الواجب إخراجه: ${zakatCash.toStringAsFixed(2)} $currency (أو ${inKindWeight.toStringAsFixed(1)} كجم عيناً).'
        : 'نوع السقي: $irrigationDesc. الواجب إخراجه عيناً: ${inKindWeight.toStringAsFixed(1)} كجم من المحصول (وهو الأصل الشرعي لزكاة الزروع يوم الحصاد).';

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakatCash,
      zakatInKindDescription: inKind,
      explanation: explanation,
    );
  }

  static ZakatCalculationResult calculateMinerals({
    required double totalExtractedValue,
    required bool isRikaz,
    required double gold24Price,
    String currency = 'ر.ي',
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

    final nisab = customNisabThreshold ?? (ZakatConstants.goldNisabGrams * gold24Price);

    if (isRikaz) {
      final rate = customMineralRate ?? 0.20;
      final zakat = totalExtractedValue * rate;
      return ZakatCalculationResult(
        reachedNisab: true,
        zakatAmount: zakat,
        appliedPrice: gold24Price,
        explanation: 'الركاز (دفين الجاهلية والكنوز القديمة) يجب فيه الخُمس (${(rate * 100).toStringAsFixed(0)}%) فور استخراجه وفق السياسة المعتمدة دون اشتراط حول أو نصاب.',
      );
    }

    if (totalExtractedValue < nisab) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: nisab,
        appliedPrice: gold24Price,
        explanation: 'لم تبلغ قيمة المعادن النصاب الشرعي (المعادل لقيمة 85 جرام ذهب خالص عيار 24: ${nisab.toStringAsFixed(2)} $currency).',
      );
    }

    // وفق المعتمد في فقه الزيدية والهادوية (متن الأزهار وشروحه والبحر الزخار):
    // "وفي المعادن الخُمس"، فالمعادن ملحقة بالركاز في وجوب الخمس (20%) فور استخراجها.
    // وإن كانت بمؤنة استخراج باهظة فيجوز إخراج نصف الخمس (10%) أو ربع العشر (2.5%) رعاية للجهد.
    final rate = customMineralRate ?? 0.20; // 20% الخمس هو معتمد الهادوية والزيدية
    final zakat = totalExtractedValue * rate;
    final ratePercent = (rate * 100).toStringAsFixed(rate % 1 == 0 ? 0 : 1);

    final String fiqhNote = rate == 0.20
        ? 'المعتمد في فقه الزيدية والهادوية (متن الأزهار والبحر الزخار): في المعادن المستخرجة الخُمس ($ratePercent%) كركاز فور استخراجها.'
        : 'تم احتساب الزكاة بنسبة ($ratePercent%) مراعاة لنفقات ومؤنة الاستخراج والآلات.';

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakat,
      nisabThreshold: nisab,
      appliedPrice: gold24Price,
      explanation: 'بلغت المعادن المستخرجة النصاب الشرعي (المعادل لـ 85 جرام ذهب خالص عيار 24: ${nisab.toStringAsFixed(2)} $currency).\n$fiqhNote\nالمقدار الواجب إخراجه: ${zakat.toStringAsFixed(2)} $currency.',
    );
  }
}
