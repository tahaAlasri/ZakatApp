import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/zakat_constants.dart';
import '../../core/utils/app_input_formatters.dart';
import '../../core/widgets/category_icon_badge.dart';
import '../../core/widgets/zakat_result_card.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../core/services/cloud_sync_service.dart';

class FitrCalcScreen extends StatefulWidget {
  const FitrCalcScreen({super.key});

  @override
  State<FitrCalcScreen> createState() => _FitrCalcScreenState();
}

class _FitrCalcScreenState extends State<FitrCalcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _membersController = TextEditingController(text: '4');
  final _wheatPriceController = TextEditingController();
  final _cashPerPersonController = TextEditingController();
  
  bool _isWheatBagBased = true;
  double _bagWeightKg = 50.0;
  bool _isCashPayment = true;
  String _selectedFood = 'قمح ودقيق فاخر';
  ZakatCalculationResult? _result;
  bool _isCalculated = false;

  final List<Map<String, dynamic>> _foodTypes = [
    {'name': 'قمح ودقيق فاخر', 'saWeight': 2.5, 'icon': Icons.grain},
    {'name': 'أرز (أبيض أو مزة)', 'saWeight': 2.5, 'icon': Icons.rice_bowl},
    {'name': 'تمر من غالب قوت البلد', 'saWeight': 2.5, 'icon': Icons.nature},
    {'name': 'زبيب أو شعير', 'saWeight': 2.5, 'icon': Icons.spa},
  ];

  final List<Map<String, dynamic>> _bagSizes = [
    {'weight': 50.0, 'saCount': 20, 'label': 'كيس كبير (50 كجم = 20 صاع)'},
    {'weight': 25.0, 'saCount': 10, 'label': 'كيس وسط (25 كجم = 10 أصواع)'},
    {'weight': 40.0, 'saCount': 16, 'label': 'كيس (40 كجم = 16 صاع)'},
  ];

  @override
  void initState() {
    super.initState();
    final cloudSync = Provider.of<CloudSyncService>(context, listen: false);
    _wheatPriceController.text = cloudSync.wheatBagPriceYER.toStringAsFixed(0);
    _bagWeightKg = cloudSync.wheatBagWeightKg;
    _syncCashFromWheat();
  }

  @override
  void dispose() {
    _membersController.dispose();
    _wheatPriceController.dispose();
    _cashPerPersonController.dispose();
    super.dispose();
  }

  void _syncCashFromWheat() {
    final price = AppInputFormatters.tryParseDouble(_wheatPriceController.text) ?? ZakatConstants.defaultWheatBagPriceYER;
    final saCount = _bagWeightKg / ZakatConstants.fitrSaWeightKg;
    final perPerson = saCount > 0 ? (price / saCount) : ZakatConstants.defaultFitrCashYER;
    _cashPerPersonController.text = perPerson.toStringAsFixed(0);
  }

  void _updateMembers(int delta) {
    int current = AppInputFormatters.tryParseInt(_membersController.text) ?? 1;
    current = (current + delta).clamp(1, 100);
    _membersController.text = current.toString();
    if (_isCalculated) _calculate();
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('يرجى التحقق من صحة البيانات المدخلة')),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final members = AppInputFormatters.tryParseInt(_membersController.text) ?? 0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    ZakatCalculationResult res;
    if (_isCashPayment && _isWheatBagBased) {
      final bagPrice = AppInputFormatters.tryParseDouble(_wheatPriceController.text) ?? ZakatConstants.defaultWheatBagPriceYER;
      res = zakatProv.calculateFitrZakat(
        familyMembers: members,
        wheatBagPrice: bagPrice,
        bagWeightKg: _bagWeightKg,
        isCashPayment: true,
      );
    } else {
      final cashVal = AppInputFormatters.tryParseDouble(_cashPerPersonController.text) ?? ZakatConstants.defaultFitrCashYER;
      res = zakatProv.calculateFitrZakat(
        familyMembers: members,
        cashValuePerPerson: cashVal,
        bagWeightKg: _bagWeightKg,
        isCashPayment: _isCashPayment,
      );
    }

    setState(() {
      _result = res;
      _isCalculated = true;
    });

    final msg = _isCashPayment
        ? 'تم الحساب بنجاح: الواجب ${res.zakatDue.toStringAsFixed(0)} ${zakatProv.currency} عن $members أفراد'
        : 'تم الحساب بنجاح: الواجب ${(members * ZakatConstants.fitrSaWeightKg).toStringAsFixed(1)} كجم ($members صاع) طعام';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: AppColors.emeraldPrimary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zakatProv = Provider.of<ZakatProvider>(context);
    final favProv = Provider.of<FavoritesProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const favId = 'calc_fitr';
    final isFav = favProv.isFavorite(favId);

    final members = AppInputFormatters.tryParseInt(_membersController.text) ?? 1;
    final saCountInBag = (_bagWeightKg / ZakatConstants.fitrSaWeightKg).round();
    final wheatPrice = AppInputFormatters.tryParseDouble(_wheatPriceController.text) ?? 0;
    final perPersonCash = saCountInBag > 0 ? (wheatPrice / saCountInBag).round() : 0;
    final totalCashEstimate = members * perPersonCash;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة زكاة الفطر'),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.redAccent : Colors.white,
            ),
            tooltip: isFav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
            onPressed: () {
              favProv.toggleFavorite(
                FavoriteItem(
                  id: favId,
                  title: 'حاسبة زكاة الفطر',
                  subtitle: 'حساب زكاة الفطر عن أفراد الأسرة',
                  type: 'calculator',
                  route: '/fitr_calc',
                  imagePath: 'assets/images/fitr.png',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isFav
                        ? 'تمت الإزالة من حاسباتي المفضلة'
                        : 'تمت الإضافة إلى حاسباتي المفضلة بنجاح',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: isFav ? Colors.black87 : AppColors.emeraldPrimary,
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
              // Sharia Context Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CategoryIconBadge(
                        imagePath: 'assets/images/fitr.png',
                        size: 60,
                        iconSize: 32,
                        padding: 8,
                        borderRadius: 14,
                        fallbackIcon: Icons.volunteer_activism,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'زكاة الفطر (طهرة للصائم وطعمة للمساكين)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'فريضة على كل مسلم قادر عن نفسه وعمّن تلزمه نفقتهم. مقدارها صاع نبوي (≈ 2.5 كجم قمح) عن الفرد الواحد، وتُحسب قيمتها نقداً بتقسيم سعر كيس القمح على عدد الأصواع.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Family Members Counter Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.people_outline, color: AppColors.emeraldPrimary, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'عدد أفراد الأسرة (النفس ومن تعولهم)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filled(
                            onPressed: () => _updateMembers(-1),
                            icon: const Icon(Icons.remove),
                            style: IconButton.styleFrom(
                              backgroundColor: isDark ? AppColors.emeraldDark : AppColors.emeraldSubtle,
                              foregroundColor: isDark ? Colors.white : AppColors.emeraldPrimary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 90,
                            child: TextFormField(
                              controller: _membersController,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [AppInputFormatters.digitsOnly],
                              validator: AppValidators.requiredPositiveInteger('عدد الأفراد'),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                if (_isCalculated) _calculate();
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton.filled(
                            onPressed: () => _updateMembers(1),
                            icon: const Icon(Icons.add),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.emeraldPrimary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    // Quick chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [1, 2, 4, 6, 8, 10].map((count) {
                        final isSelected = _membersController.text == count.toString();
                        return ChoiceChip(
                          label: Text('$count أفراد'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _membersController.text = count.toString();
                              });
                              if (_isCalculated) _calculate();
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment method selector (Cash vs In-Kind Food)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'طريقة إخراج الزكاة:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() => _isCashPayment = true);
                              if (_isCalculated) _calculate();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _isCashPayment
                                    ? AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.28 : 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isCashPayment ? AppColors.emeraldPrimary : Colors.grey.shade300,
                                  width: _isCashPayment ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.payments_outlined,
                                    color: _isCashPayment ? AppColors.emeraldPrimary : Colors.grey,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'نقداً (بالمال)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _isCashPayment ? AppColors.emeraldPrimary : null,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Text('قيمة الصاع مالاً', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() => _isCashPayment = false);
                              if (_isCalculated) _calculate();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: !_isCashPayment
                                    ? AppColors.goldAccent.withValues(alpha: isDark ? 0.28 : 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !_isCashPayment ? AppColors.goldAccent : Colors.grey.shade300,
                                  width: !_isCashPayment ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.grain,
                                    color: !_isCashPayment ? AppColors.goldDark : Colors.grey,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'عيناً (طعام وقوت)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: !_isCashPayment ? AppColors.goldDark : null,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Text('صاع حبوب/أرز', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_isCashPayment) ...[
                      // Pricing Mode Selector (Wheat Bag vs Direct Manual)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isWheatBagBased = true;
                                    _syncCashFromWheat();
                                  });
                                  if (_isCalculated) _calculate();
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isWheatBagBased
                                        ? (isDark ? AppColors.emeraldDark : AppColors.emeraldPrimary)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'بحسب كيس القمح (المعتمد)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _isWheatBagBased ? Colors.white : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() => _isWheatBagBased = false);
                                  if (_isCalculated) _calculate();
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !_isWheatBagBased
                                        ? (isDark ? AppColors.emeraldDark : AppColors.emeraldPrimary)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'إدخال قيمة الصاع يدوياً',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: !_isWheatBagBased ? Colors.white : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_isWheatBagBased) ...[
                        TextFormField(
                          controller: _wheatPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [AppInputFormatters.decimal],
                          validator: (val) {
                            if (!_isCashPayment || !_isWheatBagBased) return null;
                            return AppValidators.requiredPositiveNumber('سعر كيس القمح')(val);
                          },
                          decoration: InputDecoration(
                            labelText: 'سعر كيس القمح بالسوق',
                            suffixText: zakatProv.currency,
                            prefixIcon: const Icon(Icons.shopping_bag_outlined, color: AppColors.emeraldPrimary),
                            helperText: 'السعر السائد لكيس القمح أو الدقيق في منطقتك',
                          ),
                          onChanged: (_) {
                            _syncCashFromWheat();
                            if (_isCalculated) _calculate();
                          },
                        ),
                        const SizedBox(height: 14),

                        // Bag Weight selector
                        const Text(
                          'وزن كيس القمح وسعته بالأصواع:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _bagSizes.map((bag) {
                            final w = bag['weight'] as double;
                            final isSelected = _bagWeightKg == w;
                            return ChoiceChip(
                              label: Text(bag['label'] as String),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _bagWeightKg = w;
                                    _syncCashFromWheat();
                                  });
                                  if (_isCalculated) _calculate();
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Live Wheat Bag Metrics Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.emeraldSubtle.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.emeraldPrimary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('وزن الصاع النبوي الشرعي:', style: TextStyle(fontSize: 12)),
                                  Text('${ZakatConstants.fitrSaWeightKg} كجم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('كم يحتوي الكيس على صاع:', style: TextStyle(fontSize: 12)),
                                  Text(
                                    '$saCountInBag صاع نبوي (${_bagWeightKg.toStringAsFixed(0)} ÷ ${ZakatConstants.fitrSaWeightKg})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.emeraldPrimary, fontSize: 12),
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('قيمة الصاع للفرد الواحد:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(
                                    '$perPersonCash ${zakatProv.currency}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.emeraldPrimary, fontSize: 15),
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('إجمالي الواجب عن $members أفراد:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(
                                    '$totalCashEstimate ${zakatProv.currency}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.emeraldDark, fontSize: 15),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _cashPerPersonController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [AppInputFormatters.decimal],
                          validator: (val) {
                            if (!_isCashPayment || _isWheatBagBased) return null;
                            return AppValidators.requiredPositiveNumber('قيمة صاع الفطرة نقداً')(val);
                          },
                          decoration: InputDecoration(
                            labelText: 'قيمة صاع الفطرة نقداً للفرد الواحد',
                            suffixText: zakatProv.currency,
                            prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.emeraldPrimary),
                            helperText: 'تقديري وفق دار الإفتاء أو غالب سعر 2.5 كجم أرز/قمح',
                          ),
                          onChanged: (_) {
                            if (_isCalculated) _calculate();
                          },
                        ),
                      ],
                    ] else ...[
                      DropdownButtonFormField<String>(
                        value: _selectedFood,
                        decoration: const InputDecoration(
                          labelText: 'نوع قوت البلد المخرج منه',
                          prefixIcon: Icon(Icons.shopping_basket_outlined, color: AppColors.goldDark),
                        ),
                        items: _foodTypes.map((food) {
                          return DropdownMenuItem<String>(
                            value: food['name'] as String,
                            child: Row(
                              children: [
                                Icon(food['icon'] as IconData, size: 18, color: AppColors.goldDark),
                                const SizedBox(width: 8),
                                Text(food['name'] as String),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedFood = val);
                            if (_isCalculated) _calculate();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.goldLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.goldAccent.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('الواجب عن كل فرد:', style: TextStyle(fontSize: 12)),
                                Text('صاع نبوي (≈ ${ZakatConstants.fitrSaWeightKg} كجم)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('إجمالي الواجب عن $members أفراد:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  '${(members * ZakatConstants.fitrSaWeightKg).toStringAsFixed(1)} كجم ($members أصواع)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.goldDark, fontSize: 14),
                                ),
                              ],
                            ),
                            if (_bagWeightKg > 0) ...[
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('ما يعادل من أكياس القمح:', style: TextStyle(fontSize: 12)),
                                  Text(
                                    '${((members * ZakatConstants.fitrSaWeightKg) / _bagWeightKg).toStringAsFixed(2)} كيس (50 كجم)',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('احسب زكاة الفطر', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 24),

            if (_isCalculated && _result != null)
              ZakatResultCard(
                result: _result!,
                typeName: 'زكاة الفطر',
                categoryKey: 'fitr',
                totalWealth: (int.tryParse(_membersController.text.trim()) ?? 1).toDouble(),
                currency: zakatProv.currency,
                pdfFileName: 'zakat_fitr_receipt.pdf',
                pdfTitle: 'إقرار وتفصيل حساب زكاة الفطر',
              ),
          ],
        ),
      ),
    ),
  );
}
}

