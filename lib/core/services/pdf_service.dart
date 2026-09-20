import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hijri/hijri_calendar.dart';
import '../../models/zakat_record.dart';
import '../../models/assistance_request.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../database/preferences_service.dart';

class PdfService {
  /// Loads Arabic fonts with offline-first fallback:
  /// 1. GoogleFonts network/memory cache
  /// 2. Local asset fonts (assets/fonts/Cairo-Regular.ttf & Cairo-Bold.ttf)
  /// 3. Standard fallback
  static Future<({pw.Font regular, pw.Font bold})> _loadPdfFonts() async {
    try {
      final font = await PdfGoogleFonts.cairoRegular();
      final fontBold = await PdfGoogleFonts.cairoBold();
      return (regular: font, bold: fontBold);
    } catch (e) {
      debugPrint('PdfService: GoogleFonts failed, falling back to local asset fonts: $e');
    }

    try {
      final regularData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      return (
        regular: pw.Font.ttf(regularData),
        bold: pw.Font.ttf(boldData),
      );
    } catch (e) {
      debugPrint('PdfService: Local asset fonts failed, using helvetica fallback: $e');
    }

    return (
      regular: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );
  }

  static Future<Uint8List> generateZakatReceipt(ZakatRecord record, {String userName = 'المزكي الكريم'}) async {
    final pdf = pw.Document();
    final fonts = await _loadPdfFonts();
    final font = fonts.regular;
    final fontBold = fonts.bold;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.green900, width: 3),
              borderRadius: pw.BorderRadius.circular(16),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'بسم الله الرحمن الرحيم',
                  style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.green900),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'إقرار وتفصيل حساب الزكاة الشرعية',
                  style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.green800),
                ),
                pw.Text(
                  'الهيئة العامة للزكاة - النظام الشامل لحساب الزكاة',
                  style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700),
                ),
                pw.Divider(color: PdfColors.green900, thickness: 1.5),
                pw.SizedBox(height: 20),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('اسم المكلف: $userName', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                    pw.Text(
                      'التاريخ: ${AppFormatters.formatDate(record.date)}',
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Details table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.green100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('البند', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('القيمة / البيان', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('نوع الزكاة', style: pw.TextStyle(font: font, fontSize: 12)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(record.typeName, style: pw.TextStyle(font: fontBold, fontSize: 12)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('إجمالي المال / المقدار المحسوب', style: pw.TextStyle(font: font, fontSize: 12)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${record.totalWealth} ${record.currency}', style: pw.TextStyle(font: font, fontSize: 12)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('حالة بلوغ النصاب', style: pw.TextStyle(font: font, fontSize: 12)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            record.reachedNisab ? 'اكتمل النصاب وحالت الزكاة' : 'لم يكتمل النصاب الشرعي',
                            style: pw.TextStyle(font: fontBold, fontSize: 12, color: record.reachedNisab ? PdfColors.green700 : PdfColors.orange700),
                          ),
                        ),
                      ],
                    ),
                    if (record.calculationPolicy.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('السياسة الفقهية المعتمدة', style: pw.TextStyle(font: font, fontSize: 12)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(record.calculationPolicy, style: pw.TextStyle(font: font, fontSize: 12)),
                          ),
                        ],
                      ),
                    if (record.appliedPrice != null && record.appliedPrice! > 0)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              record.goldKarat != null
                                  ? 'سعر الجرام المعتمد (عيار ${record.goldKarat})'
                                  : 'السعر المعتمد للوحدة',
                              style: pw.TextStyle(font: font, fontSize: 12),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${record.appliedPrice!.toStringAsFixed(2)} ${record.currency}',
                              style: pw.TextStyle(font: fontBold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    if (record.nisabThreshold != null && record.nisabThreshold! > 0)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('النصاب الشرعي المعتمد', style: pw.TextStyle(font: font, fontSize: 12)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${record.nisabThreshold!.toStringAsFixed(2)} ${record.currency}',
                              style: pw.TextStyle(font: fontBold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    if (record.exchangeRate != null && record.exchangeRate! > 0)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('سعر التحويل / الصرف المعتمد', style: pw.TextStyle(font: font, fontSize: 12)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${record.exchangeRate!.toStringAsFixed(2)} (المصدر: ${record.priceSource})',
                              style: pw.TextStyle(font: fontBold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.amber100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text('المقدار الواجب إخراجه', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text(
                            record.zakatInKindDescription.isNotEmpty
                                ? record.zakatInKindDescription
                                : '${record.zakatAmount.toStringAsFixed(2)} ${record.currency}',
                            style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.green900),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 30),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'قال تعالى: {خُذْ مِنْ أَمْوَالِهِمْ صَدَقَةً تُطَهِّرُهُمْ وَتُزَكِّيهِم بِهَا وَصَلِّ عَلَيْهِمْ إِنَّ صَلَاتَكَ سَكَنٌ لَّهُمْ} [التوبة: 103]\n'
                    'تقبل الله طاعتكم وزكاتكم وجعلها طهرة ونماءً لأموالكم.',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey800),
                  ),
                ),
                pw.Spacer(),
                pw.Text(
                  'تم استخراج هذا التقرير تلقائياً بواسطة تطبيق الهيئة العامة للزكاة',
                  style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey500),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateAssistancePdf(AssistanceRequest request) async {
    final pdf = pw.Document();
    final fonts = await _loadPdfFonts();
    final font = fonts.regular;
    final fontBold = fonts.bold;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'بسم الله الرحمن الرحيم',
                    style: pw.TextStyle(font: fontBold, fontSize: 16),
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text('الأخ رئيس الهيئة العامة للزكاة                                            المحترم',
                    style: pw.TextStyle(font: fontBold, fontSize: 14)),
                pw.Text('تحية طيبة... وبعد،،،', style: pw.TextStyle(font: font, fontSize: 13)),
                pw.SizedBox(height: 12),
                pw.Text('الموضوع/ ${request.subject}', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Text('نص الرسالة والطلب:', style: pw.TextStyle(font: fontBold, fontSize: 13)),
                pw.SizedBox(height: 6),
                pw.Text(request.details, style: pw.TextStyle(font: font, fontSize: 12, lineSpacing: 2)),
                pw.SizedBox(height: 24),
                pw.Text('معلومات مقدم الطلب:', style: pw.TextStyle(font: fontBold, fontSize: 13)),
                pw.Text('الاسم: ${request.fullName}', style: pw.TextStyle(font: font, fontSize: 12)),
                pw.Text('العنوان: ${request.address}', style: pw.TextStyle(font: font, fontSize: 12)),
                pw.Text('رقم الجوال: ${request.phone}', style: pw.TextStyle(font: font, fontSize: 12)),
                pw.Text('رقم البطاقة الشخصية: ${request.idNumber}', style: pw.TextStyle(font: font, fontSize: 12)),
                pw.Text('تاريخ تقديم الطلب: ${AppFormatters.formatDate(request.createdAt)}',
                    style: pw.TextStyle(font: font, fontSize: 12)),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text('والله الموفق والمستعان', style: pw.TextStyle(font: fontBold, fontSize: 13)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Checks if the records contain more than one distinct currency.
  static bool hasMixedCurrencies(List<ZakatRecord> records) {
    final currencies = records
        .map((r) => r.currency.trim())
        .where((c) => c.isNotEmpty)
        .toSet();
    return currencies.length > 1;
  }

  /// Generates a comprehensive official Annual Zakat Statement PDF
  /// aggregating all calculations, total wealth, total zakat due, and details.
  /// If records contain multiple currencies, totals are grouped by currency
  /// (Map<String, double> totalByCurrency) rather than mixing distinct currencies.
  static Future<Uint8List> generateAnnualStatementPdf({
    required List<ZakatRecord> records,
    String userName = 'المزكي الكريم',
    String? hijriYear,
    String? currency,
    bool preventMixedCurrencies = false,
  }) async {
    final effectiveCurrency = currency ?? (records.isNotEmpty ? records.first.currency : PreferencesService.currency);
    final pdf = pw.Document();
    final fonts = await _loadPdfFonts();
    final font = fonts.regular;
    final fontBold = fonts.bold;

    final Map<String, double> totalZakatByCurrency = {};
    final Map<String, double> totalWealthByCurrency = {};
    int reachedNisabCount = 0;

    for (final r in records) {
      final curr = r.currency.trim().isNotEmpty ? r.currency.trim() : effectiveCurrency;
      if (r.reachedNisab) {
        reachedNisabCount++;
        totalZakatByCurrency[curr] = (totalZakatByCurrency[curr] ?? 0.0) + r.zakatAmount;
      }
      totalWealthByCurrency[curr] = (totalWealthByCurrency[curr] ?? 0.0) + r.totalWealth;
    }

    final isMultiCurrency = totalZakatByCurrency.keys.length > 1 || totalWealthByCurrency.keys.length > 1;

    if (preventMixedCurrencies && isMultiCurrency) {
      throw ArgumentError('لا يمكن جمع سجلات بعملات مختلفة دون تحديد سعر تحويل.');
    }

    final yearStr = hijriYear ?? '${HijriCalendar.now().hYear} هـ';
    final reportDate = AppFormatters.formatDate(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.green900, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('الجمهورية اليمنية', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    pw.Text('الهيئة العامة للزكاة', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.green900)),
                    pw.Text('نظام حساب وإدارة الزكاة الشامل', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('بسم الله الرحمن الرحيم', style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.green900)),
                    pw.SizedBox(height: 2),
                    pw.Text('كشف الحساب الزكوي السنوي المجمع', style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.green800)),
                    pw.Text('للعام الهجري: $yearStr', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.amber800)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('تاريخ التقرير:', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                    pw.Text(reportDate, style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    pw.Text('رقم الإقرار: ZKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('وثيقة إقرار زكوي رسمية صادرة عن تطبيق الهيئة العامة للزكاة', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 12),
            // User & Summary Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.green200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('اسم المكلف: $userName', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.green900)),
                      pw.SizedBox(height: 4),
                      pw.Text('حالة الإقرار: مستوفٍ للشروط الشرعية', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('إجمالي العمليات المسجلة: ${records.length}', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text('العمليات المستوفية للنصاب: $reachedNisabCount', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.green800)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Summary Financial Cards (Grouped by Currency)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green100,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.green800),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          isMultiCurrency
                              ? 'إجمالي الزكاة الواجبة (حسب العملة)'
                              : 'إجمالي الزكاة الواجب إخراجها',
                          style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.green900),
                        ),
                        pw.SizedBox(height: 4),
                        if (totalZakatByCurrency.isEmpty)
                          pw.Text('0.00 $effectiveCurrency', style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.green900))
                        else
                          ...totalZakatByCurrency.entries.map(
                            (entry) => pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 2),
                              child: pw.Text(
                                '${AppFormatters.formatNumber(entry.value, decimals: 2)} ${entry.key}',
                                style: pw.TextStyle(font: fontBold, fontSize: isMultiCurrency ? 11 : 13, color: PdfColors.green900),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          isMultiCurrency
                              ? 'إجمالي الأوعية الخاضعة (حسب العملة)'
                              : 'إجمالي الأموال والأوعية الخاضعة',
                          style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800),
                        ),
                        pw.SizedBox(height: 4),
                        if (totalWealthByCurrency.isEmpty)
                          pw.Text('0.00 $effectiveCurrency', style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.grey800))
                        else
                          ...totalWealthByCurrency.entries.map(
                            (entry) => pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 2),
                              child: pw.Text(
                                '${AppFormatters.formatNumber(entry.value, decimals: 2)} ${entry.key}',
                                style: pw.TextStyle(font: fontBold, fontSize: isMultiCurrency ? 11 : 13, color: PdfColors.grey800),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isMultiCurrency) ...[
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.amber700, width: 0.8),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('تنبيه هام:', style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.amber900)),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: pw.Text(
                        'يتضمن التقرير سجلات بعملات متعددة (${totalWealthByCurrency.keys.join('، ')}). تم تصنيف المبالغ حسب كل عملة على حدة دون دمجها منعاً لجمع عملات مختلفة دون سعر تحويل معتمد.',
                        style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.amber900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 16),

            // Records Detail Table Header
            pw.Text('تفصيل العمليات والأنصبة المحسوبة:', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.green900)),
            pw.SizedBox(height: 6),

            // Records Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.2),
                1: pw.FlexColumnWidth(1.8),
                2: pw.FlexColumnWidth(2.2),
                3: pw.FlexColumnWidth(2.0),
                4: pw.FlexColumnWidth(2.6),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.green800),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: pw.Text('نوع الزكاة', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: pw.Text('التاريخ', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: pw.Text('الوعاء / الثروة', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: pw.Text('الواجب نقداً', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: pw.Text('المقدار عيناً / الحالة', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white), textAlign: pw.TextAlign.center),
                    ),
                  ],
                ),
                ...records.map((rec) {
                  final inKind = rec.zakatInKindDescription.isNotEmpty
                      ? rec.zakatInKindDescription
                      : (rec.reachedNisab ? 'مستوفٍ للنصاب' : 'دون النصاب');
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: rec.reachedNisab ? PdfColors.white : PdfColors.grey100,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(rec.typeName, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(AppFormatters.formatDate(rec.date), style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          rec.totalWealth > 0 ? '${AppFormatters.formatNumber(rec.totalWealth, decimals: 0)} ${rec.currency}' : '-',
                          style: pw.TextStyle(font: font, fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          rec.reachedNisab ? '${AppFormatters.formatNumber(rec.zakatAmount, decimals: 2)} ${rec.currency}' : '0',
                          style: pw.TextStyle(font: fontBold, fontSize: 8, color: rec.reachedNisab ? PdfColors.green900 : PdfColors.grey700),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(inKind, style: pw.TextStyle(font: font, fontSize: 7, color: rec.reachedNisab ? PdfColors.green800 : PdfColors.grey600)),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),

            // Seal & Signature Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('توقيع المكلف / المقر', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    pw.SizedBox(height: 25),
                    pw.Text('................................', style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.green900, width: 1.5),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('ختم الاعتماد الإلكتروني', style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.green900)),
                      pw.SizedBox(height: 2),
                      pw.Text('الهيئة العامة للزكاة - اليمن', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.green800)),
                      pw.Text('معتمد رسمياً', style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.amber800)),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<String?> savePdfToDevice(Uint8List pdfData, String filename) async {
    try {
      Directory? targetDir;

      if (Platform.isAndroid) {
        // Attempt to save to public Downloads folder so it's readily accessible to the user
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
      // Fallback to internal application documents directory if public path is restricted
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
