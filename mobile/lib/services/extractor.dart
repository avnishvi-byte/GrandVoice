import 'package:intl/intl.dart';

import '../models.dart';

/// What the review screen shows after Rosa finishes talking.
class Extraction {
  Extraction({required this.updates, required this.flags});
  final List<Update> updates;
  final List<String> flags;
}

/// Simple keyword rules that spot medicine changes, upcoming visits and
/// symptoms in what Rosa said.
///
/// This runs on the phone with no internet. For the full product, replace
/// [extract] with a call to your FastAPI backend that asks Claude to return
/// the same fields as JSON.
class Extractor {
  static const _medAliases = {
    'Lisinopril': ['lisinopril', 'blood pressure'],
    'Metformin': ['metformin', 'sugar pill', 'diabetes'],
    'Atorvastatin': ['atorvastatin', 'cholesterol'],
    'Vitamin D': ['vitamin d'],
  };

  static const _weekdays = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];

  static const _eventWords = [
    'visit', 'coming', 'appointment', 'doctor', 'dr.', 'dr ', 'party',
    'birthday', 'lunch', 'dinner', 'meet', 'pick me up', 'check-up', 'checkup',
  ];

  static const _symptoms = {
    'dizzy': ['dizzy', 'dizziness', 'lightheaded'],
    'pain': ['pain', 'hurts', 'ache'],
    'tired': ['tired', 'exhausted', 'no energy'],
    'fall': ['fell', 'fall down', 'tripped'],
    'sleep': ["couldn't sleep", 'could not sleep', 'slept badly', 'bad sleep'],
  };

  static Extraction extract(String text, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final lower = text.toLowerCase();
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final updates = <Update>[];

    // Medicine changes: a medicine mentioned with a time of day or a change.
    for (final med in medicines) {
      final aliases = _medAliases[med.name] ?? [med.name.toLowerCase()];
      for (final s in sentences) {
        final sl = s.toLowerCase();
        if (!aliases.any(sl.contains)) continue;
        String? when;
        if (sl.contains('morning')) when = 'now mornings';
        if (sl.contains('evening') || sl.contains('night')) when = 'now evenings';
        if (sl.contains('stop')) when = 'stopped';
        if (sl.contains('increase') || sl.contains('more')) when = 'dose increased';
        if (sl.contains('decrease') || sl.contains('less')) when = 'dose lowered';
        if (when != null) {
          updates.add(Update(
              title: '${med.name} ${med.dose.split(',').first}, $when',
              kind: 'Medicine change'));
          break;
        }
      }
    }

    // Calendar: a sentence with a weekday and an event word.
    for (final s in sentences) {
      final sl = s.toLowerCase();
      final dayIndex = _weekdays.indexWhere(sl.contains);
      if (dayIndex < 0) continue;
      if (!_eventWords.any(sl.contains)) continue;
      // Past tense ("saw", "felt") is not a future event.
      if (RegExp(r'\b(saw|felt|went|was|had)\b').hasMatch(sl) &&
          !sl.contains('coming') &&
          !sl.contains('will')) {
        continue;
      }
      final date = _nextWeekday(today, dayIndex + 1);
      var label = s.split(',').first.replaceAll(RegExp(r'[.!?]$'), '');
      label = label.replaceAll(
          RegExp(r'\s+(on\s+)?(next\s+)?' + _weekdays[dayIndex], caseSensitive: false), '');
      if (label.length > 36) label = '${label.substring(0, 34).trim()}...';
      updates.add(Update(
        title: '$label, ${DateFormat('EEEE MMM d').format(date)}',
        kind: 'Calendar',
      ));
    }

    final flags = <String>[
      for (final entry in _symptoms.entries)
        if (entry.value.any(lower.contains)) entry.key,
    ];

    return Extraction(updates: updates, flags: flags);
  }

  static DateTime _nextWeekday(DateTime from, int weekday) {
    var d = DateTime(from.year, from.month, from.day);
    var add = (weekday - d.weekday) % 7;
    if (add == 0) add = 7;
    return d.add(Duration(days: add));
  }
}
