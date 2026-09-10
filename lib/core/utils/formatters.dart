import 'package:intl/intl.dart';

class AppFormatters {
  static String formatCurrency(double amount, {String currency = 'ر.ي'}) {
    final formatter = NumberFormat('#,##0.00', 'ar_YE');
    return '${formatter.format(amount)} $currency';
  }

  static String formatNumber(double number, {int decimals = 2}) {
    final formatter = NumberFormat('#,##0.${'#' * decimals}');
    return formatter.format(number);
  }

  static String formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd', 'ar').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(date);
  }
}
