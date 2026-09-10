import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/formatters.dart';
import '../../models/zakat_record.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class FieldsCalcScreen extends StatefulWidget {
  const FieldsCalcScreen({super.key});

  @override
  State<FieldsCalcScreen> createState() => _FieldsCalcScreenState();
}

class _FieldsCalcScreenState extends State<FieldsCalcScreen> {
  final _incomeController = TextEditingController();
  final _expensesController = TextEditingController();

  ZakatCalculationResult? _result;
  bool _isCalculated = false;

  @override
  void dispose() {
    _incomeController.dispose();
    _expensesController.dispose();
    super.dispose();
  }

  void _calculate() {
    final income = double.tryParse(_incomeController.text.trim()) ?? 0.0;
    final expenses = double.tryParse(_expensesController.text.trim()) ?? 0.0;

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    final res = zakatProv.calculateExploitedAssetsZakat(
      grossIncome: income,
      expenses: expenses,
    );

    setState(() {
      _result = res;
      _isCalculated = true;
    });
  }

  void _saveRecord() async {
    if (_result == null) return;
    final income = double.tryParse(_incomeController.text.trim()) ?? 0.0;
    final expenses = double.tryParse(_expensesController.text.trim()) ?? 0.0;
    final net = income - expenses;

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final record = ZakatRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      typeName: 'زكاة المستغلات والعقارات المؤجرة',
      categoryKey: 'fields',
      totalWealth: net,
      zakatAmount: _result!.zakatAmount,
      currency: zakatProv.currency,
      reachedNisab: _result!.reachedNisab,
      notes: _result!.explanation,
    );

    await zakatProv.saveRecord(record);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ زكاة المستغلات في السجل بنجاح'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _exportPdf() async {
    if (_result == null) return;
    final income = double.tryParse(_incomeController.text.trim()) ?? 0.0;
    final expenses = double.tryParse(_expensesController.text.trim()) ?? 0.0;
    final net = income - expenses;

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final record = ZakatRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      typeName: 'زكاة المستغلات والعقارات المؤجرة',
      categoryKey: 'fields',
      totalWealth: net,
      zakatAmount: _result!.zakatAmount,
      currency: zakatProv.currency,
      reachedNisab: _result!.reachedNisab,
      notes: _result!.explanation,
    );

    final pdfBytes = await PdfService.generateZakatReceipt(record);
    await PdfService.shareOrPrintPdf(pdfBytes, 'zakat_fields_receipt.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final zakatProv = Provider.of<ZakatProvider>(context);
    final favProv = Provider.of<FavoritesProvider>(context);
    const favId = 'calc_fields';
    final isFav = favProv.isFavorite(favId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('زكاة المستغلات'),
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
                  title: 'زكاة المستغلات',
                  subtitle: 'حساب زكاة العقارات المؤجرة والمصانع وسيارات الأجرة',
                  type: 'calculator',
                  route: '/fields_calc',
                  imagePath: 'assets/images/fields.png',
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
                      child: Image.asset('assets/images/fields.png'),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('زكاة المستغلات والريع',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 4),
                          Text(
                            'تشمل العقارات والمباني المؤجرة، وسيارات الأجرة، والمصانع. الزكاة في صافي الدخل (2.5%) بعد خصم مصاريف الصيانة والتشغيل.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
              controller: _incomeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'إجمالي الإيرادات والإيجارات المقبوضة',
                suffixText: zakatProv.currency,
                prefixIcon: const Icon(Icons.apartment_outlined, color: AppColors.emeraldPrimary),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _expensesController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'المصاريف والتشغيل والصيانة (تُخصم)',
                suffixText: zakatProv.currency,
                prefixIcon: const Icon(Icons.build_outlined, color: Colors.brown),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('احسب زكاة المستغلات', style: TextStyle(fontSize: 18)),
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
