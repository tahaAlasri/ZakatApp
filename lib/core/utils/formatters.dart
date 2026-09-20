import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import '../database/preferences_service.dart';

class AppFormatters {
  static String formatCurrency(double amount, {String? currency}) {
    final cur = currency ?? PreferencesService.currency;
    final formatter = NumberFormat('#,##0.00', 'ar_YE');
    return '${formatter.format(amount)} $cur';
  }

  static String formatNumber(double number, {int decimals = 2}) {
    final formatter = NumberFormat('#,##0.${'#' * decimals}');
    return formatter.format(number);
  }

  /// Convert a Gregorian DateTime to HijriCalendar
  static HijriCalendar toHijri(DateTime date) {
    HijriCalendar.setLocal('ar');
    return HijriCalendar.fromDate(date);
  }

  /// Format date as Hijri string (e.g. 15 ربيع الأول 1448 هـ)
  static String formatDate(DateTime date, {bool includeMonthName = true}) {
    try {
      HijriCalendar.setLocal('ar');
      final hDate = HijriCalendar.fromDate(date);
      if (includeMonthName) {
        return '${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear} هـ';
      } else {
        return '${hDate.hYear}/${hDate.hMonth.toString().padLeft(2, '0')}/${hDate.hDay.toString().padLeft(2, '0')} هـ';
      }
    } catch (_) {
      try {
        return DateFormat('yyyy/MM/dd', 'ar').format(date);
      } catch (_) {
        return '${date.year}/${date.month}/${date.day}';
      }
    }
  }

  /// Format date and time in Hijri (e.g. 15 ربيع الأول 1448 هـ - 03:30 م)
  static String formatDateTime(DateTime date) {
    try {
      final hijriDate = formatDate(date);
      final timeStr = DateFormat('hh:mm a', 'ar').format(date);
      return '$hijriDate - $timeStr';
    } catch (_) {
      return formatDate(date);
    }
  }

  /// Format numerical Hijri date (e.g. 1448/03/15 هـ)
  static String formatDateNumeric(DateTime date) {
    return formatDate(date, includeMonthName: false);
  }
}
