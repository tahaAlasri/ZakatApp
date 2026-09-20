import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_input_formatters.dart';
import '../../core/widgets/category_icon_badge.dart';
import '../../core/widgets/zakat_result_card.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class SilverCalcScreen extends StatefulWidget {
  const SilverCalcScreen({super.key});

  @override
  State<SilverCalcScreen> createState() => _SilverCalcScreenState();
}

class _SilverCalcScreenState extends State<SilverCalcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gramsController = TextEditingController();
  final _priceController = TextEditingController();
  ZakatCalculationResult? _result;
  bool _isCalculated = false;

  @override
  void initState() {
    super.initState();
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    _priceController.text = zakatProv.silverPrice.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _gramsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final grams = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_gramsController.text.trim())) ?? 0.0;
    final price = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_priceController.text.trim())) ?? 0.0;

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    final res = zakatProv.calculateSilverZakat(grams, pricePerGram: price);

    setState(() {
      _result = res;
      _isCalculated = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم احتساب زكاة الفضة بنجاح'),
        backgroundColor: AppColors.emeraldPrimary,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zakatProv = Provider.of<ZakatProvider>(context);
    final favProv = Provider.of<FavoritesProvider>(context);
    const favId = 'calc_silver';
    final isFav = favProv.isFavorite(favId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة زكاة الفضة'),
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
                  title: 'حاسبة زكاة الفضة',
                  subtitle: 'حساب زكاة الفضة والسبائك',
                  type: 'calculator',
                  route: '/silver_calc',
                  imagePath: 'assets/images/silver.png',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isNowFav
                        ? 'تمت إضافة "حاسبة زكاة الفضة" إلى المفضلة'
                        : 'تمت إزالة "حاسبة زكاة الفضة" من المفضلة',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CategoryIconBadge(
                        imagePath: 'assets/images/silver.png',
                        size: 60,
                        iconSize: 32,
                        padding: 8,
                        borderRadius: 14,
                        fallbackIcon: Icons.circle_outlined,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'نصاب الفضة 595 جراماً',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'المقدار الواجب إخراجه هو ربع العشر (2.5%) عند بلوغ النصاب وحولان الحول.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _gramsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: const InputDecoration(
                  labelText: 'إجمالي وزن الفضة بالجرام',
                  hintText: 'مثال: 650',
                  suffixText: 'جرام',
                  prefixIcon: Icon(Icons.scale_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.requiredPositiveNumber('وزن الفضة بالجرام'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: 'سعر جرام الفضة اليوم',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.requiredPositiveNumber('سعر جرام الفضة'),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: const Text('احسب زكاة الفضة', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 24),

              // Unified Result Card
              if (_isCalculated && _result != null)
                ZakatResultCard(
                  result: _result!,
                  typeName: 'زكاة الفضة',
                  categoryKey: 'silver',
                  totalWealth: double.tryParse(AppInputFormatters.normalizeArabicNumbers(_gramsController.text.trim())) ?? 0.0,
                  currency: zakatProv.currency,
                  pdfFileName: 'zakat_silver_receipt.pdf',
                  pdfTitle: 'إقرار وتفصيل حساب زكاة الفضة',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
