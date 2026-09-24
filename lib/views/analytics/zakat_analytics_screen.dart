import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/zakat_record.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/hawl_provider.dart';
import '../../providers/auth_provider.dart';
import '../history/zakat_history_screen.dart';
import 'widgets/zakat_donut_chart.dart';
import 'widgets/zakat_bar_chart.dart';
import 'widgets/hawl_progress_gauge.dart';

class ZakatAnalyticsScreen extends StatelessWidget {
  const ZakatAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final zakatProv = Provider.of<ZakatProvider>(context);
    final hawlProv = Provider.of<HawlProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final records = zakatProv.records;

    // Calculate aggregated statistics
    double totalZakat = 0.0;
    int reachedNisabCount = 0;
    final Map<String, double> categoryZakatMap = {};

    for (final rec in records) {
      if (rec.reachedNisab) {
        reachedNisabCount++;
        totalZakat += rec.zakatAmount;
      }

      final catName = rec.typeName;
      categoryZakatMap[catName] = (categoryZakatMap[catName] ?? 0) + (rec.reachedNisab ? rec.zakatAmount : 0);
    }

    // Colors palette for categories
    final List<Color> palette = [
      AppColors.emeraldPrimary,
      AppColors.goldAccent,
      Colors.teal,
      Colors.amber.shade700,
      Colors.blueGrey,
      Colors.indigo,
      Colors.deepOrange,
      Colors.brown,
      Colors.purple,
    ];

    int colorIdx = 0;
    final List<ChartDataSegment> chartSegments = [];
    categoryZakatMap.forEach((category, amount) {
      if (amount > 0) {
        chartSegments.add(
          ChartDataSegment(
            label: category,
            value: amount,
            color: palette[colorIdx % palette.length],
          ),
        );
        colorIdx++;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('التحليلات والرسوم البيانية'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'سجل العمليات',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ZakatHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'تصدير كشف الحساب السنوي',
            onPressed: () => _exportAnnualPdf(context, records, zakatProv.currency),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: context.rPadding(horizontal: 16, vertical: 16),
        child: ResponsiveConstraint(
          maxWidth: 800,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // KPI Summary Row
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'إجمالي الزكاة الواجبة',
                    value: '${AppFormatters.formatNumber(totalZakat, decimals: 0)} ${zakatProv.currency}',
                    icon: Icons.payments_outlined,
                    color: AppColors.emeraldPrimary,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'العمليات المكتملة',
                    value: '$reachedNisabCount من أصل ${records.length}',
                    icon: Icons.done_all,
                    color: AppColors.goldAccent,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Annual Statement Export Banner
            if (records.isNotEmpty) ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: AppColors.goldAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.goldAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.description_outlined, color: AppColors.goldDark, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'كشف الحساب السنوي',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'تصدير تقرير موثق بجميع العمليات',
                              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _exportAnnualPdf(context, records, zakatProv.currency),
                        icon: const Icon(Icons.picture_as_pdf, size: 14),
                        label: const Text('تصدير PDF', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emeraldPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 1. Donut Distribution Chart Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pie_chart, color: AppColors.emeraldPrimary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'توزيع مبالغ الزكاة حسب الأصناف',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ZakatDonutChart(
                      segments: chartSegments,
                      totalAmount: totalZakat,
                      currency: zakatProv.currency,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Bar Chart Comparison Card
            if (chartSegments.length > 1) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bar_chart, color: AppColors.goldDark, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'مقارنة مبالغ الزكاة بين الفئات',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ZakatBarChart(
                        items: chartSegments,
                        currency: zakatProv.currency,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3. Hawl Lunar Cycle Gauge Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.timelapse, color: AppColors.emeraldPrimary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'مسار الحول الهجري القمري (354 يوماً)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (hawlProv.startDate == null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.calendar_month, size: 40, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text(
                                'لم يتم تحديد تاريخ بدء الحول بعد. يمكنك ضبطه من متتبع الحول في الشاشة الرئيسية.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 340;
                          final gaugeWidget = HawlProgressGauge(
                            daysPassed: hawlProv.daysPassed,
                            daysRemaining: hawlProv.daysRemaining,
                            isCompleted: hawlProv.isHawlCompleted,
                            dueDate: hawlProv.expectedDueDate,
                          );

                          final detailsWidget = Column(
                            crossAxisAlignment: isNarrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                            children: [
                              Text(
                                hawlProv.isHawlCompleted
                                    ? 'اكتملت مدة الحول الشرعي!'
                                    : 'الحول جارٍ بدقة',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                textAlign: isNarrow ? TextAlign.center : TextAlign.start,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'تاريخ بدء النصاب: ${AppFormatters.formatDate(hawlProv.startDate!)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                textAlign: isNarrow ? TextAlign.center : TextAlign.start,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'تاريخ الاستحقاق: ${AppFormatters.formatDate(hawlProv.expectedDueDate!)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                textAlign: isNarrow ? TextAlign.center : TextAlign.start,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: hawlProv.isHawlCompleted
                                      ? Colors.red.withValues(alpha: 0.1)
                                      : AppColors.emeraldPrimary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  hawlProv.isHawlCompleted
                                      ? 'الزكاة واجبة الإخراج حالاً'
                                      : 'متبقي ${hawlProv.daysRemaining} يوماً',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: hawlProv.isHawlCompleted ? Colors.red : AppColors.emeraldPrimary,
                                  ),
                                ),
                              ),
                            ],
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                gaugeWidget,
                                const SizedBox(height: 14),
                                detailsWidget,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              gaugeWidget,
                              const SizedBox(width: 16),
                              Expanded(child: detailsWidget),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 5),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAnnualPdf(BuildContext context, List<ZakatRecord> records, String currency) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد عمليات لتصدير كشف الحساب السنوي'),
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
            'تتضمن السجلات أكثر من عملة ($currencies).\n\n'
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
    final userName = authProv.isAuthenticated && authProv.user?.name.isNotEmpty == true
        ? authProv.user!.name
        : 'المزكي الكريم';

    final bytes = await PdfService.generateAnnualStatementPdf(
      records: records,
      userName: userName,
      currency: currency,
    );

    if (!context.mounted) return;
    await PdfService.showExportOptions(
      context,
      pdfData: bytes,
      filename: 'annual_zakat_statement_${DateTime.now().year}.pdf',
      title: 'كشف الحساب الزكوي السنوي المجمع',
    );
  }
}
