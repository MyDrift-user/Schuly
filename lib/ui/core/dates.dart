import 'package:intl/intl.dart';
import 'package:schuly_api/schuly_api.dart' show Date;

DateTime dayOf(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

DateTime get today => dayOf(DateTime.now());

bool isSameDay(DateTime a, DateTime b) => dayOf(a) == dayOf(b);

/// Whole days from [from] to [to], unaffected by daylight-saving shifts.
int daysBetween(DateTime from, DateTime to) {
  final a = from.toLocal(), b = to.toLocal();
  return DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// [days] after [d], at midnight local time.
DateTime addDays(DateTime d, int days) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day + days);
}

DateTime fromApiDate(Date d) => DateTime(d.year, d.month, d.day);

/// "15.09.2026"
String formatDate(DateTime d) => DateFormat('dd.MM.yyyy').format(d.toLocal());

/// "Mon, 15 Sep"
String formatDayShort(DateTime d) => DateFormat('EEE, d MMM').format(d.toLocal());

/// "Monday, 15 September"
String formatDayLong(DateTime d) => DateFormat('EEEE, d MMMM').format(d.toLocal());

/// "September 2026"
String formatMonthYear(DateTime d) => DateFormat('MMMM yyyy').format(d.toLocal());

/// "08:15"
String formatTime(DateTime d) => DateFormat('HH:mm').format(d.toLocal());

/// "Today", "Tomorrow", "Yesterday", or the short day label.
String relativeDay(DateTime d) {
  final diff = daysBetween(today, d);
  return switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => formatDayShort(d),
  };
}

/// "now", "tomorrow", "in 3 days", "in 2 weeks"
String countdown(DateTime d) {
  final days = daysBetween(today, d);
  if (days <= 0) return 'now';
  if (days == 1) return 'tomorrow';
  if (days < 14) return 'in $days days';
  final weeks = (days / 7).round();
  return 'in $weeks weeks';
}

/// "15.09." or "15.09. - 19.09."
String formatDateRange(DateTime from, DateTime? until) {
  final f = DateFormat('dd.MM.').format(from.toLocal());
  if (until == null || isSameDay(from, until)) return f;
  return '$f - ${DateFormat('dd.MM.').format(until.toLocal())}';
}

/// "Mon, 15 Sep" or "Mon, 15 Sep - Fri, 19 Sep"
String formatDayRange(DateTime from, DateTime? until) {
  final f = formatDayShort(from);
  if (until == null || isSameDay(from, until)) return f;
  return '$f - ${formatDayShort(until)}';
}

/// "just now", "5m ago", "3h ago", "15.09.2026"
String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return formatDate(t);
}

String greeting(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Good night';
  if (h < 11) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}
