import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/formatters.dart';
import '../../models/zakat_record.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class TradeCalcScreen extends StatefulWidget {
  const TradeCalcScreen({super.key});

  @override
  State<TradeCalcScreen> createState() => _TradeCalcScreenState();
}

class _TradeCalcScreenState extends State<TradeCalcScreen> {
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
    final inventory = double.tryParse(_inventoryController.text.trim()) ?? 0.0;
    final cash = double.tryParse(_cashController.text.trim()) ?? 0.0;
    final receivables = double.tryParse(_receivablesController.text.trim()) ?? 0.0;
    final liabilities = double.tryParse(_liabilitiesController.text.trim()) ?? 0.0;

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
  }

  void _saveRecord() async {
    if (_result == null) return;
    final inventory = double.tryParse(_inventoryController.text.trim()) ?? 0.0;
    final cash = double.tryParse(_cashController.text.trim()) ?? 0.0;
    final receivables = double.tryParse(_receivablesController.text.trim()) ?? 0.0;
    final liabilities = double.tryParse(_liabilitiesController.text.trim()) ?? 0.0;
    final totalBase = (inventory + cash + receivables) - liabilities;

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final record = ZakatRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      typeName: 'زكاة عروض التجارة والصناعة',
      categoryKey: 'trade',
      totalWealth: totalBase,
      zakatAmount: _result!.zakatAmount,
      currency: zakatProv.currency,
      reachedNisab: _result!.reachedNisab,
      notes: _result!.explanation,
    );

    await zakatProv.saveRecord(record);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ زكاة التجارة في السجل بنجاح'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _exportPdf() async {
    if (_result == null) return;
    final inventory = double.tryParse(_inventoryController.text.trim()) ?? 0.0;
    final cash = double.tryParse(_cashController.text.trim()) ?? 0.0;
    final receivables = double.tryParse(_receivablesController.text.trim()) ?? 0.0;
    final liabilities = double.tryParse(_liabilitiesController.text.trim()) ?? 0.0;
    final totalBase = (inventory + cash + receivables) - liabilities;

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final record = ZakatRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      typeName: 'زكاة عروض التجارة والصناعة',
      categoryKey: 'trade',
      totalWealth: totalBase,
      zakatAmount: _result!.zakatAmount,
      currency: zakatProv.currency,
      reachedNisab: _result!.reachedNisab,
      notes: _result!.explanation,
    );

    final pdfBytes = await PdfService.generateZakatReceipt(record);
    await PdfService.shareOrPrintPdf(pdfBytes, 'zakat_trade_receipt.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final zakatProv = Provider.of<ZakatProvider>(context);
    final favProv = Provider.of<FavoritesProvider>(context);
    const favId = 'calc_trade';
    final isFav = favProv.isFavorite(favId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('زكاة عروض التجارة'),
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
                  title: 'زكاة عروض التجارة',
                  subtitle: 'حساب زكاة الشركات والمؤسسات والمحلات',
                  type: 'calculator',
                  route: '/trade_calc',
                  imagePath: 'assets/images/trade.png',
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
                      child: Image.asset('assets/images/trade.png'),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'وعاء عروض التجارة والصناعة',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'المعادلة: (البضاعة المعروضة + السيولة النقدية + الديون المرجوة) - الديون التي عليك = الوعاء الزكوي (2.5%).',
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
              decoration: InputDecoration(
                labelText: 'قيمة البضائع في المستودعات والمحلات',
                suffixText: zakatProv.currency,
                prefixIcon: const Icon(Icons.storefront_outlined, color: AppColors.emeraldPrimary),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _cashController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'السيولة النقدية في الصناديق والبنوك',
                suffixText: zakatProv.currency,
                prefixIcon: const Icon(Icons.account_balance_outlined, color: AppColors.emeraldPrimary),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _receivablesController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'الديون المرجوة السداد (لك عند العملاء)',
                suffixText: zakatProv.currency,
                prefixIcon: const Icon(Icons.arrow_downward, color: Colors.green),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _liabilitiesController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'الديون المستحقة عليك للموردين (تُخصم)',
                suffixText: zakatProv.currency,
                prefixIcon: const Icon(Icons.arrow_upward, color: Colors.red),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('احسب زكاة التجارة', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 24),

            if (_isCalculated && _result != null) ...[
              Card(
                color: _result!.reachedNisab ? AppColors.emeraldSubtle : Colors.orange.shade50,
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
