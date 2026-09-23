class ZakatConstants {
  // Nisab thresholds in grams
  static const double goldNisabGrams = 85.0; // 85 grams of 24k gold
  static const double silverNisabGrams = 595.0; // 595 grams of pure silver

  // Standard Zakat percentage
  static const double standardZakatRate = 0.025; // 2.5% (ربع العشر) - السنة الهجرية القمرية (354 يوماً)
  // نسبة الزكاة بالسنة الميلادية الشمسية (365 يوماً) وفق قرار مجمع الفقه الإسلامي الدولي ومعيار AAOIFI رقم 35
  static const double solarZakatRate = 0.02577; // 2.577% لتعويض فرق الـ 11 يوماً عن السنة القمرية

  // Crops Zakat rates
  static const double rainFedRate = 0.10; // 10% سقيت بماء المطر / سيحاً (العشر)
  static const double irrigatedRate = 0.05; // 5% سقيت بالآلات والنواضح (نصف العشر)
  static const double mixedRate = 0.075; // 7.5% مشتركة
  static const double cropsNisabKg = 612.0; // 5 أوسق = 300 صاع نبوي ≈ 612 كجم من الحبوب والثمار

  // Zakat al-Fitr constants
  static const double fitrSaWeightKg = 2.5; // الصاع النبوي بالكيلوغرام (حوالي 2.5 كجم من غالب قوت البلد)
  static const double defaultWheatBagWeightKg = 50.0; // وزن كيس القمح الشائع (50 كجم = 20 صاع نبوي)
  static const double defaultWheatBagPriceYER = 24000.0; // السعر التقديري لكيس القمح 50 كجم بالريال اليمني
  static const double defaultFitrCashYER = 1200.0; // القيمة التقديرية النقدية للصاع (24000 ÷ 20 صاع)

  // Default market estimates (Can be edited by user dynamically)
  static const double defaultGold24PriceYER = 62850.0; // الأساس المعتمد للنصاب الشرعي
  static const double defaultGold21PriceYER = 55000.0;
  static const double defaultGold18PriceYER = 47150.0;
  static const double defaultSilverPriceYER = 700.0;

  // Livestock Nisab thresholds
  static const int camelNisab = 5;
  static const int cowNisab = 30;
  static const int sheepNisab = 40;

  // Currencies list
  static const List<String> supportedCurrencies = [
    'ر.ي (ريال يمني)',
    'ر.س (ريال سعودي)',
    'د.إ (درهم إماراتي)',
    'ج.م (جنيه مصري)',
    '\$ (دولار أمريكي)',
  ];
}
