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
import '../../core/services/cloud_sync_service.dart';

class FitrCalcScreen extends StatefulWidget {
  const FitrCalcScreen({super.key});

  @override
  State<FitrCalcScreen> createState() => _FitrCalcScreenState();
}

class _FitrCalcScreenState extends State<FitrCalcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _membersController = TextEditingController(text: '4');
  
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

  @override
  void dispose() {
    _membersController.dispose();
    super.dispose();
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
    final cloudSync = Provider.of<CloudSyncService>(context, listen: false);
    
    final selectedFoodData = _foodTypes.firstWhere((f) => f['name'] == _selectedFood);
    final currentSaWeight = selectedFoodData['saWeight'] as double;

    ZakatCalculationResult res;
    if (_isCashPayment) {
      res = zakatProv.calculateFitrZakat(
        familyMembers: members,
        stapleBagPrice: cloudSync.wheatBagPriceYER,
        bagWeightKg: cloudSync.wheatBagWeightKg,
        cashValuePerPerson: cloudSync.fitrCashYER,
        isCashPayment: true,
        stapleName: _selectedFood,
        saWeightKg: currentSaWeight,
      );
    } else {
      res = zakatProv.calculateFitrZakat(
        familyMembers: members,
        bagWeightKg: cloudSync.wheatBagWeightKg,
        isCashPayment: false,
        stapleName: _selectedFood,
        saWeightKg: currentSaWeight,
      );
    }

    setState(() {
      _result = res;
      _isCalculated = true;
    });

    final msg = _isCashPayment
        ? 'تم الحساب بنجاح: الواجب ${res.zakatDue.toStringAsFixed(0)} ${zakatProv.currency} عن $members أفراد'
        : 'تم الحساب بنجاح: الواجب ${(members * currentSaWeight).toStringAsFixed(1)} كجم ($members صاع) من $_selectedFood';

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
    final cloudSync = Provider.of<CloudSyncService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const favId = 'calc_fitr';
    final isFav = favProv.isFavorite(favId);

    final members = AppInputFormatters.tryParseInt(_membersController.text) ?? 1;
    final saCount = cloudSync.wheatBagWeightKg > 0 ? (cloudSync.wheatBagWeightKg / 2.5) : 20.0;
    final officialPerPersonCash = cloudSync.fitrCashYER > 0
        ? cloudSync.fitrCashYER
        : (saCount > 0 ? (cloudSync.wheatBagPriceYER / saCount) : 1200.0);
    final totalCashEstimate = (members * officialPerPersonCash).round();

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
        padding: context.rPadding(horizontal: 16, vertical: 16),
        child: ResponsiveConstraint(
          maxWidth: 680,
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
                              'فريضة على كل مسلم قادر عن نفسه وعمّن تلزمه نفقتهم. مقدارها صاع نبوي (≈ 2.5 كجم) عن الفرد الواحد، وتعتمد قيمتها على التسعيرة الرسمية المعتمدة من الهيئة العامة للزكاة.',
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
                    children: [
                      const Text(
                        'عدد أفراد الأسرة المكلف بالإنفاق عليهم:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 14),
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
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'مطلوب';
                                final num = int.tryParse(val.trim());
                                if (num == null || num <= 0) return 'أدخل عدداً صحيحاً';
                                return null;
                              },
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
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'نقداً (بالمال)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _isCashPayment ? AppColors.emeraldPrimary : null,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('قيمة الصاع مالاً', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    ),
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
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'عيناً (طعام وقوت)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: !_isCashPayment ? AppColors.goldDark : null,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('صاع حبوب/أرز', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_isCashPayment) ...[
                        // Official Zakat Authority Fitr Price Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.emeraldSubtle.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.emeraldPrimary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified, color: AppColors.emeraldPrimary, size: 18),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      'التسعيرة الرسمية المعتمدة',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'هيئة الزكاة',
                                      style: TextStyle(fontSize: 10, color: AppColors.emeraldPrimary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'قيمة زكاة الفطرة للفرد:',
                                      style: TextStyle(fontSize: 12.5),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${officialPerPersonCash.toStringAsFixed(0)} ${zakatProv.currency}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.emeraldPrimary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'سعر كيس القمح 50 كجم:',
                                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${cloudSync.wheatBagPriceYER.toStringAsFixed(0)} ${zakatProv.currency}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'إجمالي الواجب ($members أفراد):',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
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
                        DropdownButtonFormField<String>(
                          value: _selectedFood,
                          isExpanded: true,
                          isDense: true,
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
                                  Expanded(
                                    child: Text(
                                      food['name'] as String,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
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
                                children: [
                                  Expanded(
                                    child: Text(
                                      'الواجب عن كل فرد:',
                                      style: TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text('صاع نبوي (≈ 2.5 كجم)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'إجمالي الواجب عن $members أفراد:',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${(members * 2.5).toStringAsFixed(1)} كجم ($members أصواع)',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.goldDark, fontSize: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'ما يعادل من أكياس القمح 50 كجم:',
                                      style: TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${((members * 2.5) / 50.0).toStringAsFixed(2)} كيس',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
    ),
  );
  }
}
