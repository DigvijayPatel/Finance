import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _inrPrecise =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

String formatAmount(num value) =>
    value == value.roundToDouble() ? _inr.format(value) : _inrPrecise.format(value);

String formatDay(DateTime d) => DateFormat('EEE, d MMM').format(d);

String formatShortDate(DateTime d) => DateFormat('d MMM').format(d);

String formatFullDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

String formatMonth(DateTime d) => DateFormat('MMMM yyyy').format(d);

/// First day of the month containing [d].
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

String relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatShortDate(t);
}
