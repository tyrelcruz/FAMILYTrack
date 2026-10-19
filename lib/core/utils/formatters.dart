import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

String formatMoney(double v) => _currency.format(v);
String formatDay(DateTime d) => DateFormat('EEE, MMM d, y').format(d);
String formatMonth(DateTime d) => DateFormat('MMMM y').format(d);

/// e.g. "10:00 am • 08 Mar, 2025"
String formatTimeAndDate(DateTime d) =>
    '${DateFormat('hh:mm a').format(d).toLowerCase()} • '
    '${DateFormat('dd MMM, y').format(d)}';
