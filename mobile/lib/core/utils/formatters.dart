import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

String formatMoney(double v) => _currency.format(v);
String formatDay(DateTime d) => DateFormat('EEE, MMM d, y').format(d);
String formatMonth(DateTime d) => DateFormat('MMMM y').format(d);

/// e.g. "10:00 am • 08 Mar, 2025"
String formatTimeAndDate(DateTime d) =>
    '${DateFormat('hh:mm a').format(d).toLowerCase()} • '
    '${DateFormat('dd MMM, y').format(d)}';

/// Like [formatMoney] but drops ".00", e.g. "₱1,800" or "₱23.12".
String formatAmount(double v) {
  final s = _currency.format(v);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

/// e.g. "03:12 PM"
String formatTime(DateTime d) => DateFormat('hh:mm a').format(d);

/// "Today", "Yesterday", or e.g. "Mon, Oct 13".
String formatDayHeader(DateTime d) {
  final today = DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final diff = DateTime(today.year, today.month, today.day).difference(day);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  return DateFormat('EEE, MMM d').format(d);
}

/// e.g. "Oct 21"
String formatShortDay(DateTime d) => DateFormat('MMM d').format(d);

/// e.g. "Oct 20 – 24, 2026" or "Oct 30 – Nov 2, 2026"
String formatDateRange(DateTime a, DateTime b) {
  if (a.year != b.year) {
    return '${DateFormat('MMM d, y').format(a)} – ${DateFormat('MMM d, y').format(b)}';
  }
  if (a.month != b.month) {
    return '${DateFormat('MMM d').format(a)} – ${DateFormat('MMM d, y').format(b)}';
  }
  if (a.day == b.day) return DateFormat('MMM d, y').format(a);
  return '${DateFormat('MMM d').format(a)} – ${b.day}, ${b.year}';
}

/// e.g. "Apr 12, 2025"
String formatDayShortYear(DateTime d) => DateFormat('MMM d, y').format(d);
