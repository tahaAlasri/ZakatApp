import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfThemeHelper {
  /// Loads Arabic fonts with offline-first fallback:
  /// 1. GoogleFonts network/memory cache (Cairo)
  /// 2. Local asset fonts (assets/fonts/Cairo-Regular.ttf & Cairo-Bold.ttf)
  /// 3. Helvetica standard fallback
  static Future<({pw.Font regular, pw.Font bold})> loadPdfFonts() async {
    try {
      final font = await PdfGoogleFonts.cairoRegular();
      final fontBold = await PdfGoogleFonts.cairoBold();
      return (regular: font, bold: fontBold);
    } catch (e) {
      debugPrint('PdfThemeHelper: GoogleFonts failed, falling back to local asset fonts: $e');
    }

    try {
      final regularData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      return (
        regular: pw.Font.ttf(regularData),
        bold: pw.Font.ttf(boldData),
      );
    } catch (e) {
      debugPrint('PdfThemeHelper: Local asset fonts failed, using helvetica fallback: $e');
    }

    return (
      regular: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );
  }

  static pw.BoxDecoration get borderDecoration => pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.green900, width: 3),
        borderRadius: pw.BorderRadius.circular(16),
      );

  static pw.Divider get standardDivider =>
      pw.Divider(color: PdfColors.green900, thickness: 1.5);
}
