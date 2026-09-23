import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_input_formatters.dart';
import '../../core/widgets/category_icon_badge.dart';
import '../../core/widgets/price_transparency_card.dart';
import '../../core/widgets/zakat_result_card.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class GoldCalcScreen extends StatefulWidget {
  const GoldCalcScreen({super.key});

  @override
  State<GoldCalcScreen> createState() => _GoldCalcScreenState();
}

class _GoldCalcScreenState extends State<GoldCalcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gramsController = TextEditingController();
  final _silverGramsController = TextEditingController();
  int _selectedKarat = 21;
  bool _isPersonalJewelry = false;
  bool _madhhabRequiresZakat = true; // المعتمد في فقه الزيدية والهادوية (متن الأزهار)
  bool _combineWithSilver = false; // ضم الفضة لتكميل النصاب بالأجزاء
  ZakatCalculationResult? _result;
  bool _isCalculated = false;
  bool _isPriceConfirmed = false;

  double _getPriceForKarat(int karat, ZakatProvider prov) {
    return switch (karat) {
      24 => prov.gold24Price,
      21 => prov.gold21Price,
      18 => prov.gold18Price,
      _ => prov.gold21Price,
    };
  }

  @override
  void initState() {
    super.initState();
    _gramsController.addListener(() {
      if (_isPriceConfirmed) {
        setState(() => _isPriceConfirmed = false);
      } else {
        setState(() {});
      }
    });
    _silverGramsController.addListener(() {
      if (_isPriceConfirmed) {
        setState(() => _isPriceConfirmed = false);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _gramsController.dispose();
    _silverGramsController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    final goldGrams = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_gramsController.text.trim())) ?? 0.0;
    final silverGrams = _combineWithSilver
        ? (double.tryParse(AppInputFormatters.normalizeArabicNumbers(_silverGramsController.text.trim())) ?? 0.0)
        : 0.0;
    final price = _getPriceForKarat(_selectedKarat, zakatProv);

    final ZakatCalculationResult res;
    if (_combineWithSilver && (silverGrams > 0 || goldGrams > 0)) {
      res = zakatProv.calculateCombinedGoldSilverZakat(
        goldGrams: goldGrams,
        goldKarat: _selectedKarat,
        silverGrams: silverGrams,
      );
    } else {
      res = zakatProv.calculateGoldZakat(
        grams: goldGrams,
        karat: _selectedKarat,
        pricePerGram: price,
        isPersonalJewelry: _isPersonalJewelry,
        madhhabRequiresZakat: _madhhabRequiresZakat,
      );
    }

    setState(() {
      _result = res;
      _isCalculated = true;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_combineWithSilver
            ? 'تم احتساب الزكاة بضم الذهب والفضة بالأجزاء وفق المعتمد الفقهي'
            : 'تم احتساب زكاة الذهب بنجاح وفق التسعيرة الرسمية'),
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
    const favId = 'calc_gold';
    final isFav = favProv.isFavorite(favId);

    final currentKaratPrice = _getPriceForKarat(_selectedKarat, zakatProv);
    final enteredGrams = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_gramsController.text.trim())) ?? 0.0;
    final pureGrams = enteredGrams * (_selectedKarat / 24.0);
    final isNearNisab = enteredGrams > 0 && zakatProv.isCloseToNisab(pureGrams, 85.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة زكاة الذهب'),
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
                  title: 'حاسبة زكاة الذهب',
                  subtitle: 'حساب زكاة الذهب والسبائك والحلي',
                  type: 'calculator',
                  route: '/gold_calc',
                  imagePath: 'assets/images/gold.png',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isNowFav
                        ? 'تمت إضافة "حاسبة زكاة الذهب" إلى المفضلة'
                        : 'تمت إزالة "حاسبة زكاة الذهب" من المفضلة',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CategoryIconBadge(
                        imagePath: 'assets/images/gold.png',
                        size: 60,
                        iconSize: 32,
                        padding: 8,
                        borderRadius: 14,
                        fallbackIcon: Icons.monetization_on_outlined,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'نصاب الذهب 85 جراماً خالصاً',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'المقدار الواجب إخراجه هو ربع العشر (2.5%) عند بلوغ النصاب وحولان الحول، وتعتمد الأسعار آلياً من لوحة تحكم الهيئة العامة للزكاة.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'اختر عيار الذهب:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),

              Row(
                children: [24, 21, 18].map((karat) {
                  final isSelected = _selectedKarat == karat;
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
                              _selectedKarat = karat;
                            });
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Official Price Display Card (From Control Panel)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.goldLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.goldAccent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, color: AppColors.goldDark, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'سعر جرام الذهب عيار $_selectedKarat المعتمد:',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    Text(
                      '${currentKaratPrice.toStringAsFixed(0)} ${zakatProv.currency}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.goldDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Weight in grams
              TextFormField(
                controller: _gramsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: 'وزن الذهب عيار $_selectedKarat بالجرام',
                  hintText: 'مثال: 120',
                  suffixText: 'جرام',
                  prefixIcon: const Icon(Icons.scale_outlined, color: AppColors.goldDark),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'يرجى إدخال وزن الذهب';
                  final v = double.tryParse(AppInputFormatters.normalizeArabicNumbers(val.trim()));
                  if (v == null || v <= 0) return 'يرجى إدخال قيمة أكبر من الصفر';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Personal Jewelry Ruling
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _isPersonalJewelry ? AppColors.goldAccent : Colors.transparent,
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      title: const Text(
                        'ذهب زينة واستعمال شخصي للمرأة (حلي مباح)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'معتمد فقه الهادوية والزيدية في الأزهار: تجب الزكاة في حلي النساء ولو كان مباحاً للزينة إذا بلغ النصاب.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: _isPersonalJewelry,
                      activeThumbColor: AppColors.goldAccent,
                      onChanged: (val) {
                        setState(() {
                          _isPersonalJewelry = val;
                        });
                      },
                    ),
                    if (_isPersonalJewelry) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: DropdownButtonFormField<bool>(
                          value: _madhhabRequiresZakat,
                          isExpanded: true,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'المعتمد الفقهي لحلي الزينة الشخصية:',
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: true,
                              child: Text(
                                'معتمد الهادوية والزيدية (الأزهار) والحنفية: تجب الزكاة',
                                style: TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            DropdownMenuItem(
                              value: false,
                              child: Text(
                                'مذهب الجمهور (الشافعية والمالكية والحنابلة): معفى من الزكاة',
                                style: TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _madhhabRequiresZakat = val);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Combine Gold with Silver (ضم الذهب إلى الفضة بالأجزاء)
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _combineWithSilver ? AppColors.goldAccent : Colors.transparent,
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      title: const Text(
                        'ضم الفضة إلى الذهب لتكميل النصاب (بالأجزاء)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'المعتمد في فقه الهادوية والزيدية (الأزهار) وجمهور الفقهاء: إذا كان لديك ذهب وفضة ولم يبلغ أحدهما نصاباً منفرداً، يُضمان بالأجزاء.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: _combineWithSilver,
                      activeThumbColor: AppColors.goldAccent,
                      onChanged: (val) {
                        setState(() {
                          _combineWithSilver = val;
                          if (!val) _silverGramsController.clear();
                        });
                      },
                    ),
                    if (_combineWithSilver) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'سعر جرام الفضة المعتمد: ${zakatProv.silverPrice.toStringAsFixed(0)} ${zakatProv.currency}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                ),
                                const Text(
                                  'نصاب الفضة: 595 جم',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _silverGramsController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [AppInputFormatters.decimal],
                              decoration: const InputDecoration(
                                labelText: 'وزن الفضة المراد ضمها بالجرام',
                                hintText: 'مثال: 300',
                                suffixText: 'جرام فضة',
                                prefixIcon: Icon(Icons.circle_outlined, color: Colors.blueGrey),
                              ),
                              validator: (val) {
                                if (!_combineWithSilver) return null;
                                final goldVal = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_gramsController.text.trim())) ?? 0.0;
                                final silverVal = double.tryParse(AppInputFormatters.normalizeArabicNumbers(val ?? '')) ?? 0.0;
                                if (goldVal <= 0 && silverVal <= 0) {
                                  return 'يرجى إدخال وزن الذهب أو الفضة على الأقل';
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
              const SizedBox(height: 16),

              PriceTransparencyCard(
                snapshot: zakatProv.currentPriceSnapshot,
                isNearNisab: isNearNisab,
                isPriceConfirmed: _isPriceConfirmed,
                onConfirmPrice: () {
                  setState(() => _isPriceConfirmed = true);
                  _calculate();
                },
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: Text(
                  _combineWithSilver ? 'احسب زكاة الذهب والفضة (المشتركة)' : 'احسب زكاة الذهب',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 24),

              // Unified Result Card
              if (_isCalculated && _result != null)
                ZakatResultCard(
                  result: _result!,
                  typeName: _combineWithSilver ? 'زكاة الذهب والفضة (ضم النقدين بالأجزاء)' : 'زكاة الذهب (عيار $_selectedKarat)',
                  categoryKey: _combineWithSilver ? 'gold_silver_combined' : 'gold',
                  totalWealth: double.tryParse(AppInputFormatters.normalizeArabicNumbers(_gramsController.text.trim())) ?? 0.0,
                  currency: zakatProv.currency,
                  appliedPrice: currentKaratPrice,
                  goldKarat: _selectedKarat,
                  pdfFileName: _combineWithSilver ? 'zakat_combined_gold_silver.pdf' : 'zakat_gold_receipt.pdf',
                  pdfTitle: _combineWithSilver ? 'إقرار وتفصيل حساب زكاة الذهب والفضة (ضم النقدين)' : 'إقرار وتفصيل حساب زكاة الذهب',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
