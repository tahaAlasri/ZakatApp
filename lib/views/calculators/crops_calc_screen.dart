import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_input_formatters.dart';
import '../../core/widgets/category_icon_badge.dart';
import '../../core/widgets/zakat_result_card.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class CropsCalcScreen extends StatefulWidget {
  const CropsCalcScreen({super.key});

  @override
  State<CropsCalcScreen> createState() => _CropsCalcScreenState();
}

class _CropsCalcScreenState extends State<CropsCalcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _weightController = TextEditingController();
  String _irrigationType = 'natural'; // natural, artificial, mixed
  ZakatCalculationResult? _result;
  bool _isCalculated = false;

  @override
  void dispose() {
    _amountController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final amountText = _amountController.text.trim();
    final amount = amountText.isNotEmpty
        ? AppInputFormatters.tryParseDouble(AppInputFormatters.normalizeArabicNumbers(amountText))
        : null;
    final weight = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_weightController.text.trim())) ?? 0.0;

    if (weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إدخال وزن المحصول بالكيلوجرام (أكبر من الصفر)'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final res = zakatProv.calculateCropsZakat(
      totalCropValue: amount,
      irrigationType: _irrigationType,
      weightInKg: weight,
    );

    setState(() {
      _result = res;
      _isCalculated = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res.reachedNisab
              ? 'تم احتساب زكاة الزروع والثمار بنجاح'
              : 'لم يكتمل النصاب الشرعي للزروع والثمار (612 كجم)',
        ),
        backgroundColor: res.reachedNisab ? AppColors.emeraldPrimary : Colors.orange.shade800,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zakatProv = Provider.of<ZakatProvider>(context);
    final favProv = Provider.of<FavoritesProvider>(context);
    const favId = 'calc_crops';
    final isFav = favProv.isFavorite(favId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة الحبوب والثمار'),
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
                  title: 'حاسبة الحبوب والثمار',
                  subtitle: 'حساب زكاة الزروع والمحاصيل الزراعية',
                  type: 'calculator',
                  route: '/crops_calc',
                  imagePath: 'assets/images/crops.png',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isNowFav
                        ? 'تمت إضافة "حاسبة الحبوب والثمار" إلى المفضلة'
                        : 'تمت إزالة "حاسبة الحبوب والثمار" من المفضلة',
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
                        imagePath: 'assets/images/crops.png',
                        size: 60,
                        iconSize: 32,
                        padding: 8,
                        borderRadius: 14,
                        fallbackIcon: Icons.grass_outlined,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'زكاة الحبوب والمحاصيل الثمرية',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'تجب الزكاة يوم الحصاد؛ 10% فيما سقي بماء المطر أو العيون، و 5% فيما سقي بالآلات والري المكلف، و 7.5% للمشترك.',
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

              // Irrigation Radio Selection
              const Text(
                'طريقة سقي المحصول:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('سقي طبيعي (أمطار / عيون / سيح)'),
                      subtitle: const Text('المقدار الواجب: العشر كامل (10%)'),
                      value: 'natural',
                      groupValue: _irrigationType,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (val) {
                        if (val != null) setState(() => _irrigationType = val);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      title: const Text('سقي اصطناعي مكلف (مضخات / آبار / نواضح)'),
                      subtitle: const Text('المقدار الواجب: نصف العشر (5%)'),
                      value: 'artificial',
                      groupValue: _irrigationType,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (val) {
                        if (val != null) setState(() => _irrigationType = val);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      title: const Text('سقي مشترك (طبيعي ومكلف مناصفة)'),
                      subtitle: const Text('المقدار الواجب: ثلاثة أرباع العشر (7.5%)'),
                      value: 'mixed',
                      groupValue: _irrigationType,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (val) {
                        if (val != null) setState(() => _irrigationType = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Weight input for Nisab verification (Required)
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: const InputDecoration(
                  labelText: 'وزن المحصول بالكيلوجرام (إلزامي - النصاب 612 كجم)',
                  hintText: 'مثال: 1000',
                  suffixText: 'كجم',
                  prefixIcon: Icon(Icons.scale_outlined, color: AppColors.goldDark),
                ),
                validator: AppValidators.requiredPositiveNumber('وزن المحصول بالكيلوجرام'),
              ),
              const SizedBox(height: 16),

              // Crop monetary value (Optional)
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: 'القيمة المالية التقديرية (اختياري - للتقويم النقدي)',
                  hintText: 'اتركه فارغاً للاحتساب عيناً بالكيلوجرام فقط',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return null; // اختياري
                  final parsed = AppInputFormatters.tryParseDouble(AppInputFormatters.normalizeArabicNumbers(val.trim()));
                  if (parsed == null || parsed < 0) {
                    return 'يرجى إدخال مبلغ صحيح أو ترك الحقل فارغاً';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: const Text('احسب زكاة الزروع', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 24),

              // Unified Result Card
              if (_isCalculated && _result != null)
                ZakatResultCard(
                  result: _result!,
                  typeName: 'زكاة الزروع والثمار',
                  categoryKey: 'crops',
                  totalWealth: double.tryParse(AppInputFormatters.normalizeArabicNumbers(_amountController.text.trim())) ?? 0.0,
                  currency: zakatProv.currency,
                  pdfFileName: 'zakat_crops_receipt.pdf',
                  pdfTitle: 'إقرار وتفصيل حساب زكاة الحبوب والثمار',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
