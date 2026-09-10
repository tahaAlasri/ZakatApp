import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/pdf_service.dart';
import '../../models/zakat_record.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class SilverCalcScreen extends StatefulWidget {
  const SilverCalcScreen({super.key});

  @override
  State<SilverCalcScreen> createState() => _SilverCalcScreenState();
}

class _SilverCalcScreenState extends State<SilverCalcScreen> {
  final _gramsController = TextEditingController();
  final _priceController = TextEditingController();
  ZakatCalculationResult? _result;
  bool _isCalculated = false;

  @override
  void initState() {
    super.initState();
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    _priceController.text = zakatProv.silverPrice.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _gramsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _calculate() {
    final grams = double.tryParse(_gramsController.text.trim()) ?? 0.0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    final res = zakatProv.calculateSilverZakat(grams, pricePerGram: price);

    setState(() {
      _result = res;
      _isCalculated = true;
    });
  }

  void _saveRecord() async {
    if (_result == null) return;
    final grams = double.tryParse(_gramsController.text.trim()) ?? 0.0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final record = ZakatRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      typeName: 'زكاة الفضة',
      categoryKey: 'silver',
      totalWealth: grams,
      zakatAmount: _result!.zakatAmount,
      zakatInKindDescription: _result!.zakatInKindDescription,
      currency: zakatProv.currency,
      reachedNisab: _result!.reachedNisab,
      notes: _result!.explanation,
    );

    await zakatProv.saveRecord(record);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ زكاة الفضة في السجل بنجاح'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _exportPdf() async {
    if (_result == null) return;
    final grams = double.tryParse(_gramsController.text.trim()) ?? 0.0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final record = ZakatRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      typeName: 'زكاة الفضة',
      categoryKey: 'silver',
      totalWealth: grams,
      zakatAmount: _result!.zakatAmount,
      zakatInKindDescription: _result!.zakatInKindDescription,
      currency: zakatProv.currency,
      reachedNisab: _result!.reachedNisab,
      notes: _result!.explanation,
    );

    final pdfBytes = await PdfService.generateZakatReceipt(record);
    await PdfService.shareOrPrintPdf(pdfBytes, 'zakat_silver_receipt.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final zakatProv = Provider.of<ZakatProvider>(context);
    final favProv = Provider.of<FavoritesProvider>(context);
    const favId = 'calc_silver';
    final isFav = favProv.isFavorite(favId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة زكاة الفضة'),
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
                  title: 'حاسبة زكاة الفضة',
                  subtitle: 'حساب زكاة الفضة وسبائكها',
                  type: 'calculator',
                  route: '/silver_calc',
                  imagePath: 'assets/images/silver.png',
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
                      child: Image.asset('assets/images/silver.png'),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'نصاب الفضة 595 جراماً',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'المقدار الواجب ربع العشر (2.5%) إذا بلغت الفضة 595 جراماً وحال عليها الحول.',
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
              controller: _gramsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'وزن الفضة بالجرام',
                hintText: 'مثال: 650',
                suffixText: 'جرام',
                prefixIcon: Icon(Icons.scale_outlined, color: Colors.blueGrey),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'سعر جرام الفضة اليوم',
                suffixText: zakatProv.currency,
                prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.emeraldPrimary),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('احسب زكاة الفضة', style: TextStyle(fontSize: 18)),
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
                          _result!.zakatInKindDescription,
                          style: const TextStyle(
                            fontSize: 18,
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
