import 'package:intl/intl.dart';

/// "7:40 PM"
String clock(DateTime t) => DateFormat.jm().format(t);

/// "Friday, September 25"
String longDate(DateTime t) => DateFormat('EEEE, MMMM d').format(t);

DateTime dayOnly(DateTime t) => DateTime(t.year, t.month, t.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Heading for a journal day group: "Today", "Yesterday", "Wednesday"
/// (within the last week) or "Sep 12" / "Sep 12, 2025".
String dayLabel(DateTime t, {DateTime? now}) {
  final today = dayOnly(now ?? DateTime.now());
  final diff = today.difference(dayOnly(t)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return DateFormat('EEEE').format(t);
  if (t.year == today.year) return DateFormat('MMM d').format(t);
  return DateFormat('MMM d, y').format(t);
}

/// "Today, 10:14 AM" / "Yesterday, 7:40 PM" / "Sep 12, 9:05 AM"
String whenLabel(DateTime t) => '${dayLabel(t)}, ${clock(t)}';

/// "0:32"
String duration(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

String greeting(DateTime t) {
  if (t.hour < 12) return 'Good morning';
  if (t.hour < 17) return 'Good afternoon';
  return 'Good evening';
}
