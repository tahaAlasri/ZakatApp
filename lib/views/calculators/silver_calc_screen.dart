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

class SilverCalcScreen extends StatefulWidget {
  const SilverCalcScreen({super.key});

  @override
  State<SilverCalcScreen> createState() => _SilverCalcScreenState();
}

class _SilverCalcScreenState extends State<SilverCalcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gramsController = TextEditingController();
  final _goldGramsController = TextEditingController();
  int _selectedGoldKarat = 21;
  bool _combineWithGold = false; // ضم الذهب لتكميل النصاب بالأجزاء
  ZakatCalculationResult? _result;
  bool _isCalculated = false;

  @override
  void dispose() {
    _gramsController.dispose();
    _goldGramsController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    final silverGrams = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_gramsController.text.trim())) ?? 0.0;
    final goldGrams = _combineWithGold
        ? (double.tryParse(AppInputFormatters.normalizeArabicNumbers(_goldGramsController.text.trim())) ?? 0.0)
        : 0.0;

    final ZakatCalculationResult res;
    if (_combineWithGold && (goldGrams > 0 || silverGrams > 0)) {
      res = zakatProv.calculateCombinedGoldSilverZakat(
        goldGrams: goldGrams,
        goldKarat: _selectedGoldKarat,
        silverGrams: silverGrams,
      );
    } else {
      res = zakatProv.calculateSilverZakat(silverGrams, pricePerGram: zakatProv.silverPrice);
    }

    setState(() {
      _result = res;
      _isCalculated = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_combineWithGold
            ? 'تم احتساب الزكاة بضم الفضة والذهب بالأجزاء وفق المعتمد الفقهي'
            : 'تم احتساب زكاة الفضة بنجاح وفق التسعيرة الرسمية'),
        backgroundColor: AppColors.emeraldPrimary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zakatProv = Provider.of<ZakatProvider>(context);
    final favProv = Provider.of<FavoritesProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        padding: context.rPadding(horizontal: 16, vertical: 16),
        child: ResponsiveConstraint(
          maxWidth: 680,
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
                              'المقدار الواجب إخراجه هو ربع العشر (2.5%) عند بلوغ النصاب وحولان الحول، والتسعيرة معتمدة من الهيئة العامة للزكاة.',
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

              // Official Silver Price Card (From Control Panel)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.blueGrey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: Colors.blueGrey, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'سعر جرام الفضة المعتمد:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${zakatProv.silverPrice.toStringAsFixed(0)} ${zakatProv.currency}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

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
                validator: (val) {
                  if (!_combineWithGold && (val == null || val.trim().isEmpty)) return 'يرجى إدخال وزن الفضة';
                  final silverVal = double.tryParse(AppInputFormatters.normalizeArabicNumbers(val ?? '')) ?? 0.0;
                  final goldVal = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_goldGramsController.text.trim())) ?? 0.0;
                  if (silverVal <= 0 && (!_combineWithGold || goldVal <= 0)) {
                    return 'يرجى إدخال وزن صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Combine Silver with Gold (ضم الذهب إلى الفضة بالأجزاء)
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _combineWithGold ? AppColors.emeraldPrimary : Colors.transparent,
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      title: const Text(
                        'ضم الذهب إلى الفضة لتكميل النصاب (بالأجزاء)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'المعتمد في فقه الهادوية والزيدية (الأزهار) وجمهور الفقهاء: إذا كان لديك فضة وذهب ولم يبلغ أحدهما نصاباً منفرداً، يُضمان بالأجزاء.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: _combineWithGold,
                      activeThumbColor: AppColors.emeraldPrimary,
                      onChanged: (val) {
                        setState(() {
                          _combineWithGold = val;
                          if (!val) _goldGramsController.clear();
                        });
                      },
                    ),
                    if (_combineWithGold) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'اختر عيار الذهب المراد ضمه:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [24, 21, 18].map((karat) {
                                final isSelected = _selectedGoldKarat == karat;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: ChoiceChip(
                                      label: Text('$karat قيراط'),
                                      selected: isSelected,
                                      selectedColor: AppColors.goldAccent,
                                      labelStyle: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.black : null,
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedGoldKarat = karat;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _goldGramsController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [AppInputFormatters.decimal],
                              decoration: InputDecoration(
                                labelText: 'وزن الذهب عيار $_selectedGoldKarat بالجرام',
                                hintText: 'مثال: 45',
                                suffixText: 'جرام ذهب',
                                prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.goldDark),
                              ),
                              validator: (val) {
                                if (!_combineWithGold) return null;
                                final silverVal = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_gramsController.text.trim())) ?? 0.0;
                                final goldVal = double.tryParse(AppInputFormatters.normalizeArabicNumbers(val ?? '')) ?? 0.0;
                                if (silverVal <= 0 && goldVal <= 0) {
                                  return 'يرجى إدخال وزن الفضة أو الذهب على الأقل';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: Text(
                  _combineWithGold ? 'احسب زكاة الفضة والذهب (المشتركة)' : 'احسب زكاة الفضة',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 24),

              // Unified Result Card
              if (_isCalculated && _result != null)
                ZakatResultCard(
                  result: _result!,
                  typeName: _combineWithGold ? 'زكاة الفضة والذهب (ضم النقدين بالأجزاء)' : 'زكاة الفضة',
                  categoryKey: _combineWithGold ? 'silver_gold_combined' : 'silver',
                  totalWealth: double.tryParse(AppInputFormatters.normalizeArabicNumbers(_gramsController.text.trim())) ?? 0.0,
                  currency: zakatProv.currency,
                  appliedPrice: zakatProv.silverPrice,
                  pdfFileName: _combineWithGold ? 'zakat_combined_silver_gold.pdf' : 'zakat_silver_receipt.pdf',
                  pdfTitle: _combineWithGold ? 'إقرار وتفصيل حساب زكاة الفضة والذهب (ضم النقدين)' : 'إقرار وتفصيل حساب زكاة الفضة',
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
