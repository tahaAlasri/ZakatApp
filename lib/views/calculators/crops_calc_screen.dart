import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/formatters.dart';
import '../../models/zakat_record.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class CropsCalcScreen extends StatefulWidget {
  const CropsCalcScreen({super.key});

  @override
  State<CropsCalcScreen> createState() => _CropsCalcScreenState();
}

class _CropsCalcScreenState extends State<CropsCalcScreen> {
  final _amountController = TextEditingController();
  String _irrigationType = 'natural'; // natural, artificial, mixed
  ZakatCalculationResult? _result;
  bool _isCalculated = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _calculate() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final res = zakatProv.calculateCropsZakat(
      totalCropValue: amount,
      irrigationType: _irrigationType,
    );

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
      typeName: 'زكاة الزروع والثمار',
      categoryKey: 'crops',
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
        content: Text('تم حفظ زكاة الزروع في السجل بنجاح'),
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
      typeName: 'زكاة الزروع والثمار',
      categoryKey: 'crops',
      totalWealth: amount,
      zakatAmount: _result!.zakatAmount,
      currency: zakatProv.currency,
      reachedNisab: _result!.reachedNisab,
      notes: _result!.explanation,
    );

    final pdfBytes = await PdfService.generateZakatReceipt(record);
    await PdfService.shareOrPrintPdf(pdfBytes, 'zakat_crops_receipt.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final zakatProv = Provider.of<ZakatProvider>(context);
    final favProv = Provider.of<FavoritesProvider>(context);
    const favId = 'calc_crops';
    final isFav = favProv.isFavorite(favId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('زكاة الحبوب والثمار'),
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
                  title: 'زكاة الحبوب والثمار',
                  subtitle: 'حساب زكاة المحاصيل الزراعية والتمور والفاكهة',
                  type: 'calculator',
                  route: '/crops_calc',
                  imagePath: 'assets/images/crops.png',
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
                      child: Image.asset('assets/images/crops.png'),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'زكاة المحاصيل والزروع',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'تجب الزكاة يوم الحصاد؛ العشر (10%) لما سقي بلا كلفة، ونصف العشر (5%) لما سقي بمؤونة وآلات.',
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

            // Amount / Value
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'قيمة أو كمية المحصول الإجمالي',
                hintText: 'أدخل قيمة المحصول الإجمالية',
                suffixText: zakatProv.currency,
                prefixIcon: const Icon(Icons.agriculture_outlined, color: Colors.green),
              ),
            ),
            const SizedBox(height: 16),

            // Irrigation type dropdown
            DropdownButtonFormField<String>(
              initialValue: _irrigationType,
              decoration: const InputDecoration(
                labelText: 'طريقة السقي والري',
                prefixIcon: Icon(Icons.water_drop_outlined, color: Colors.blue),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'natural',
                  child: Text('ري طبيعي (مطر، سيول) - العشر 10%'),
                ),
                DropdownMenuItem(
                  value: 'artificial',
                  child: Text('ري صناعي (آلات، مضخات) - نصف العشر 5%'),
                ),
                DropdownMenuItem(
                  value: 'mixed',
                  child: Text('ري مشترك (طبيعي وصناعي) - 7.5%'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _irrigationType = val;
                  });
                }
              },
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('احسب زكاة الزروع', style: TextStyle(fontSize: 18)),
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
                            _result!.reachedNisab ? 'واجبة الإخراج يوم الحصاد' : 'قيمة غير صحيحة',
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
