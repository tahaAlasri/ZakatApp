import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/zakat_record.dart';
import '../../models/assistance_request.dart';

class PdfService {
  static Future<Uint8List> generateZakatReceipt(ZakatRecord record, {String userName = 'المزكي الكريم'}) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

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
                  'تطبيق زكاتي - النظام الشامل لحساب الزكاة',
                  style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700),
                ),
                pw.Divider(color: PdfColors.green900, thickness: 1.5),
                pw.SizedBox(height: 20),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('اسم المكلف: $userName', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                    pw.Text(
                      'التاريخ: ${record.date.year}/${record.date.month}/${record.date.day}',
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
                  'تم استخراج هذا التقرير تلقائياً بواسطة تطبيق زكاتي',
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

    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

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
                pw.Text('تاريخ تقديم الطلب: ${request.createdAt.year}/${request.createdAt.month}/${request.createdAt.day}',
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

  static Future<void> shareOrPrintPdf(Uint8List pdfData, String filename) async {
    await Printing.sharePdf(bytes: pdfData, filename: filename);
  }
}
