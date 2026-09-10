import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/formatters.dart';
import '../../models/zakat_record.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class MineralsScreen extends StatefulWidget {
  const MineralsScreen({super.key});

  @override
  State<MineralsScreen> createState() => _MineralsScreenState();
}

class _MineralsScreenState extends State<MineralsScreen> {
  final _amountController = TextEditingController();
  bool _isRikaz = true; // true = الركاز (20%), false = المعادن (2.5%)
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

    final res = zakatProv.calculateMineralsZakat(
      totalExtractedValue: amount,
      isRikaz: _isRikaz,
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
      typeName: _isRikaz ? 'زكاة الركاز (دفين الجاهلية)' : 'زكاة المعادن والمنتجات المائية',
      categoryKey: 'minerals',
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
        content: Text('تم حفظ زكاة الركاز والمعادن في السجل'),
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
      typeName: _isRikaz ? 'زكاة الركاز (الخمس)' : 'زكاة المعادن',
      categoryKey: 'minerals',
      totalWealth: amount,
      zakatAmount: _result!.zakatAmount,
      currency: zakatProv.currency,
      reachedNisab: _result!.reachedNisab,
      notes: _result!.explanation,
    );

    final pdfBytes = await PdfService.generateZakatReceipt(record);
    await PdfService.shareOrPrintPdf(pdfBytes, 'zakat_minerals_receipt.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final zakatProv = Provider.of<ZakatProvider>(context);
    final favProv = Provider.of<FavoritesProvider>(context);
    const favId = 'calc_minerals';
    final isFav = favProv.isFavorite(favId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('زكاة الركاز والمعادن'),
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
                  title: 'زكاة الركاز والمعادن',
                  subtitle: 'حساب ما يجب في الركاز والمعادن المستخرجة',
                  type: 'calculator',
                  route: '/minerals_calc',
                  imagePath: 'assets/images/minral.png',
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
                      child: Image.asset('assets/images/minral.png'),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ما يجب في الركاز والمعادن',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 4),
                          Text(
                            'في الركاز الخُمس (20%) فور استخراجه بلا اشتراط حول، والمعادن ربع العشر (2.5%).',
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

            // Type selector
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('الركاز (دفين الجاهلية) - 20%'),
                    selected: _isRikaz,
                    selectedColor: AppColors.goldAccent,
                    onSelected: (val) => setState(() => _isRikaz = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('المعادن والمستخرجات - 2.5%'),
                    selected: !_isRikaz,
                    selectedColor: AppColors.goldAccent,
                    onSelected: (val) => setState(() => _isRikaz = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'إجمالي القيمة المستخرجة المقومة',
                suffixText: zakatProv.currency,
                prefixIcon: const Icon(Icons.diamond_outlined, color: AppColors.goldDark),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('احسب الواجب إخراجه', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),

            if (_isCalculated && _result != null) ...[
              Card(
                color: AppColors.emeraldSubtle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.emeraldPrimary, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _result!.explanation,
                        style: const TextStyle(fontSize: 14, color: AppColors.emeraldDark),
                      ),
                      const Divider(height: 24),
                      const Text(
                        'المقدار الواجب إخراجه فوراً:',
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

            const SizedBox(height: 24),

            // Sharia Article 48 Details (from web project)
            const Card(
              child: ExpansionTile(
                initiallyExpanded: false,
                title: Text(
                  'مصارف الركاز والمعادن (مادة 48 شرعية وقانونية)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.emeraldPrimary),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('1. سهم الله: ويصرف في مصالح المسلمين العامة كالطرق والمستشفيات والمدارس.'),
                        SizedBox(height: 6),
                        Text('2. سهم الرسول: لولي الأمر وله كل تصرف فيها بما يحقق المصلحة.'),
                        SizedBox(height: 6),
                        Text('3. ذوو القربى من بني هاشم: الذين حرمت عليهم الصدقة فجعل الله لهم الخمس.'),
                        SizedBox(height: 6),
                        Text('4. يتامى المسلمين: بمن فيهم يتامى ذوي القربى.'),
                        SizedBox(height: 6),
                        Text('5. عموم مساكين وفقراء المسلمين.'),
                        SizedBox(height: 6),
                        Text('6. ابن السبيل المنقطع عن نفقته.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
