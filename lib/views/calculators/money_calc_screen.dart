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

class MoneyCalcScreen extends StatefulWidget {
  const MoneyCalcScreen({super.key});

  @override
  State<MoneyCalcScreen> createState() => _MoneyCalcScreenState();
}

class _MoneyCalcScreenState extends State<MoneyCalcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _goldPriceController = TextEditingController();
  final _receivablesController = TextEditingController();
  final _liabilitiesController = TextEditingController();
  bool _useSilverNisab = false;
  ZakatCalculationResult? _result;
  bool _isCalculated = false;
  bool _isPriceConfirmed = false;

  @override
  void initState() {
    super.initState();
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    _goldPriceController.text = zakatProv.gold24Price.toStringAsFixed(0);
    _amountController.addListener(_onInputChanged);
    _goldPriceController.addListener(_onInputChanged);
    _receivablesController.addListener(_onInputChanged);
    _liabilitiesController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (_isPriceConfirmed) {
      setState(() {
        _isPriceConfirmed = false;
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onInputChanged);
    _goldPriceController.removeListener(_onInputChanged);
    _receivablesController.removeListener(_onInputChanged);
    _liabilitiesController.removeListener(_onInputChanged);
    _amountController.dispose();
    _goldPriceController.dispose();
    _receivablesController.dispose();
    _liabilitiesController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;

    final amountText = AppInputFormatters.normalizeArabicNumbers(_amountController.text.trim());
    final goldPriceText = AppInputFormatters.normalizeArabicNumbers(_goldPriceController.text.trim());
    final amount = double.tryParse(amountText) ?? 0.0;
    final goldPrice = double.tryParse(goldPriceText) ?? 0.0;
    final receivables = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_receivablesController.text.trim())) ?? 0.0;
    final liabilities = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_liabilitiesController.text.trim())) ?? 0.0;

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    final effectivePrice = _useSilverNisab ? zakatProv.silverPrice : goldPrice;
    final nisabThreshold = _useSilverNisab ? (595.0 * effectivePrice) : (85.0 * effectivePrice);
    final netWorth = (amount + receivables) - liabilities;
    final isNear = zakatProv.isCloseToNisab(netWorth, nisabThreshold);

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
              Text('صافي الوعاء الزكوي (${netWorth.toStringAsFixed(0)} ${zakatProv.currency}) قريب جداً من حد النصاب الشرعي (${nisabThreshold.toStringAsFixed(0)} ${zakatProv.currency}).'),
              const SizedBox(height: 8),
              Text('المصدر: ${zakatProv.currentPriceSnapshot.source}'),
              const SizedBox(height: 8),
              const Text('نظراً لأن تغير سعر الذهب/الفضة قد يقلب وجوب الزكاة، يرجى تأكيد السعر قبل اعتماد النتيجة.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('مراجعة السعر'),
            ),
            ElevatedButton(
              key: const Key('btn_confirm_price_near_nisab_dialog'),
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

    final res = zakatProv.calculateMoneyZakat(
      amount,
      goldPricePerGram: goldPrice,
      receivables: receivables,
      liabilities: liabilities,
      useSilverNisab: _useSilverNisab,
    );

    setState(() {
      _result = res;
      _isCalculated = true;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم احتساب زكاة المال بنجاح'),
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
    const favId = 'calc_money';
    final isFav = favProv.isFavorite(favId);

    final enteredAmount = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_amountController.text.trim())) ?? 0.0;
    final enteredGoldPrice = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_goldPriceController.text.trim())) ?? zakatProv.gold24Price;
    final nisabThreshold = 85.0 * enteredGoldPrice;
    final isNearNisab = enteredAmount > 0 && zakatProv.isCloseToNisab(enteredAmount, nisabThreshold);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة زكاة المال'),
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
                  title: 'حاسبة زكاة المال',
                  subtitle: 'حساب زكاة السيولة والنقد المدخر',
                  type: 'calculator',
                  route: '/money_calc',
                  imagePath: 'assets/images/money.png',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isNowFav
                        ? 'تمت إضافة "حاسبة زكاة المال" إلى المفضلة'
                        : 'تمت إزالة "حاسبة زكاة المال" من المفضلة',
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
              // Header Image & Description Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CategoryIconBadge(
                        imagePath: 'assets/images/money.png',
                        size: 60,
                        iconSize: 32,
                        padding: 8,
                        borderRadius: 14,
                        fallbackIcon: Icons.account_balance_wallet,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'زكاة الأموال النقدية والمدخرات',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'تجب الزكاة بنسبة ربع العشر (2.5%) إذا بلغ المال نصاب 85 جرام ذهب خالص (عيار 24) وحال عليه الحول.',
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

              // Form Inputs
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: 'إجمالي المبلغ المالي المدخر',
                  hintText: 'مثال: 5000000',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.requiredPositiveNumber('المبلغ المدخر'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _goldPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: 'سعر جرام الذهب عيار 24 اليوم (المعتمد للنصاب)',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.price_change_outlined, color: AppColors.goldAccent),
                ),
                validator: AppValidators.requiredPositiveNumber('سعر جرام الذهب عيار 24'),
              ),
              const SizedBox(height: 16),

              // Receivables (ديون لك مرجوة السداد)
              TextFormField(
                controller: _receivablesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: 'ديون لك مرجوة السداد (تُضاف للوعاء - اختياري)',
                  hintText: '0',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.add_circle_outline, color: AppColors.success),
                ),
              ),
              const SizedBox(height: 16),

              // Liabilities (ديون عليك حالة واجبة السداد)
              TextFormField(
                controller: _liabilitiesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: 'ديون عليك عاجلة واجبة السداد (تُخصم من الوعاء - اختياري)',
                  hintText: '0',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                ),
              ),
              const SizedBox(height: 8),

              // Silver Nisab Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('اعتماد نصاب الفضة (595 جراماً)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: const Text('قول معتبر وأحظ لمصلحة الفقراء في الأوراق النقدية المعاصرة', style: TextStyle(fontSize: 12)),
                value: _useSilverNisab,
                activeColor: AppColors.emeraldPrimary,
                onChanged: (val) {
                  setState(() {
                    _useSilverNisab = val;
                  });
                },
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
                label: const Text('احسب الزكاة الآن', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 24),

              // Result Display using unified ZakatResultCard
              if (_isCalculated && _result != null)
                ZakatResultCard(
                  result: _result!,
                  typeName: 'زكاة المال والنقود',
                  categoryKey: 'money',
                  totalWealth: double.tryParse(AppInputFormatters.normalizeArabicNumbers(_amountController.text.trim())) ?? 0.0,
                  currency: zakatProv.currency,
                  appliedPrice: double.tryParse(AppInputFormatters.normalizeArabicNumbers(_goldPriceController.text.trim())),
                  pdfFileName: 'zakat_money_receipt.pdf',
                  pdfTitle: 'إقرار زكاة الأموال والنقود',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
