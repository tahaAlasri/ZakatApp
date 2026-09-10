import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/formatters.dart';
import '../../models/zakat_record.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class MoneyCalcScreen extends StatefulWidget {
  const MoneyCalcScreen({super.key});

  @override
  State<MoneyCalcScreen> createState() => _MoneyCalcScreenState();
}

class _MoneyCalcScreenState extends State<MoneyCalcScreen> {
  final _amountController = TextEditingController();
  final _goldPriceController = TextEditingController();
  ZakatCalculationResult? _result;
  bool _isCalculated = false;

  @override
  void initState() {
    super.initState();
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    _goldPriceController.text = zakatProv.goldPrice.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _goldPriceController.dispose();
    super.dispose();
  }

  void _calculate() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final goldPrice = double.tryParse(_goldPriceController.text.trim()) ?? 0.0;

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    final res = zakatProv.calculateMoneyZakat(amount, goldPricePerGram: goldPrice);

    setState(() {
      _result = res;
      _isCalculated = true;
    });
  }

  void _saveRecord() async {
    if (_result == null) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final record = ZakatRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      typeName: 'زكاة المال والنقود',
      categoryKey: 'money',
      totalWealth: amount,
      zakatAmount: _result!.zakatAmount,
      currency: zakatProv.currency,
      reachedNisab: _result!.reachedNisab,
      notes: _result!.explanation,
    );

    await zakatProv.saveRecord(record);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ العملية في سجل الحسابات بنجاح'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _exportPdf() async {
    if (_result == null) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final record = ZakatRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      typeName: 'زكاة المال والنقود',
      categoryKey: 'money',
      totalWealth: amount,
      zakatAmount: _result!.zakatAmount,
      currency: zakatProv.currency,
      reachedNisab: _result!.reachedNisab,
      notes: _result!.explanation,
    );

    final pdfBytes = await PdfService.generateZakatReceipt(record);
    await PdfService.shareOrPrintPdf(pdfBytes, 'zakat_money_receipt.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final zakatProv = Provider.of<ZakatProvider>(context);
    final favProv = Provider.of<FavoritesProvider>(context);
    const favId = 'calc_money';
    final isFav = favProv.isFavorite(favId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة زكاة المال'),
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
                  title: 'حاسبة زكاة المال',
                  subtitle: 'حساب زكاة السيولة والنقد المدخر',
                  type: 'calculator',
                  route: '/money_calc',
                  imagePath: 'assets/images/money.png',
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Image & Description Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldSubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset('assets/images/money.png'),
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
                            'تجب الزكاة بنسبة ربع العشر (2.5%) إذا بلغ المال نصاب 85 جرام ذهب وحال عليه الحول.',
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
              decoration: InputDecoration(
                labelText: 'إجمالي المبلغ المالي المدخر',
                hintText: 'مثال: 5000000',
                suffixText: zakatProv.currency,
                prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.emeraldPrimary),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _goldPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'سعر جرام الذهب عيار 21 اليوم',
                suffixText: zakatProv.currency,
                prefixIcon: const Icon(Icons.price_change_outlined, color: AppColors.goldAccent),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('احسب الزكاة الآن', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 24),

            // Result Display
            if (_isCalculated && _result != null) ...[
              Card(
                color: _result!.reachedNisab
                    ? AppColors.emeraldSubtle
                    : Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _result!.reachedNisab ? AppColors.emeraldPrimary : Colors.orange,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _result!.reachedNisab ? Icons.check_circle : Icons.info,
                            color: _result!.reachedNisab ? AppColors.emeraldPrimary : Colors.orange.shade800,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _result!.reachedNisab ? 'اكتمل النصاب الشرعي' : 'لم يكتمل النصاب',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _result!.reachedNisab ? AppColors.emeraldDark : Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _result!.explanation,
                        style: TextStyle(
                          fontSize: 14,
                          color: _result!.reachedNisab ? AppColors.emeraldDark : Colors.brown,
                        ),
                      ),
                      if (_result!.reachedNisab) ...[
                        const Divider(height: 24),
                        const Text(
                          'المقدار الواجب إخراجه:',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppFormatters.formatCurrency(_result!.zakatAmount, currency: zakatProv.currency),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.emeraldPrimary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saveRecord,
                              icon: const Icon(Icons.bookmark_add_outlined),
                              label: const Text('حفظ بالسجل'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _exportPdf,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.goldAccent,
                                foregroundColor: Colors.black,
                              ),
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('تصدير PDF'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
