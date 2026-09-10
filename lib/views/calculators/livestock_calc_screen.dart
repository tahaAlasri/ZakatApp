import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/pdf_service.dart';
import '../../models/zakat_record.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class LivestockCalcScreen extends StatefulWidget {
  final int initialTabIndex;
  const LivestockCalcScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LivestockCalcScreen> createState() => _LivestockCalcScreenState();
}

class _LivestockCalcScreenState extends State<LivestockCalcScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _camelsController = TextEditingController();
  final _cowsController = TextEditingController();
  final _sheepController = TextEditingController();

  ZakatCalculationResult? _camelsResult;
  ZakatCalculationResult? _cowsResult;
  ZakatCalculationResult? _sheepResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _camelsController.dispose();
    _cowsController.dispose();
    _sheepController.dispose();
    super.dispose();
  }

  void _calculateCamels() {
    final count = int.tryParse(_camelsController.text.trim()) ?? 0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    setState(() {
      _camelsResult = zakatProv.calculateCamelsZakat(count);
    });
  }

  void _calculateCows() {
    final count = int.tryParse(_cowsController.text.trim()) ?? 0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    setState(() {
      _cowsResult = zakatProv.calculateCowsZakat(count);
    });
  }

  void _calculateSheep() {
    final count = int.tryParse(_sheepController.text.trim()) ?? 0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    setState(() {
      _sheepResult = zakatProv.calculateSheepZakat(count);
    });
  }

  void _saveRecord(String typeName, String key, int count, ZakatCalculationResult result) async {
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final record = ZakatRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      typeName: typeName,
      categoryKey: key,
      totalWealth: count.toDouble(),
      zakatAmount: 0,
      zakatInKindDescription: result.zakatInKindDescription,
      currency: 'رأس',
      reachedNisab: result.reachedNisab,
      notes: result.explanation,
    );

    await zakatProv.saveRecord(record);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ $typeName في السجل بنجاح'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _exportPdf(String typeName, String key, int count, ZakatCalculationResult result) async {
    final record = ZakatRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      typeName: typeName,
      categoryKey: key,
      totalWealth: count.toDouble(),
      zakatAmount: 0,
      zakatInKindDescription: result.zakatInKindDescription,
      currency: 'رأس',
      reachedNisab: result.reachedNisab,
      notes: result.explanation,
    );

    final pdfBytes = await PdfService.generateZakatReceipt(record);
    await PdfService.shareOrPrintPdf(pdfBytes, 'zakat_${key}_receipt.pdf');
  }

  Widget _buildResultBox(
    String typeName,
    String key,
    int count,
    ZakatCalculationResult? result,
    VoidCallback onSave,
    VoidCallback onPdf,
  ) {
    if (result == null) return const SizedBox.shrink();

    return Card(
      color: result.reachedNisab ? AppColors.emeraldSubtle : Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: result.reachedNisab ? AppColors.emeraldPrimary : Colors.orange,
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
                  result.reachedNisab ? Icons.check_circle : Icons.info,
                  color: result.reachedNisab ? AppColors.emeraldPrimary : Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Text(
                  result.reachedNisab ? 'اكتمل النصاب الشرعي' : 'لم يكتمل النصاب',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: result.reachedNisab ? AppColors.emeraldDark : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              result.explanation,
              style: TextStyle(
                fontSize: 14,
                color: result.reachedNisab ? AppColors.emeraldDark : Colors.brown,
              ),
            ),
            if (result.reachedNisab && result.zakatInKindDescription.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'الواجب إخراجه عيناً:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                result.zakatInKindDescription,
                style: const TextStyle(
                  fontSize: 20,
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
                    onPressed: onSave,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('حفظ بالسجل'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPdf,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final favProv = Provider.of<FavoritesProvider>(context);
    const favId = 'calc_livestock';
    final isFav = favProv.isFavorite(favId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('زكاة بهيمة الأنعام'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.goldAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: 'الإبل (الجمال)'),
            Tab(text: 'البقر والجاموس'),
            Tab(text: 'الغنم والماعز'),
          ],
        ),
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
                  title: 'زكاة بهيمة الأنعام',
                  subtitle: 'حاسبة زكاة الإبل والبقر والغنم والماعز',
                  type: 'calculator',
                  route: '/livestock_calc',
                  imagePath: 'assets/images/camel.png',
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Camels
          SingleChildScrollView(
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
                          child: Image.asset('assets/images/camel.png'),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('نصاب الإبل يبدأ من 5 رؤوس',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('أن تكون سائمة وحال عليها الحول، وتخرج شاة عن كل خمس حتى 24، ثم من جنس الإبل.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _camelsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد الإبل السائمة',
                    hintText: 'أدخل عدد رؤوس الإبل',
                    suffixText: 'رأس',
                    prefixIcon: Icon(Icons.numbers, color: AppColors.emeraldPrimary),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _calculateCamels,
                  icon: const Icon(Icons.calculate),
                  label: const Text('احسب زكاة الإبل', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 20),
                _buildResultBox(
                  'زكاة الإبل',
                  'camels',
                  int.tryParse(_camelsController.text) ?? 0,
                  _camelsResult,
                  () => _saveRecord('زكاة الإبل', 'camels', int.tryParse(_camelsController.text) ?? 0, _camelsResult!),
                  () => _exportPdf('زكاة الإبل', 'camels', int.tryParse(_camelsController.text) ?? 0, _camelsResult!),
                ),
              ],
            ),
          ),

          // Tab 2: Cows
          SingleChildScrollView(
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
                          child: Image.asset('assets/images/cow.png'),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('نصاب البقر يبدأ من 30 بقرة',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('في كل 30 تبيع أو تبيعة (أتم سنة)، وفي كل 40 مسنة (أتمت سنتين).',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _cowsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد البقر والجاموس السائم',
                    hintText: 'أدخل عدد رؤوس البقر',
                    suffixText: 'رأس',
                    prefixIcon: Icon(Icons.numbers, color: AppColors.emeraldPrimary),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _calculateCows,
                  icon: const Icon(Icons.calculate),
                  label: const Text('احسب زكاة البقر', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 20),
                _buildResultBox(
                  'زكاة البقر',
                  'cows',
                  int.tryParse(_cowsController.text) ?? 0,
                  _cowsResult,
                  () => _saveRecord('زكاة البقر', 'cows', int.tryParse(_cowsController.text) ?? 0, _cowsResult!),
                  () => _exportPdf('زكاة البقر', 'cows', int.tryParse(_cowsController.text) ?? 0, _cowsResult!),
                ),
              ],
            ),
          ),

          // Tab 3: Sheep & Goats
          SingleChildScrollView(
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
                          child: Image.asset('assets/images/goat.png'),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('نصاب الغنم يبدأ من 40 شاة',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('من 40 إلى 120 شاة واحدة، ثم شاتان إلى 200، ثم 3 شياه إلى 399، ثم شاة في كل مئة.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _sheepController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد الغنم والضأن والماعز السائمة',
                    hintText: 'أدخل عدد رؤوس الغنم',
                    suffixText: 'رأس',
                    prefixIcon: Icon(Icons.numbers, color: AppColors.emeraldPrimary),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _calculateSheep,
                  icon: const Icon(Icons.calculate),
                  label: const Text('احسب زكاة الغنم', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 20),
                _buildResultBox(
                  'زكاة الغنم',
                  'sheep',
                  int.tryParse(_sheepController.text) ?? 0,
                  _sheepResult,
                  () => _saveRecord('زكاة الغنم', 'sheep', int.tryParse(_sheepController.text) ?? 0, _sheepResult!),
                  () => _exportPdf('زكاة الغنم', 'sheep', int.tryParse(_sheepController.text) ?? 0, _sheepResult!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
