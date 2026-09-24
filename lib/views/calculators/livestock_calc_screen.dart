import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_input_formatters.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/widgets/category_icon_badge.dart';
import '../../core/widgets/zakat_result_card.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class LivestockCalcScreen extends StatefulWidget {
  final int initialTabIndex;
  const LivestockCalcScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LivestockCalcScreen> createState() => _LivestockCalcScreenState();
}

class _LivestockCalcScreenState extends State<LivestockCalcScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _camelsFormKey = GlobalKey<FormState>();
  final _cowsFormKey = GlobalKey<FormState>();
  final _sheepFormKey = GlobalKey<FormState>();

  final _camelsController = TextEditingController();
  final _cowsController = TextEditingController();
  final _sheepController = TextEditingController();

  ZakatCalculationResult? _camelsResult;
  ZakatCalculationResult? _cowsResult;
  ZakatCalculationResult? _sheepResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _camelsController.dispose();
    _cowsController.dispose();
    _sheepController.dispose();
    super.dispose();
  }

  void _calculateCamels() {
    if (!_camelsFormKey.currentState!.validate()) return;
    final count = int.tryParse(AppInputFormatters.normalizeArabicNumbers(_camelsController.text.trim())) ?? 0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    setState(() {
      _camelsResult = zakatProv.calculateCamelsZakat(count);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم احتساب زكاة الإبل بنجاح'),
        backgroundColor: AppColors.emeraldPrimary,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _calculateCows() {
    if (!_cowsFormKey.currentState!.validate()) return;
    final count = int.tryParse(AppInputFormatters.normalizeArabicNumbers(_cowsController.text.trim())) ?? 0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    setState(() {
      _cowsResult = zakatProv.calculateCowsZakat(count);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم احتساب زكاة البقر والجاموس بنجاح'),
        backgroundColor: AppColors.emeraldPrimary,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _calculateSheep() {
    if (!_sheepFormKey.currentState!.validate()) return;
    final count = int.tryParse(AppInputFormatters.normalizeArabicNumbers(_sheepController.text.trim())) ?? 0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    setState(() {
      _sheepResult = zakatProv.calculateSheepZakat(count);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم احتساب زكاة الغنم والماعز بنجاح'),
        backgroundColor: AppColors.emeraldPrimary,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favProv = Provider.of<FavoritesProvider>(context);
    const favId = 'calc_livestock';
    final isFav = favProv.isFavorite(favId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('زكاة بهيمة الأنعام'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.goldAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: 'الإبل (الجمال)'),
            Tab(text: 'البقر والجاموس'),
            Tab(text: 'الغنم والماعز'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.redAccent : Colors.white,
            ),
            tooltip: isFav ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
            onPressed: () {
              final isNowFav = !isFav;
              favProv.toggleFavorite(
                FavoriteItem(
                  id: favId,
                  title: 'زكاة بهيمة الأنعام',
                  subtitle: 'حاسبة زكاة الإبل والبقر والغنم والماعز',
                  type: 'calculator',
                  route: '/livestock_calc',
                  imagePath: 'assets/images/camel.png',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isNowFav
                        ? 'تمت إضافة "زكاة بهيمة الأنعام" إلى المفضلة'
                        : 'تمت إزالة "زكاة بهيمة الأنعام" من المفضلة',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Camels
          SingleChildScrollView(
            padding: context.rPadding(horizontal: 16, vertical: 16),
            child: ResponsiveConstraint(
              maxWidth: 680,
              child: Form(
                key: _camelsFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CategoryIconBadge(
                            imagePath: 'assets/images/camel.png',
                            size: 60,
                            iconSize: 32,
                            padding: 8,
                            borderRadius: 14,
                            fallbackIcon: Icons.pets,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('نصاب الإبل يبدأ من 5 رؤوس',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('يشترط أن تكون سائمة ترعى أكثر الحول، وحال عليها الحول الكامل.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _camelsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [AppInputFormatters.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'عدد رؤوس الإبل المملوكة',
                      hintText: 'مثال: 25',
                      suffixText: 'رأس',
                      prefixIcon: Icon(Icons.pets, color: AppColors.emeraldPrimary),
                    ),
                    validator: AppValidators.requiredPositiveInteger('عدد رؤوس الإبل'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _calculateCamels,
                    icon: const Icon(Icons.calculate),
                    label: const Text('احسب زكاة الإبل', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 24),
                  if (_camelsResult != null)
                    ZakatResultCard(
                      result: _camelsResult!,
                      typeName: 'زكاة الإبل السائمة',
                      categoryKey: 'camel',
                      totalWealth: (int.tryParse(AppInputFormatters.normalizeArabicNumbers(_camelsController.text.trim())) ?? 0).toDouble(),
                      currency: 'رأس',
                      pdfFileName: 'zakat_camels_receipt.pdf',
                      pdfTitle: 'إقرار وتفصيل حساب زكاة الإبل',
                    ),
                ],
              ),
            ),
          ),
        ),

          // Tab 2: Cows
          SingleChildScrollView(
            padding: context.rPadding(horizontal: 16, vertical: 16),
            child: ResponsiveConstraint(
              maxWidth: 680,
              child: Form(
                key: _cowsFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CategoryIconBadge(
                            imagePath: 'assets/images/cow.png',
                            size: 60,
                            iconSize: 32,
                            padding: 8,
                            borderRadius: 14,
                            fallbackIcon: Icons.pets,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('نصاب البقر يبدأ من 30 بقرة',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('في كل 30 تبيع أو تبيعة (أتم سنة)، وفي كل 40 مسنة (أتمت سنتين).',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _cowsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [AppInputFormatters.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'عدد رؤوس البقر أو الجاموس',
                      hintText: 'مثال: 40',
                      suffixText: 'رأس',
                      prefixIcon: Icon(Icons.pets, color: AppColors.emeraldPrimary),
                    ),
                    validator: AppValidators.requiredPositiveInteger('عدد رؤوس البقر'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _calculateCows,
                    icon: const Icon(Icons.calculate),
                    label: const Text('احسب زكاة البقر', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 24),
                  if (_cowsResult != null)
                    ZakatResultCard(
                      result: _cowsResult!,
                      typeName: 'زكاة البقر والجاموس',
                      categoryKey: 'cow',
                      totalWealth: (int.tryParse(AppInputFormatters.normalizeArabicNumbers(_cowsController.text.trim())) ?? 0).toDouble(),
                      currency: 'رأس',
                      pdfFileName: 'zakat_cows_receipt.pdf',
                      pdfTitle: 'إقرار وتفصيل حساب زكاة البقر',
                    ),
                ],
              ),
            ),
          ),
        ),

          // Tab 3: Sheep
          SingleChildScrollView(
            padding: context.rPadding(horizontal: 16, vertical: 16),
            child: ResponsiveConstraint(
              maxWidth: 680,
              child: Form(
                key: _sheepFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CategoryIconBadge(
                            imagePath: 'assets/images/goat.png',
                            size: 60,
                            iconSize: 32,
                            padding: 8,
                            borderRadius: 14,
                            fallbackIcon: Icons.pets,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('نصاب الغنم يبدأ من 40 شاة',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('من 40-120 شاة واحدة، ومن 121-200 شاتان، ومن 201-300 ثلاث شياه، ثم في كل مئة شاة.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _sheepController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [AppInputFormatters.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'عدد رؤوس الضأن والماعز',
                      hintText: 'مثال: 50',
                      suffixText: 'رأس',
                      prefixIcon: Icon(Icons.pets, color: AppColors.emeraldPrimary),
                    ),
                    validator: AppValidators.requiredPositiveInteger('عدد رؤوس الغنم'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _calculateSheep,
                    icon: const Icon(Icons.calculate),
                    label: const Text('احسب زكاة الغنم', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 24),
                  if (_sheepResult != null)
                    ZakatResultCard(
                      result: _sheepResult!,
                      typeName: 'زكاة الغنم والماعز',
                      categoryKey: 'goat',
                      totalWealth: (int.tryParse(AppInputFormatters.normalizeArabicNumbers(_sheepController.text.trim())) ?? 0).toDouble(),
                      currency: 'رأس',
                      pdfFileName: 'zakat_sheep_receipt.pdf',
                      pdfTitle: 'إقرار وتفصيل حساب زكاة الغنم والماعز',
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }
}
