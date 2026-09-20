import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_input_formatters.dart';
import '../../core/widgets/category_icon_badge.dart';
import '../../core/widgets/zakat_result_card.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class StocksCalcScreen extends StatefulWidget {
  const StocksCalcScreen({super.key});

  @override
  State<StocksCalcScreen> createState() => _StocksCalcScreenState();
}

class _StocksCalcScreenState extends State<StocksCalcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sharesCountController = TextEditingController();
  final _sharePriceController = TextEditingController();
  final _dividendController = TextEditingController();
  bool _isSpeculation = true; // true = مضاربة، false = استثمار طويل الأجل
  ZakatCalculationResult? _result;
  bool _isCalculated = false;

  @override
  void dispose() {
    _sharesCountController.dispose();
    _sharePriceController.dispose();
    _dividendController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final sharesCount = AppInputFormatters.tryParseDouble(
        AppInputFormatters.normalizeArabicNumbers(_sharesCountController.text.trim())) ?? 0.0;
    final sharePrice = AppInputFormatters.tryParseDouble(
        AppInputFormatters.normalizeArabicNumbers(_sharePriceController.text.trim())) ?? 0.0;
    final dividend = AppInputFormatters.tryParseDouble(
        AppInputFormatters.normalizeArabicNumbers(_dividendController.text.trim())) ?? 0.0;

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final res = zakatProv.calculateStocksZakat(
      sharesCount: sharesCount,
      shareMarketPrice: sharePrice,
      isSpeculation: _isSpeculation,
      dividendPerShare: dividend,
    );

    setState(() {
      _result = res;
      _isCalculated = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res.reachedNisab
              ? 'تم احتساب زكاة الأسهم والاستثمار بنجاح'
              : 'لم يكتمل النصاب الشرعي للأسهم',
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
    const favId = 'calc_stocks';
    final isFav = favProv.isFavorite(favId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة زكاة الأسهم والاستثمار'),
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
                  title: 'حاسبة زكاة الأسهم',
                  subtitle: 'حساب زكاة أسهم المضاربة والاستثمار',
                  type: 'calculator',
                  route: '/stocks_calc',
                  imagePath: 'assets/images/trade.png',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isNowFav
                        ? 'تمت إضافة "حاسبة زكاة الأسهم" إلى المفضلة'
                        : 'تمت إزالة "حاسبة زكاة الأسهم" من المفضلة',
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
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        fallbackIcon: Icons.trending_up,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'زكاة الأسهم والصناديق الاستثمارية',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'أسهم المضاربة تُزكى بقيمتها السوقية بنسبة 2.5% كعروض تجارة، بينما أسهم الاستثمار طويل الأجل تُزكى على أرباحها أو أصولها الزكوية.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Investment Strategy Selector
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      title: const Text('أسهم للمتاجرة والمضاربة (عروض تجارة)'),
                      subtitle: const Text('المقدار: 2.5% من إجمالي القيمة السوقية الحالية للأسهم'),
                      value: true,
                      groupValue: _isSpeculation,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (val) {
                        if (val != null) setState(() => _isSpeculation = val);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<bool>(
                      title: const Text('أسهم استثمار طويل الأجل (للحصول على الأرباح)'),
                      subtitle: const Text('المقدار: 2.5% من الأرباح الموزعة أو الأصول المتداولة للشركة'),
                      value: false,
                      groupValue: _isSpeculation,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (val) {
                        if (val != null) setState(() => _isSpeculation = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Inputs
              TextFormField(
                controller: _sharesCountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: const InputDecoration(
                  labelText: 'عدد الأسهم المملوكة',
                  hintText: 'مثال: 1000',
                  prefixIcon: Icon(Icons.numbers_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.requiredPositiveNumber('عدد الأسهم'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _sharePriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: 'القيمة السوقية للسهم الواحد حالياً',
                  hintText: 'مثال: 500',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.goldAccent),
                ),
                validator: AppValidators.requiredPositiveNumber('سعر السهم السوقي'),
              ),
              const SizedBox(height: 16),

              if (!_isSpeculation) ...[
                TextFormField(
                  controller: _dividendController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [AppInputFormatters.decimal],
                  decoration: InputDecoration(
                    labelText: 'صافي الربح الموزع لكل سهم (أو الوعاء الزكوي المعتمد)',
                    hintText: 'مثال: 50 (اتركه فارغاً لاعتماد تقدير 10% أصول زكوية)',
                    suffixText: zakatProv.currency,
                    prefixIcon: const Icon(Icons.savings_outlined, color: AppColors.emeraldPrimary),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: const Text('احسب زكاة الأسهم الآن', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 24),

              if (_isCalculated && _result != null) ...[
                ZakatResultCard(
                  result: _result!,
                  typeName: 'زكاة الأسهم والاستثمار',
                  categoryKey: 'trade',
                  totalWealth: (AppInputFormatters.tryParseDouble(_sharesCountController.text) ?? 0.0) *
                      (AppInputFormatters.tryParseDouble(_sharePriceController.text) ?? 0.0),
                  currency: zakatProv.currency,
                  appliedPrice: zakatProv.gold24Price,
                  pdfFileName: 'zakat_stocks_receipt.pdf',
                  pdfTitle: 'إقرار زكاة الأسهم والاستثمار',
                  calculationPolicy: _isSpeculation ? 'أسهم مضاربة (عروض تجارة)' : 'أسهم استثمار طويل الأجل',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
