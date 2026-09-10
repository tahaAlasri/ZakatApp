class ZakatConstants {
  // Nisab thresholds in grams
  static const double goldNisabGrams = 85.0; // 85 grams of 24k gold
  static const double silverNisabGrams = 595.0; // 595 grams of pure silver

  // Standard Zakat percentage
  static const double standardZakatRate = 0.025; // 2.5% (ربع العشر)

  // Crops Zakat rates
  static const double rainFedRate = 0.10; // 10% سقيت بماء المطر / سيحاً (العشر)
  static const double irrigatedRate = 0.05; // 5% سقيت بالآلات والنواضح (نصف العشر)
  static const double mixedRate = 0.075; // 7.5% مشتركة

  // Default market estimates (Can be edited by user dynamically)
  static const double defaultGold21PriceYER = 55000.0;
  static const double defaultGold24PriceYER = 62850.0;
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
