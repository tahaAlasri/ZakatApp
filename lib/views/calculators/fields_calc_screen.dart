import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_input_formatters.dart';
import '../../core/widgets/category_icon_badge.dart';
import '../../core/widgets/zakat_result_card.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class FieldsCalcScreen extends StatefulWidget {
  const FieldsCalcScreen({super.key});

  @override
  State<FieldsCalcScreen> createState() => _FieldsCalcScreenState();
}

class _FieldsCalcScreenState extends State<FieldsCalcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _incomeController = TextEditingController();
  final _expensesController = TextEditingController();

  ExploitedAssetsMethod _selectedMethod = ExploitedAssetsMethod.netRevenue;
  ZakatCalculationResult? _result;
  bool _isCalculated = false;

  @override
  void dispose() {
    _incomeController.dispose();
    _expensesController.dispose();
    super.dispose();
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
              Expanded(child: Text('يرجى تصحيح الأخطاء في الحقول والمتابعة')),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final income = AppInputFormatters.tryParseDouble(_incomeController.text) ?? 0.0;
    final expenses = _selectedMethod == ExploitedAssetsMethod.grossRevenue
        ? 0.0
        : (AppInputFormatters.tryParseDouble(_expensesController.text) ?? 0.0);

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    final res = zakatProv.calculateExploitedAssetsZakat(
      grossIncome: income,
      expenses: expenses,
      method: _selectedMethod,
    );

    setState(() {
      _result = res;
      _isCalculated = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                res.isZakatRequired
                    ? 'تم الحساب (${_selectedMethod.label}): تجب الزكاة بمقدار ${res.zakatDue.toStringAsFixed(2)} ${zakatProv.currency}'
                    : 'تم الحساب (${_selectedMethod.label}): لم يبلغ الوعاء النصاب المطلوب',
              ),
            ),
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
    const favId = 'calc_fields';
    final isFav = favProv.isFavorite(favId);

    final income = AppInputFormatters.tryParseDouble(_incomeController.text) ?? 0.0;
    final expenses = _selectedMethod == ExploitedAssetsMethod.grossRevenue
        ? 0.0
        : (AppInputFormatters.tryParseDouble(_expensesController.text) ?? 0.0);
    final taxableWealth = _selectedMethod == ExploitedAssetsMethod.grossRevenue ? income : (income - expenses);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة زكاة المستغلات'),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.redAccent : Colors.white,
            ),
            onPressed: () {
              favProv.toggleFavorite(
                FavoriteItem(
                  id: favId,
                  title: 'حاسبة زكاة المستغلات',
                  subtitle: 'حساب زكاة العقارات المؤجرة والمصانع',
                  type: 'calculator',
                  route: '/fields_calc',
                  imagePath: 'assets/images/fields.png',
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CategoryIconBadge(
                        imagePath: 'assets/images/fields.png',
                        size: 60,
                        iconSize: 32,
                        padding: 8,
                        borderRadius: 14,
                        fallbackIcon: Icons.apartment_outlined,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'زكاة المستغلات وريع العقارات',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'المستغلات هي الأصول المعدة للريع والإيجار لا للبيع بذاتها (كالعقارات والفنادق والمصانع)، وتخضع لاجتهادات فقهية وطرق حساب متعددة موضحة أدناه.',
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

              // Selection for Calculation Method
              const Text(
                'طريقة الحساب الفقهية والنظامية:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    RadioListTile<ExploitedAssetsMethod>(
                      title: const Text('صافي الريع', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('حساب 2.5% من الإيرادات بعد خصم مصاريف التشغيل والصيانة والضرائب'),
                      value: ExploitedAssetsMethod.netRevenue,
                      groupValue: _selectedMethod,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedMethod = val);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<ExploitedAssetsMethod>(
                      title: const Text('إجمالي الريع', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('حساب 2.5% من إجمالي الإيرادات مباشرة دون خصم المصروفات التشغيلية'),
                      value: ExploitedAssetsMethod.grossRevenue,
                      groupValue: _selectedMethod,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedMethod = val);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<ExploitedAssetsMethod>(
                      title: const Text('وعاء نقدي متراكم بعد بلوغ النصاب', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('مذهب الجمهور: لا زكاة في عين الأصل، وتُضم الغلة للسيولة النقدية بحولان الحول وبلوغ النصاب'),
                      value: ExploitedAssetsMethod.accumulatedCash,
                      groupValue: _selectedMethod,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedMethod = val);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<ExploitedAssetsMethod>(
                      title: const Text('سياسة الجهة المعتمدة', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('احتساب الزكاة على الوعاء المعتمد نظامياً وفق لوائح وتعليمات الهيئة المعتمدة'),
                      value: ExploitedAssetsMethod.authorityPolicy,
                      groupValue: _selectedMethod,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedMethod = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _incomeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                validator: AppValidators.requiredPositiveNumber(
                  _selectedMethod == ExploitedAssetsMethod.accumulatedCash
                      ? 'الوعاء النقدي المتراكم'
                      : 'إجمالي الإيرادات',
                ),
                decoration: InputDecoration(
                  labelText: _selectedMethod == ExploitedAssetsMethod.accumulatedCash
                      ? 'الوعاء النقدي المتراكم من الغلة بعد الحول'
                      : 'إجمالي الإيرادات / الإيجارات المحصلة',
                  hintText: 'مثال: 6000000',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.arrow_downward, color: Colors.green),
                ),
              ),
              const SizedBox(height: 16),

              if (_selectedMethod != ExploitedAssetsMethod.grossRevenue) ...[
                TextFormField(
                  controller: _expensesController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [AppInputFormatters.decimal],
                  validator: AppValidators.nonNegativeNumber('المصاريف التشغيلية'),
                  decoration: InputDecoration(
                    labelText: 'المصاريف التشغيلية والصيانة والضرائب',
                    hintText: 'مثال: 1000000 (أو 0 إذا لم توجد)',
                    suffixText: zakatProv.currency,
                    prefixIcon: const Icon(Icons.arrow_upward, color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 24),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'في طريقة "إجمالي الريع"، لا تُخصم المصروفات التشغيلية ويتم احتساب الوعاء من كامل الإيراد مباشرة.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: const Text('احسب زكاة المستغلات', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 24),

              // Unified Result Card with prominent method badge
              if (_isCalculated && _result != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: AppColors.emeraldPrimary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تم الحساب بناءً على طريقة: ${_selectedMethod.label}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.emeraldPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ZakatResultCard(
                  result: _result!,
                  typeName: 'زكاة المستغلات (${_selectedMethod.label})',
                  categoryKey: 'fields',
                  totalWealth: taxableWealth > 0 ? taxableWealth : 0,
                  currency: zakatProv.currency,
                  calculationPolicy: _selectedMethod.label,
                  inputs: {
                    'income': double.tryParse(AppInputFormatters.normalizeArabicNumbers(_incomeController.text.trim())) ?? 0.0,
                    'expenses': double.tryParse(AppInputFormatters.normalizeArabicNumbers(_expensesController.text.trim())) ?? 0.0,
                    'taxableWealth': taxableWealth,
                    'method': _selectedMethod.name,
                    'methodLabel': _selectedMethod.label,
                  },
                  pdfFileName: 'zakat_fields_receipt.pdf',
                  pdfTitle: 'إقرار وتفصيل حساب زكاة المستغلات (${_selectedMethod.label})',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
