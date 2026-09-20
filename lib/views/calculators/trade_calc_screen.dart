import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_input_formatters.dart';
import '../../core/widgets/category_icon_badge.dart';
import '../../core/widgets/zakat_result_card.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class TradeCalcScreen extends StatefulWidget {
  const TradeCalcScreen({super.key});

  @override
  State<TradeCalcScreen> createState() => _TradeCalcScreenState();
}

class _TradeCalcScreenState extends State<TradeCalcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inventoryController = TextEditingController();
  final _cashController = TextEditingController();
  final _receivablesController = TextEditingController();
  final _liabilitiesController = TextEditingController();

  ZakatCalculationResult? _result;
  bool _isCalculated = false;

  @override
  void dispose() {
    _inventoryController.dispose();
    _cashController.dispose();
    _receivablesController.dispose();
    _liabilitiesController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final inventory = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_inventoryController.text.trim())) ?? 0.0;
    final cash = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_cashController.text.trim())) ?? 0.0;
    final receivables = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_receivablesController.text.trim())) ?? 0.0;
    final liabilities = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_liabilitiesController.text.trim())) ?? 0.0;

    if (inventory <= 0 && cash <= 0 && receivables <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال قيمة البضائع أو السيولة أو الديون المرجوة (أكبر من الصفر)'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    final res = zakatProv.calculateTradeZakat(
      inventoryValue: inventory,
      cashInHand: cash,
      receivables: receivables,
      liabilities: liabilities,
    );

    setState(() {
      _result = res;
      _isCalculated = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم احتساب زكاة عروض التجارة بنجاح'),
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
    const favId = 'calc_trade';
    final isFav = favProv.isFavorite(favId);

    final inventory = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_inventoryController.text.trim())) ?? 0.0;
    final cash = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_cashController.text.trim())) ?? 0.0;
    final receivables = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_receivablesController.text.trim())) ?? 0.0;
    final liabilities = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_liabilitiesController.text.trim())) ?? 0.0;
    final totalBase = (inventory + cash + receivables) - liabilities;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة عروض التجارة'),
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
                  title: 'حاسبة عروض التجارة',
                  subtitle: 'حساب زكاة عروض التجارة والمؤسسات',
                  type: 'calculator',
                  route: '/trade_calc',
                  imagePath: 'assets/images/trade.png',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isNowFav
                        ? 'تمت إضافة "حاسبة عروض التجارة" إلى المفضلة'
                        : 'تمت إزالة "حاسبة عروض التجارة" من المفضلة',
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
                        imagePath: 'assets/images/trade.png',
                        size: 60,
                        iconSize: 32,
                        padding: 8,
                        borderRadius: 14,
                        fallbackIcon: Icons.storefront_outlined,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'وعاء عروض التجارة',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'المعادلة الشرعية: (البضائع بسعر البيع الحالي + النقد والسيولة + الديون المرجوة) - الديون التي عليك = الوعاء الخاضع للزكاة (2.5%).',
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
                controller: _inventoryController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: 'قيمة البضائع المعدة للبيع (سعر السوق اليوم)',
                  hintText: 'مثال: 10000000',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.nonNegativeNumber('قيمة البضائع'),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _cashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: 'السيولة النقدية في الصندوق وحسابات البنك',
                  hintText: 'مثال: 3000000',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.nonNegativeNumber('السيولة النقدية'),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _receivablesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: 'ديونك المرجوة على الآخرين (المرجوة السداد)',
                  hintText: 'مثال: 1500000',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.arrow_downward, color: Colors.green),
                ),
                validator: AppValidators.nonNegativeNumber('الديون المرجوة'),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _liabilitiesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: 'الديون والالتزامات الحالة عليك للموردين',
                  hintText: 'مثال: 2000000',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.arrow_upward, color: Colors.redAccent),
                ),
                validator: AppValidators.nonNegativeNumber('الديون الحالة عليك'),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: const Text('احسب زكاة التجارة', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 24),

              // Unified Result Card
              if (_isCalculated && _result != null)
                ZakatResultCard(
                  result: _result!,
                  typeName: 'زكاة عروض التجارة والصناعة',
                  categoryKey: 'trade',
                  totalWealth: totalBase > 0 ? totalBase : 0,
                  currency: zakatProv.currency,
                  pdfFileName: 'zakat_trade_receipt.pdf',
                  pdfTitle: 'إقرار وتفصيل حساب زكاة عروض التجارة',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
