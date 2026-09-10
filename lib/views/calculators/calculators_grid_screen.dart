import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'money_calc_screen.dart';
import 'gold_calc_screen.dart';
import 'silver_calc_screen.dart';
import 'trade_calc_screen.dart';
import 'crops_calc_screen.dart';
import 'livestock_calc_screen.dart';
import 'minerals_screen.dart';
import 'fields_calc_screen.dart';

class ZakatCategoryItem {
  final String title;
  final String description;
  final String imagePath;
  final Widget targetScreen;
  final Color badgeColor;

  ZakatCategoryItem({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.targetScreen,
    this.badgeColor = AppColors.emeraldPrimary,
  });
}

class CalculatorsGridScreen extends StatefulWidget {
  const CalculatorsGridScreen({super.key});

  @override
  State<CalculatorsGridScreen> createState() => _CalculatorsGridScreenState();
}

class _CalculatorsGridScreenState extends State<CalculatorsGridScreen> {
  String _searchQuery = '';

  List<ZakatCategoryItem> _getAllItems() {
    return [
      ZakatCategoryItem(
        title: 'زكاة المال والنقود',
        description: 'حساب زكاة السيولة النقدية والودائع البنكية والمدخرات',
        imagePath: 'assets/images/money.png',
        targetScreen: const MoneyCalcScreen(),
      ),
      ZakatCategoryItem(
        title: 'زكاة الذهب',
        description: 'حساب زكاة سبائك وحلي الذهب بعيارات 24، 21، 18',
        imagePath: 'assets/images/gold.png',
        targetScreen: const GoldCalcScreen(),
      ),
      ZakatCategoryItem(
        title: 'زكاة الفضة',
        description: 'حساب زكاة الفضة والسبائك بنصاب 595 جراماً',
        imagePath: 'assets/images/silver.png',
        targetScreen: const SilverCalcScreen(),
      ),
      ZakatCategoryItem(
        title: 'عروض التجارة والصناعة',
        description: 'حساب زكاة البضائع والمؤسسات والمحلات التجارية',
        imagePath: 'assets/images/trade.png',
        targetScreen: const TradeCalcScreen(),
      ),
      ZakatCategoryItem(
        title: 'زكاة الحبوب والثمار',
        description: 'حساب زكاة الزروع والمحاصيل بالري الطبيعي والصناعي',
        imagePath: 'assets/images/crops.png',
        targetScreen: const CropsCalcScreen(),
      ),
      ZakatCategoryItem(
        title: 'زكاة الإبل',
        description: 'حساب زكاة الإبل السائمة بنصاب يبدأ من 5 رؤوس',
        imagePath: 'assets/images/camel.png',
        targetScreen: const LivestockCalcScreen(initialTabIndex: 0),
      ),
      ZakatCategoryItem(
        title: 'زكاة البقر والجاموس',
        description: 'حساب زكاة البقر السائم بنصاب يبدأ من 30 بقرة',
        imagePath: 'assets/images/cow.png',
        targetScreen: const LivestockCalcScreen(initialTabIndex: 1),
      ),
      ZakatCategoryItem(
        title: 'زكاة الغنم والماعز',
        description: 'حساب زكاة الضأن والماعز السائم بنصاب 40 شاة',
        imagePath: 'assets/images/goat.png',
        targetScreen: const LivestockCalcScreen(initialTabIndex: 2),
      ),
      ZakatCategoryItem(
        title: 'الركاز والمعادن',
        description: 'ما يجب في دفين الجاهلية (الخمس) والمعادن المستخرجة',
        imagePath: 'assets/images/minral.png',
        targetScreen: const MineralsScreen(),
      ),
      ZakatCategoryItem(
        title: 'زكاة المستغلات',
        description: 'حساب ريع العقارات المؤجرة والمصانع وسيارات الأجرة',
        imagePath: 'assets/images/fields.png',
        targetScreen: const FieldsCalcScreen(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _getAllItems().where((item) {
      return item.title.contains(_searchQuery) || item.description.contains(_searchQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبات الزكاة الشاملة'),
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن نوع الزكاة...',
                prefixIcon: const Icon(Icons.search, color: AppColors.emeraldPrimary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // Grid
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => item.targetScreen),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldSubtle,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Image.asset(item.imagePath, fit: BoxFit.contain),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.description,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
