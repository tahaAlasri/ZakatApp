import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/zakat_record.dart';
import '../../models/assistance_request.dart';
import '../constants/app_colors.dart';
import 'pdf/pdf_receipt_builder.dart';

export 'pdf/pdf_theme_helper.dart';
export 'pdf/pdf_receipt_builder.dart';

class PdfService {
  /// Generate a single Zakat receipt PDF document
  static Future<Uint8List> generateZakatReceipt(
    ZakatRecord record, {
    String userName = 'المزكي الكريم',
  }) {
    return PdfReceiptBuilder.generateZakatReceipt(record, userName: userName);
  }

  /// Generate an official assistance request letter PDF
  static Future<Uint8List> generateAssistancePdf(AssistanceRequest request) {
    return PdfReceiptBuilder.generateAssistancePdf(request);
  }

  /// Check if the records list contains multiple distinct currencies
  static bool hasMixedCurrencies(List<ZakatRecord> records) {
    final currencies = records
        .map((r) => r.currency.trim())
        .where((c) => c.isNotEmpty)
        .toSet();
    return currencies.length > 1;
  }

  /// Generate an official Annual Zakat Statement PDF aggregating records
  static Future<Uint8List> generateAnnualStatementPdf({
    required List<ZakatRecord> records,
    String userName = 'المزكي الكريم',
    String? hijriYear,
    String? currency,
    bool preventMixedCurrencies = false,
  }) {
    return PdfReceiptBuilder.generateAnnualStatementPdf(
      records: records,
      userName: userName,
      hijriYear: hijriYear,
      currency: currency,
      preventMixedCurrencies: preventMixedCurrencies,
    );
  }

  /// Save PDF file to device storage
  static Future<String?> savePdfToDevice(Uint8List pdfData, String filename) async {
    try {
      Directory? targetDir;

      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          targetDir = downloadDir;
        } else {
          targetDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        targetDir = await getApplicationDocumentsDirectory();
      } else {
        targetDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }

      targetDir ??= await getApplicationDocumentsDirectory();

      if (!filename.toLowerCase().endsWith('.pdf')) {
        filename = '$filename.pdf';
      }

      final filePath = '${targetDir.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(pdfData, flush: true);
      return filePath;
    } catch (e) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        if (!filename.toLowerCase().endsWith('.pdf')) {
          filename = '$filename.pdf';
        }
        final fallbackPath = '${appDir.path}/$filename';
        final file = File(fallbackPath);
        await file.writeAsBytes(pdfData, flush: true);
        return fallbackPath;
      } catch (_) {
        return null;
      }
    }
  }

  /// Present modern modal bottom sheet with Export / Print / Share options
  static Future<void> showExportOptions(
    BuildContext context, {
    required Uint8List pdfData,
    required String filename,
    String title = 'خيارات تصدير التقرير',
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.emeraldPrimary.withValues(alpha: 0.3)
                          : AppColors.emeraldSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.emeraldPrimary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          filename,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white60 : Colors.grey.shade600),
                    onPressed: () => Navigator.of(bottomSheetContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(color: isDark ? Colors.white12 : Colors.grey.shade200, height: 1),
              const SizedBox(height: 16),

              // 1. Save to Device
              _buildOptionCard(
                isDark: isDark,
                icon: Icons.download_rounded,
                iconColor: AppColors.emeraldLight,
                iconBgColor: isDark
                    ? AppColors.emeraldPrimary.withValues(alpha: 0.25)
                    : AppColors.emeraldSubtle,
                title: 'حفظ في الجهاز (التنزيلات)',
                subtitle: 'تنزيل وحفظ نسخة PDF مباشرة في مساحة تخزين هاتفك',
                onTap: () async {
                  Navigator.of(bottomSheetContext).pop();
                  final savedPath = await savePdfToDevice(pdfData, filename);
                  if (!context.mounted) return;
                  if (savedPath != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.emeraldDark,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 4),
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'تم حفظ الملف بنجاح في الجهاز:\n$savedPath',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('تعذر حفظ الملف، يرجى التحقق من مساحة التخزين والأذونات.'),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),

              // 2. Share PDF
              _buildOptionCard(
                isDark: isDark,
                icon: Icons.share_rounded,
                iconColor: Colors.blue.shade600,
                iconBgColor: isDark
                    ? Colors.blue.shade900.withValues(alpha: 0.3)
                    : Colors.blue.shade50,
                title: 'مشاركة الملف',
                subtitle: 'إرسال التقرير عبر واتساب، تيليجرام، أو البريد الإلكتروني',
                onTap: () async {
                  Navigator.of(bottomSheetContext).pop();
                  await Printing.sharePdf(bytes: pdfData, filename: filename);
                },
              ),
              const SizedBox(height: 10),

              // 3. Preview & Print
              _buildOptionCard(
                isDark: isDark,
                icon: Icons.print_rounded,
                iconColor: AppColors.goldDark,
                iconBgColor: isDark
                    ? AppColors.goldDark.withValues(alpha: 0.2)
                    : AppColors.goldAccent.withValues(alpha: 0.15),
                title: 'معاينة وطباعة المستند',
                subtitle: 'استعراض التقرير أو إرساله للطابعة عبر شبكة Wi-Fi',
                onTap: () async {
                  Navigator.of(bottomSheetContext).pop();
                  await Printing.layoutPdf(
                    onLayout: (_) async => pdfData,
                    name: filename,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildOptionCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
            color: isDark ? AppColors.darkCard : AppColors.lightBg,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> shareOrPrintPdf(
    Uint8List pdfData,
    String filename, {
    BuildContext? context,
    String? title,
  }) async {
    if (context != null && context.mounted) {
      await showExportOptions(
        context,
        pdfData: pdfData,
        filename: filename,
        title: title ?? 'خيارات تصدير التقرير',
      );
    } else {
      await Printing.sharePdf(bytes: pdfData, filename: filename);
    }
  }

  static Future<void> shareSummaryText({
    required String title,
    required double totalWealth,
    required double zakatAmount,
    required String currency,
    required bool reachedNisab,
    String? inKindDescription,
    String? notes,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('🕌 *تفاصيل إقرار الزكاة الشرعية - الهيئة العامة للزكاة* 🕌');
    buffer.writeln('────────────────────');
    buffer.writeln('📋 *نوع الزكاة:* $title');
    if (totalWealth > 0) {
      buffer.writeln('💰 *إجمالي المال / الأصل:* ${totalWealth.toStringAsFixed(2)} $currency');
    }
    buffer.writeln('⚖️ *حالة النصاب:* ${reachedNisab ? "بلغ النصاب الشرعي ✅" : "لم يبلغ النصاب الشرعي ❌"}');
    if (reachedNisab) {
      if (inKindDescription != null && inKindDescription.isNotEmpty) {
        buffer.writeln('🎁 *المقدار الواجب إخراجه:* $inKindDescription');
      } else {
        buffer.writeln('💵 *المقدار الواجب إخراجه:* ${zakatAmount.toStringAsFixed(2)} $currency');
      }
    }
    if (notes != null && notes.isNotEmpty) {
      buffer.writeln('📝 *التفاصيل:* $notes');
    }
    buffer.writeln('────────────────────');
    buffer.writeln('تم الحساب والتوثيق عبر تطبيق *زكـــاتـي*');

    await Share.share(
      buffer.toString(),
      subject: 'إقرار حساب $title',
    );
  }

  static Future<void> shareLetterText({
    required String subject,
    required String letterText,
  }) async {
    await Share.share(
      letterText,
      subject: subject,
    );
  }
}
