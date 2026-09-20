import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/formatters.dart';
import '../../models/zakat_record.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/auth_provider.dart';

class ZakatHistoryScreen extends StatefulWidget {
  const ZakatHistoryScreen({super.key});

  @override
  State<ZakatHistoryScreen> createState() => _ZakatHistoryScreenState();
}

class _ZakatHistoryScreenState extends State<ZakatHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryGroup = 'all';
  bool _onlyReachedNisab = false;
  bool _sortNewestFirst = true;

  final List<Map<String, String>> _categoryGroups = const [
    {'id': 'all', 'label': 'جميع الأصناف'},
    {'id': 'money', 'label': 'المال والنقود'},
    {'id': 'gold_silver', 'label': 'الذهب والفضة'},
    {'id': 'livestock', 'label': 'الأنعام والمواشي'},
    {'id': 'crops', 'label': 'الحبوب والزروع'},
    {'id': 'fitr', 'label': 'زكاة الفطر'},
    {'id': 'activities', 'label': 'التجارة والمستغلات'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesGroup(ZakatRecord rec, String groupId) {
    if (groupId == 'all') return true;

    final key = rec.categoryKey.toLowerCase();
    final name = rec.typeName.toLowerCase();

    switch (groupId) {
      case 'money':
        return key.contains('money') || name.contains('المال') || name.contains('نقود');
      case 'gold_silver':
        return key.contains('gold') || key.contains('silver') || name.contains('ذهب') || name.contains('فضة');
      case 'livestock':
        return key.contains('camel') ||
            key.contains('cow') ||
            key.contains('goat') ||
            key.contains('livestock') ||
            name.contains('إبل') ||
            name.contains('بقر') ||
            name.contains('غنم') ||
            name.contains('أنعام');
      case 'crops':
        return key.contains('crop') || name.contains('زروع') || name.contains('ثمار') || name.contains('حبوب');
      case 'fitr':
        return key.contains('fitr') || name.contains('فطر');
      case 'activities':
        return key.contains('trade') ||
            key.contains('mineral') ||
            key.contains('field') ||
            name.contains('تجارة') ||
            name.contains('ركاز') ||
            name.contains('مستغلات');
      default:
        return true;
    }
  }

  Future<void> _exportAnnualStatement(BuildContext context, List<ZakatRecord> records) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد عمليات مسجلة لتصدير كشف الحساب'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (PdfService.hasMixedCurrencies(records)) {
      final currencies = records.map((r) => r.currency).toSet().join('، ');
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.currency_exchange, color: AppColors.warning),
              SizedBox(width: 8),
              Text('سجلات بعملات متعددة'),
            ],
          ),
          content: Text(
            'تتضمن السجلات المختارة أكثر من عملة ($currencies).\n\n'
            'وفقاً للضوابط الشرعية، لا يمكن جمع مبالغ بعملات مختلفة كرقم إجمالي واحد دون تحديد سعر تحويل.\n\n'
            'هل ترغب في متابعة إصدار التقرير مع تصنيف وتجميع المبالغ لكل عملة على حدة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('متابعة بالتجميع حسب العملة'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (!context.mounted) return;
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    final userName = authProv.isAuthenticated && authProv.user?.name.isNotEmpty == true
        ? authProv.user!.name
        : 'المزكي الكريم';

    final bytes = await PdfService.generateAnnualStatementPdf(
      records: records,
      userName: userName,
      currency: zakatProv.currency,
    );

    if (!context.mounted) return;
    await PdfService.showExportOptions(
      context,
      pdfData: bytes,
      filename: 'annual_zakat_statement_${DateTime.now().year}.pdf',
      title: 'كشف الحساب الزكوي السنوي المجمع',
    );
  }

  @override
  Widget build(BuildContext context) {
    final zakatProv = Provider.of<ZakatProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter records
    List<ZakatRecord> filtered = zakatProv.records.where((rec) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = rec.typeName.toLowerCase().contains(q);
        final matchesNotes = rec.notes.toLowerCase().contains(q);
        final matchesInKind = rec.zakatInKindDescription.toLowerCase().contains(q);
        if (!matchesName && !matchesNotes && !matchesInKind) return false;
      }

      // 2. Category Group
      if (!_matchesGroup(rec, _selectedCategoryGroup)) return false;

      // 3. Nisab threshold check
      if (_onlyReachedNisab && !rec.reachedNisab) return false;

      return true;
    }).toList();

    // Sort records
    filtered.sort((a, b) => _sortNewestFirst ? b.date.compareTo(a.date) : a.date.compareTo(b.date));

    // KPI Metrics for filtered list (grouped by currency)
    final Map<String, double> filteredZakatByCurrency = {};
    int filteredNisabCount = 0;
    for (final r in filtered) {
      if (r.reachedNisab) {
        filteredNisabCount++;
        final curr = r.currency.isNotEmpty ? r.currency : zakatProv.currency;
        filteredZakatByCurrency[curr] = (filteredZakatByCurrency[curr] ?? 0.0) + r.zakatAmount;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل العمليات الزكوية الشامل'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير كشف الحساب السنوي المجمع',
            onPressed: () => _exportAnnualStatement(context, filtered),
          ),
          if (zakatProv.records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'مسح كامل السجل',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('مسح السجل بالكامل'),
                    content: const Text('هل أنت متأكد من رغبتك في حذف جميع العمليات المحفوظة؟ لا يمكن التراجع عن هذا الإجراء.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('مسح الكل'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await zakatProv.clearAll();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم مسح كامل السجل بنجاح'),
                        backgroundColor: AppColors.emeraldPrimary,
                      ),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Controls Card
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Input Field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث في السجل (اسم الزكاة، الملاحظات، المقدار)...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.emeraldPrimary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 10),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categoryGroups.map((group) {
                      final isSelected = _selectedCategoryGroup == group['id'];
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(group['label']!),
                          selected: isSelected,
                          selectedColor: AppColors.emeraldPrimary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.emeraldPrimary : null,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategoryGroup = group['id']!);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Quick Filters Row (Nisab Switch & Sort)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Switch.adaptive(
                          value: _onlyReachedNisab,
                          activeColor: AppColors.emeraldPrimary,
                          onChanged: (val) => setState(() => _onlyReachedNisab = val),
                        ),
                        const Text('البالغ للنصاب فقط', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    TextButton.icon(
                      icon: Icon(
                        _sortNewestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 16,
                        color: AppColors.emeraldPrimary,
                      ),
                      label: Text(
                        _sortNewestFirst ? 'الأحدث أولاً' : 'الأقدم أولاً',
                        style: const TextStyle(fontSize: 12, color: AppColors.emeraldPrimary),
                      ),
                      onPressed: () => setState(() => _sortNewestFirst = !_sortNewestFirst),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Summary Stats Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? AppColors.darkCard : AppColors.emeraldSubtle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calculate_outlined, size: 18, color: AppColors.emeraldPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'العمليات: ${filtered.length} (مستوفية: $filteredNisabCount)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  filteredZakatByCurrency.isEmpty
                      ? 'الزكاة: 0 ${zakatProv.currency}'
                      : 'الزكاة: ${filteredZakatByCurrency.entries.map((e) => '${AppFormatters.formatNumber(e.value, decimals: 0)} ${e.key}').join(' | ')}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.emeraldPrimary),
                ),
              ],
            ),
          ),

          // Records List / Empty State
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty || _selectedCategoryGroup != 'all'
                                ? Icons.filter_list_off
                                : Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty || _selectedCategoryGroup != 'all'
                                ? 'لا توجد عمليات تطابق البحث أو الفلتر المحدد'
                                : 'سجل العمليات فارغ حتى الآن',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty || _selectedCategoryGroup != 'all'
                                ? 'جرّب تعديل نص البحث أو اختيار صنف آخر'
                                : 'عند إتمامك لأي حساب زكوي وحفظه، سيظهر تلقائياً هنا في السجل.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final rec = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: rec.reachedNisab
                                ? AppColors.emeraldPrimary.withValues(alpha: 0.2)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Type and Status Badge
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: rec.reachedNisab
                                            ? AppColors.emeraldSubtle
                                            : Colors.orange.shade50,
                                        child: Icon(
                                          rec.reachedNisab ? Icons.check_circle : Icons.info_outline,
                                          color: rec.reachedNisab ? AppColors.emeraldPrimary : Colors.orange,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        rec.typeName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: rec.reachedNisab
                                          ? AppColors.emeraldPrimary.withValues(alpha: 0.1)
                                          : Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      rec.reachedNisab ? 'بلغ النصاب' : 'دون النصاب',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: rec.reachedNisab ? AppColors.emeraldPrimary : Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Middle: Details & Numbers
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    if (rec.totalWealth > 0)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('الوعاء / المال الخاضع:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text(
                                            '${AppFormatters.formatNumber(rec.totalWealth, decimals: 0)} ${rec.currency}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    if (rec.totalWealth > 0) const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('الزكاة الواجبة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        Text(
                                          rec.reachedNisab
                                              ? '${AppFormatters.formatNumber(rec.zakatAmount, decimals: 2)} ${rec.currency}'
                                              : 'لا تجب الزكاة',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: rec.reachedNisab ? AppColors.emeraldPrimary : Colors.brown,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (rec.zakatInKindDescription.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('المقدار عيناً:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              rec.zakatInKindDescription,
                                              textAlign: TextAlign.left,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.goldDark),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (rec.appliedPrice != null && rec.appliedPrice! > 0) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            rec.goldKarat != null
                                                ? 'السعر المعتمد (عيار ${rec.goldKarat}):'
                                                : 'السعر المعتمد للوحدة:',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                          Text(
                                            '${AppFormatters.formatNumber(rec.appliedPrice!, decimals: 2)} ${rec.currency}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (rec.nisabThreshold != null && rec.nisabThreshold! > 0) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('النصاب وقت العملية:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          Text(
                                            '${AppFormatters.formatNumber(rec.nisabThreshold!, decimals: 2)} ${rec.currency}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Bottom Row: Date & Action Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    AppFormatters.formatDate(rec.date),
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.share_outlined, size: 20, color: AppColors.emeraldPrimary),
                                        tooltip: 'مشاركة الملخص',
                                        onPressed: () {
                                          PdfService.shareSummaryText(
                                            title: rec.typeName,
                                            totalWealth: rec.totalWealth,
                                            zakatAmount: rec.zakatAmount,
                                            currency: rec.currency,
                                            reachedNisab: rec.reachedNisab,
                                            inKindDescription: rec.zakatInKindDescription,
                                            notes: rec.notes,
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppColors.goldDark),
                                        tooltip: 'تصدير إيصال PDF',
                                        onPressed: () async {
                                          final bytes = await PdfService.generateZakatReceipt(rec);
                                          if (!context.mounted) return;
                                          await PdfService.showExportOptions(
                                            context,
                                            pdfData: bytes,
                                            filename: 'zakat_${rec.id}.pdf',
                                            title: 'إيصال ${rec.typeName}',
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                                        tooltip: 'حذف',
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('حذف العملية'),
                                              content: Text('هل ترغب في حذف حساب "${rec.typeName}" من السجل؟'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text('إلغاء'),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('حذف'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            await zakatProv.deleteRecord(rec.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('تم حذف العملية من السجل')),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: filtered.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3)),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _exportAnnualStatement(context, filtered),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('تصدير كشف الحساب السنوي المجمع (PDF)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          : null,
    );
  }
}
