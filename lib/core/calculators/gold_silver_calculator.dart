import '../constants/zakat_constants.dart';
import 'zakat_calculation_result.dart';

class GoldSilverCalculator {
  static ZakatCalculationResult calculateGold({
    required double grams,
    required int karat,
    required double gold24Price,
    required double gold21Price,
    required double gold18Price,
    String currency = 'ر.ي',
    double? pricePerGram,
    bool isPersonalJewelry = false,
    bool madhhabRequiresZakat = false,
  }) {
    double price = pricePerGram ?? switch (karat) {
      24 => gold24Price,
      21 => gold21Price,
      18 => gold18Price,
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

    if (isPersonalJewelry && !madhhabRequiresZakat) {
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
    final nisabCashThreshold = ZakatConstants.goldNisabGrams * gold24Price;

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

    final jewelryNote = (isPersonalJewelry && madhhabRequiresZakat)
        ? ' (معتمد فقه الزيدية والهادوية بنص الأزهار: «وتجب في حليّ ولو مباحاً»، ومذهب الحنفية: تجب الزكاة في الحلي المعد للزينة إذا بلغ النصاب وحال عليه الحول)'
        : '';

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakatCashValue,
      nisabThreshold: nisabCashThreshold,
      appliedPrice: price,
      goldKarat: karat,
      zakatInKindDescription: '$inKindText (أو قيمتها: ${zakatCashValue.toStringAsFixed(2)} $currency)',
      explanation: 'اكتمل النصاب. المقدار الواجب إخراجه ربع العشر (2.5%) عيناً أو ما يعادله نقداً بسعر جرام عيار $karat ($price $currency).$jewelryNote',
    );
  }

  static ZakatCalculationResult calculateSilver({
    required double grams,
    required double silverPrice,
    String currency = 'ر.ي',
    double? pricePerGram,
  }) {
    final price = pricePerGram ?? silverPrice;
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
      zakatInKindDescription: '${zakatGrams.toStringAsFixed(2)} جرام فضة (أو قيمتها: ${zakatCashValue.toStringAsFixed(2)} $currency)',
      explanation: 'اكتمل النصاب. المقدار الواجب إخراجه ربع العشر (2.5%).',
    );
  }

  /// قاعدة ضم الذهب إلى الفضة لتكميل النصاب بالأجزاء
  /// وفق المعتمد في فقه الزيدية والهادوية (متن الأزهار للإمام ابن المرتضى: «ويضم الذهب إلى الفضة بالأجزاء»)
  static ZakatCalculationResult calculateCombinedGoldSilver({
    required double goldGrams,
    required int goldKarat,
    required double silverGrams,
    required double gold24Price,
    required double silverPrice,
    String currency = 'ر.ي',
  }) {
    final double pureGoldGrams = (goldGrams * goldKarat) / 24.0;
    final double goldFraction = pureGoldGrams / ZakatConstants.goldNisabGrams;
    final double silverFraction = silverGrams > 0 ? (silverGrams / ZakatConstants.silverNisabGrams) : 0.0;
    final double totalFraction = goldFraction + silverFraction;

    final double goldPrice = gold24Price * (goldKarat / 24.0);
    final double totalCashValue = (goldGrams * goldPrice) + (silverGrams * silverPrice);
    final double combinedNisabCash = ZakatConstants.goldNisabGrams * gold24Price;

    if (totalFraction < 1.0) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        nisabThreshold: combinedNisabCash,
        explanation: 'وفق قاعدة ضم الذهب إلى الفضة بالأجزاء في فقه الهادوية والزيدية (متن الأزهار): لم يكتمل النصاب المشترك. نسبة النصاب المتحققة: ${(totalFraction * 100).toStringAsFixed(1)}% (ذهب: ${(goldFraction * 100).toStringAsFixed(1)}% + فضة: ${(silverFraction * 100).toStringAsFixed(1)}%).',
      );
    }

    final double zakatGoldGrams = goldGrams * ZakatConstants.standardZakatRate;
    final double zakatSilverGrams = silverGrams * ZakatConstants.standardZakatRate;
    final double zakatCash = (zakatGoldGrams * goldPrice) + (zakatSilverGrams * silverPrice);

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: zakatCash,
      nisabThreshold: combinedNisabCash,
      explanation: 'اكتمل النصاب الشرعي بضم الذهب إلى الفضة بالأجزاء وفق مذهب الهادوية والزيدية (مجموع الأجزاء: ${(totalFraction * 100).toStringAsFixed(1)}%).\nإجمالي القيمة: ${totalCashValue.toStringAsFixed(2)} $currency.\nالواجب إخراجه ربع العشر (2.5%): ${zakatGoldGrams.toStringAsFixed(2)} جرام ذهب و ${zakatSilverGrams.toStringAsFixed(2)} جرام فضة (أو ما يعادلهما نقداً: ${zakatCash.toStringAsFixed(2)} $currency).',
      zakatInKindDescription: '${zakatGoldGrams.toStringAsFixed(2)}غ ذهب عيار $goldKarat + ${zakatSilverGrams.toStringAsFixed(2)}غ فضة',
    );
  }
}
