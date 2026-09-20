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
  final _priceController = TextEditingController();
  int _selectedKarat = 21;
  bool _isPersonalJewelry = false;
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
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    _priceController.text = _getPriceForKarat(_selectedKarat, zakatProv).toStringAsFixed(0);
    _gramsController.addListener(_onInputChanged);
    _priceController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (_isPriceConfirmed) {
      setState(() => _isPriceConfirmed = false);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _gramsController.removeListener(_onInputChanged);
    _priceController.removeListener(_onInputChanged);
    _gramsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;

    final grams = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_gramsController.text.trim())) ?? 0.0;
    final price = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_priceController.text.trim())) ?? 0.0;

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    final pureGrams = grams * (_selectedKarat / 24.0);
    final isNear = zakatProv.isCloseToNisab(pureGrams, 85.0);

    if (isNear && !_isPriceConfirmed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('تأكيد سعر النصاب'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الوزن الخالص المعادل (${pureGrams.toStringAsFixed(2)} جرام) قريب جداً من حد النصاب الشرعي (85 جرام ذهب خالص).'),
              const SizedBox(height: 8),
              Text('المصدر: ${zakatProv.currentPriceSnapshot.source}'),
              const SizedBox(height: 8),
              const Text('نظراً لحساسية النصاب وتقييم الزكاة، يرجى تأكيد مطابقة سعر السوق اليوم لاعتماد الحساب بدقة.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('مراجعة السعر'),
            ),
            ElevatedButton(
              key: const Key('btn_confirm_gold_price_near_nisab_dialog'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد السعر والمتابعة'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      setState(() {
        _isPriceConfirmed = true;
      });
    }

    final res = zakatProv.calculateGoldZakat(
      grams: grams,
      karat: _selectedKarat,
      pricePerGram: price,
      isPersonalJewelry: _isPersonalJewelry,
    );

    setState(() {
      _result = res;
      _isCalculated = true;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم احتساب زكاة الذهب بنجاح'),
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
    const favId = 'calc_gold';
    final isFav = favProv.isFavorite(favId);

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
                  subtitle: 'حساب زكاة الذهب بمختلف العيارات',
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
                    children: [
                      const CategoryIconBadge(
                        imagePath: 'assets/images/gold.png',
                        size: 60,
                        iconSize: 32,
                        padding: 8,
                        borderRadius: 14,
                        fallbackIcon: Icons.monetization_on,
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
                              'يحسب المقدار بنسبة 2.5% بعد تحويل وزن الذهب إلى المعيار الخالص (عيار 24).',
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

              // Karat Choice Chips
              const Text(
                'اختر عيار الذهب:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                              _priceController.text = _getPriceForKarat(karat, zakatProv).toStringAsFixed(0);
                            });
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
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
                validator: AppValidators.requiredPositiveNumber('وزن الذهب بالجرام'),
              ),
              const SizedBox(height: 16),

              // Price per gram
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: 'سعر جرام الذهب عيار $_selectedKarat اليوم',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.requiredPositiveNumber('سعر جرام الذهب'),
              ),
              const SizedBox(height: 16),

              // Personal Jewelry Exemption Switch
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _isPersonalJewelry ? AppColors.goldAccent : Colors.transparent,
                  ),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  title: const Text(
                    'ذهب زينة واستعمال شخصي مباح للمرأة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'جمهور الفقهاء (المالكية والشافعية والحنابلة) على عدم وجوب الزكاة في حلي الزينة الشخصية المعتادة.',
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
                label: const Text('احسب زكاة الذهب', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 24),

              // Unified Result Card
              if (_isCalculated && _result != null)
                ZakatResultCard(
                  result: _result!,
                  typeName: 'زكاة الذهب (عيار $_selectedKarat)',
                  categoryKey: 'gold',
                  totalWealth: double.tryParse(AppInputFormatters.normalizeArabicNumbers(_gramsController.text.trim())) ?? 0.0,
                  currency: zakatProv.currency,
                  appliedPrice: double.tryParse(AppInputFormatters.normalizeArabicNumbers(_priceController.text.trim())),
                  goldKarat: _selectedKarat,
                  pdfFileName: 'zakat_gold_receipt.pdf',
                  pdfTitle: 'إقرار وتفصيل حساب زكاة الذهب',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
