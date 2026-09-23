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
