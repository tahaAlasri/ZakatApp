import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../../views/calculators/money_calc_screen.dart';
import '../../views/calculators/gold_calc_screen.dart';
import '../../views/calculators/silver_calc_screen.dart';
import '../../views/calculators/trade_calc_screen.dart';
import '../../views/calculators/crops_calc_screen.dart';
import '../../views/calculators/livestock_calc_screen.dart';
import '../../views/calculators/minerals_screen.dart';
import '../../views/calculators/fields_calc_screen.dart';
import '../../views/calculators/fitr_calc_screen.dart';
import '../../views/calculators/stocks_calc_screen.dart';
import '../../views/calculators/crypto_calc_screen.dart';

class ZakatCategoryItem {
  final String title;
  final String shortTitle;
  final String description;
  final String imagePath;
  final Widget targetScreen;
  final Color badgeColor;
  final String nisabBadge;
  final String group; // 'money', 'livestock', 'crops', 'activities'

  const ZakatCategoryItem({
    required this.title,
    required this.shortTitle,
    required this.description,
    required this.imagePath,
    required this.targetScreen,
    this.badgeColor = AppColors.emeraldPrimary,
    this.nisabBadge = '',
    this.group = 'money',
  });
}

const List<ZakatCategoryItem> appZakatCategories = [
  ZakatCategoryItem(
    title: 'زكاة المال والنقود',
    shortTitle: 'زكاة المال',
    description: 'حساب زكاة السيولة النقدية والودائع البنكية والمدخرات',
    imagePath: 'assets/images/money.png',
    targetScreen: MoneyCalcScreen(),
    nisabBadge: 'نصاب 85غ ذهب 21',
    group: 'money',
  ),
  ZakatCategoryItem(
    title: 'زكاة الذهب',
    shortTitle: 'زكاة الذهب',
    description: 'حساب زكاة سبائك وحلي الذهب بعيارات 24، 21، 18',
    imagePath: 'assets/images/gold.png',
    targetScreen: GoldCalcScreen(),
    nisabBadge: 'نصاب 85غ خالص',
    group: 'money',
  ),
  ZakatCategoryItem(
    title: 'زكاة الفضة',
    shortTitle: 'زكاة الفضة',
    description: 'حساب زكاة الفضة والسبائك بنصاب 595 جراماً',
    imagePath: 'assets/images/silver.png',
    targetScreen: SilverCalcScreen(),
    nisabBadge: 'نصاب 595 جراماً',
    group: 'money',
  ),
  ZakatCategoryItem(
    title: 'زكاة الفطر المباركة',
    shortTitle: 'زكاة الفطر',
    description: 'حساب زكاة الفطر طهرة للصائم بالصاع النبوي أو نقداً',
    imagePath: 'assets/images/fitr.png',
    targetScreen: FitrCalcScreen(),
    nisabBadge: 'صاع عن كل فرد',
    badgeColor: AppColors.goldAccent,
    group: 'activities',
  ),
  ZakatCategoryItem(
    title: 'عروض التجارة والصناعة',
    shortTitle: 'عروض التجارة',
    description: 'حساب زكاة البضائع والمؤسسات والمحلات التجارية',
    imagePath: 'assets/images/trade.png',
    targetScreen: TradeCalcScreen(),
    nisabBadge: 'عروض التجارة',
    group: 'activities',
  ),
  ZakatCategoryItem(
    title: 'زكاة الحبوب والثمار',
    shortTitle: 'الحبوب والثمار',
    description: 'حساب زكاة الزروع والمحاصيل بالري الطبيعي والصناعي',
    imagePath: 'assets/images/crops.png',
    targetScreen: CropsCalcScreen(),
    nisabBadge: 'نصاب 612 كجم',
    group: 'crops',
  ),
  ZakatCategoryItem(
    title: 'زكاة الإبل',
    shortTitle: 'زكاة الإبل',
    description: 'حساب زكاة الإبل السائمة بنصاب يبدأ من 5 رؤوس',
    imagePath: 'assets/images/camel.png',
    targetScreen: LivestockCalcScreen(initialTabIndex: 0),
    nisabBadge: 'نصاب 5 رؤوس',
    group: 'livestock',
  ),
  ZakatCategoryItem(
    title: 'زكاة البقر والجاموس',
    shortTitle: 'زكاة البقر',
    description: 'حساب زكاة البقر السائم بنصاب يبدأ من 30 بقرة',
    imagePath: 'assets/images/cow.png',
    targetScreen: LivestockCalcScreen(initialTabIndex: 1),
    nisabBadge: 'نصاب 30 بقرة',
    group: 'livestock',
  ),
  ZakatCategoryItem(
    title: 'زكاة الغنم والماعز',
    shortTitle: 'زكاة الغنم',
    description: 'حساب زكاة الضأن والماعز السائم بنصاب 40 شاة',
    imagePath: 'assets/images/goat.png',
    targetScreen: LivestockCalcScreen(initialTabIndex: 2),
    nisabBadge: 'نصاب 40 شاة',
    group: 'livestock',
  ),
  ZakatCategoryItem(
    title: 'الركاز والمعادن',
    shortTitle: 'الركاز والمعادن',
    description: 'ما يجب في دفين الجاهلية (الخمس) والمعادن المستخرجة',
    imagePath: 'assets/images/minral.png',
    targetScreen: MineralsScreen(),
    nisabBadge: 'الخمس 20%',
    group: 'activities',
  ),
  ZakatCategoryItem(
    title: 'زكاة المستغلات',
    shortTitle: 'زكاة المستغلات',
    description: 'حساب ريع العقارات المؤجرة والمصانع وسيارات الأجرة',
    imagePath: 'assets/images/fields.png',
    targetScreen: FieldsCalcScreen(),
    nisabBadge: 'صافي الريع 2.5%',
    group: 'activities',
  ),
  ZakatCategoryItem(
    title: 'زكاة الأسهم والاستثمار',
    shortTitle: 'زكاة الأسهم',
    description: 'حساب زكاة أسهم المضاربة والاستثمار طويل الأجل والصناديق',
    imagePath: 'assets/images/stocks.png',
    targetScreen: StocksCalcScreen(),
    nisabBadge: 'نصاب الذهب',
    group: 'activities',
  ),
  ZakatCategoryItem(
    title: 'العملات الرقمية والمشفرة',
    shortTitle: 'العملات الرقمية',
    description: 'حساب زكاة البيتكوين والعملات المشفرة',
    imagePath: 'assets/images/crypto.png',
    targetScreen: CryptoCalcScreen(),
    nisabBadge: 'نصاب الذهب',
    group: 'activities',
  ),
];
