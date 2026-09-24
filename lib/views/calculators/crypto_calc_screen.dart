import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_input_formatters.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/widgets/zakat_result_card.dart';
import '../../providers/zakat_provider.dart';
import '../../models/favorite_item.dart';
import '../../providers/favorites_provider.dart';
import '../../models/zakat_record.dart';

class CryptoCalcScreen extends StatefulWidget {
  const CryptoCalcScreen({super.key});

  @override
  State<CryptoCalcScreen> createState() => _CryptoCalcScreenState();
}

class _CryptoCalcScreenState extends State<CryptoCalcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isSolarYear = false;
  ZakatCalculationResult? _result;
  bool _isCalculated = false;

  @override
  void dispose() {
    _amountController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = AppInputFormatters.tryParseDouble(_amountController.text) ?? 0;
    final price = AppInputFormatters.tryParseDouble(_priceController.text) ?? 0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final res = zakatProv.calculateCryptoZakat(
      cryptoAmount: amount,
      cryptoMarketPriceInFiat: price,
      isSolarYear: _isSolarYear,
    );

    setState(() {
      _result = res;
      _isCalculated = true;
    });

    if (res.reachedNisab) {
      zakatProv.saveRecord(ZakatRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: null,
        typeName: 'العملات الرقمية',
        categoryKey: 'crypto',
        totalWealth: amount,
        zakatAmount: res.zakatDue,
        currency: zakatProv.currency,
        reachedNisab: res.reachedNisab,
        appliedPrice: res.appliedPrice,
        nisabThreshold: res.nisabThreshold,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('زكاة العملات الرقمية'),
        actions: [
          Consumer<FavoritesProvider>(
            builder: (context, favProvider, child) {
              final isFav = favProvider.isFavorite('crypto');
              return IconButton(
                icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
                color: isFav ? AppColors.goldAccent : null,
                onPressed: () {
                  favProvider.toggleFavorite(FavoriteItem(
                    id: 'crypto',
                    title: 'زكاة العملات الرقمية',
                    subtitle: 'حاسبة العملات المشفرة',
                    type: 'calculator',
                    route: '/crypto_calc',
                    imagePath: 'assets/images/crypto.png',
                  ));
                },
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: context.rPadding(horizontal: 16, vertical: 16),
          child: ResponsiveConstraint(
            maxWidth: 680,
            child: Form(
              key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.emeraldSubtle,
                    child: Icon(Icons.currency_bitcoin, color: AppColors.emeraldPrimary),
                  ),
                  title: Text('العملات الرقمية والمشفرة', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('الزكاة على البيتكوين والعملات المشفرة إذا بلغت النصاب'),
                ),
                const SizedBox(height: 24),
                
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'بيانات العملة الرقمية',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.emeraldPrimary,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'الرصيد الممتلك (الكمية)',
                            hintText: 'مثال: 1.5',
                            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'يرجى إدخال الرصيد';
                            final parsed = double.tryParse(value);
                            if (parsed == null || parsed <= 0) return 'يرجى إدخال رقم صحيح';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'السعر السوقي للعملة الواحدة (${Provider.of<ZakatProvider>(context, listen: false).currency})',
                            hintText: 'مثال: السعر الحالي',
                            prefixIcon: const Icon(Icons.price_change_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'يرجى إدخال السعر';
                            final parsed = double.tryParse(value);
                            if (parsed == null || parsed <= 0) return 'يرجى إدخال رقم صحيح';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                SwitchListTile(
                  title: const Text('حساب بناءً على السنة الميلادية'),
                  subtitle: const Text('السنة الميلادية تعادل 2.577% بدلاً من 2.5% لتعويض فارق الأيام'),
                  value: _isSolarYear,
                  onChanged: (val) {
                    setState(() {
                      _isSolarYear = val;
                      if (_isCalculated) _calculate();
                    });
                  },
                  secondary: const Icon(Icons.calendar_month_outlined),
                  activeColor: AppColors.emeraldPrimary,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                
                ElevatedButton.icon(
                  onPressed: _calculate,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('احسب الزكاة'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                
                if (_isCalculated && _result != null)
                  ZakatResultCard(
                    typeName: 'العملات الرقمية',
                    categoryKey: 'crypto',
                    totalWealth: AppInputFormatters.tryParseDouble(_amountController.text) ?? 0,
                    currency: Provider.of<ZakatProvider>(context, listen: false).currency,
                    pdfFileName: 'crypto_zakat_${DateTime.now().millisecondsSinceEpoch}',
                    pdfTitle: 'تقرير زكاة العملات الرقمية',
                    result: _result!,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
