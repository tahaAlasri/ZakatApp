import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/pdf_service.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';
import '../utils/auth_guard.dart';
import '../utils/responsive_helper.dart';
import '../../models/zakat_record.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../views/payment/zakat_payment_screen.dart';

/// Reusable component for displaying Zakat calculation results
/// along with standard action buttons: Save to Record, Export PDF, and Share.
class ZakatResultCard extends StatelessWidget {
  final ZakatCalculationResult result;
  final String typeName;
  final String categoryKey;
  final double totalWealth;
  final String currency;
  final String pdfFileName;
  final String pdfTitle;
  final String? zakatInKindDescription;
  final VoidCallback? onSaved;
  final double? appliedPrice;
  final int? goldKarat;
  final Map<String, dynamic>? inputs;
  final String? calculationPolicy;

  const ZakatResultCard({
    super.key,
    required this.result,
    required this.typeName,
    required this.categoryKey,
    required this.totalWealth,
    required this.currency,
    required this.pdfFileName,
    required this.pdfTitle,
    this.zakatInKindDescription,
    this.onSaved,
    this.appliedPrice,
    this.goldKarat,
    this.inputs,
    this.calculationPolicy,
  });

  ZakatRecord _buildRecord() {
    return ZakatRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: AuthService.currentUser?.id,
      typeName: typeName,
      categoryKey: categoryKey,
      totalWealth: totalWealth,
      zakatAmount: result.zakatAmount,
      zakatInKindDescription: zakatInKindDescription ?? result.zakatInKindDescription,
      currency: currency,
      reachedNisab: result.reachedNisab,
      notes: result.explanation,
      appliedPrice: appliedPrice ?? result.appliedPrice,
      nisabThreshold: result.nisabThreshold,
      goldKarat: goldKarat ?? result.goldKarat,
      inputs: inputs ?? {
        'totalWealth': totalWealth,
        'appliedPrice': appliedPrice ?? result.appliedPrice,
        'goldKarat': goldKarat ?? result.goldKarat,
        'nisabThreshold': result.nisabThreshold,
        'currency': currency,
      },
      calculationPolicy: calculationPolicy ?? 'السياسة الشرعية المعتمدة',
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (!authProv.isAuthenticated) {
      final isAuth = await AuthGuard.requireAuth(
        context,
        title: 'حفظ العملية في السجل',
        message: 'يتطلب حفظ العمليات في سجل حساباتك تسجيل الدخول لربط سجلاتك بحسابك والرجوع إليها في أي وقت.',
        icon: Icons.save_outlined,
      );
      if (!isAuth) return;
      if (!context.mounted) return;
    }

    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);
    final snapshot = zakatProv.currentPriceSnapshot;
    final record = _buildRecord().copyWith(
      priceSource: snapshot.source,
      priceUpdatedAt: snapshot.updatedAt,
    );
    await zakatProv.saveRecord(record);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ العملية في سجل الحسابات بنجاح'),
        backgroundColor: AppColors.success,
      ),
    );
    onSaved?.call();
  }

  Future<void> _handleExportPdf(BuildContext context) async {
    final record = _buildRecord();
    final pdfBytes = await PdfService.generateZakatReceipt(record);
    if (!context.mounted) return;

    await PdfService.showExportOptions(
      context,
      pdfData: pdfBytes,
      filename: pdfFileName.endsWith('.pdf') ? pdfFileName : '$pdfFileName.pdf',
      title: pdfTitle,
    );
  }

  Future<void> _handleShare() async {
    final inKind = zakatInKindDescription ?? result.zakatInKindDescription;
    await PdfService.shareSummaryText(
      title: typeName,
      totalWealth: totalWealth,
      reachedNisab: result.reachedNisab,
      zakatAmount: result.zakatAmount,
      inKindDescription: inKind,
      currency: currency,
      notes: result.explanation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inKind = zakatInKindDescription ?? result.zakatInKindDescription;
    final isReached = result.reachedNisab;

    final cardBgColor = isDark
        ? (isReached
            ? AppColors.emeraldPrimary.withValues(alpha: 0.22)
            : Colors.orange.withValues(alpha: 0.14))
        : (isReached ? AppColors.emeraldSubtle : Colors.orange.shade50);

    final borderColor = isReached
        ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
        : (isDark ? Colors.orangeAccent.withValues(alpha: 0.7) : Colors.orange);

    final statusIcon = isReached ? Icons.check_circle : Icons.info;
    final statusIconColor = isReached
        ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
        : (isDark ? Colors.orangeAccent : Colors.orange.shade800);

    final statusTextColor = isReached
        ? (isDark ? AppColors.emeraldLight : AppColors.emeraldDark)
        : (isDark ? Colors.orangeAccent : Colors.orange.shade900);

    final explanationTextColor = isDark
        ? AppColors.textSecondaryDark
        : (isReached ? AppColors.emeraldDark : Colors.brown);

    final dueAmountColor = isDark ? AppColors.goldAccent : AppColors.emeraldPrimary;

    return Card(
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: context.rPadding(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status row
            Row(
              children: [
                Icon(
                  statusIcon,
                  color: statusIconColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isReached ? 'اكتمل النصاب الشرعي' : 'لم يكتمل النصاب',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Explanation text
            Text(
              result.explanation,
              style: TextStyle(
                fontSize: 14,
                color: explanationTextColor,
                height: 1.4,
              ),
            ),

            // Due Zakat Details
            if (isReached) ...[
              Divider(height: 24, color: isDark ? Colors.white24 : Colors.black12),
              Text(
                'المقدار الواجب إخراجه:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              if (inKind.isNotEmpty)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    inKind,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: dueAmountColor,
                    ),
                  ),
                )
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    AppFormatters.formatCurrency(result.zakatAmount, currency: currency),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: dueAmountColor,
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleSave(context),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('حفظ بالسجل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.emeraldPrimary : AppColors.emeraldPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  onPressed: () => _handleExportPdf(context),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  icon: Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 20,
                    color: isDark ? AppColors.goldAccent : AppColors.emeraldPrimary,
                  ),
                  tooltip: 'تصدير وحفظ PDF',
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  onPressed: _handleShare,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  icon: Icon(
                    Icons.share_outlined,
                    size: 20,
                    color: isDark ? AppColors.goldAccent : AppColors.emeraldPrimary,
                  ),
                  tooltip: 'مشاركة النتيجة',
                ),
              ],
            ),

            if (isReached && result.zakatAmount > 0) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ZakatPaymentScreen(
                        suggestedAmount: result.zakatAmount,
                        zakatType: typeName,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.payments_outlined, color: AppColors.emeraldPrimary, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'سداد وإخراج الزكاة (الحسابات المعتمدة)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.emeraldPrimary),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.emeraldPrimary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
