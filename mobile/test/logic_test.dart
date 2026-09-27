import 'package:flutter_test/flutter_test.dart';
import 'package:grandvoice/services/extractor.dart';
import 'package:grandvoice/util/time_format.dart';

void main() {
  group('dayLabel', () {
    final now = DateTime(2026, 9, 25, 15); // a Friday

    test('today and yesterday', () {
      expect(dayLabel(DateTime(2026, 9, 25, 8), now: now), 'Today');
      expect(dayLabel(DateTime(2026, 9, 24, 23), now: now), 'Yesterday');
    });

    test('weekday within a week, date after that', () {
      expect(dayLabel(DateTime(2026, 9, 22, 9), now: now), 'Tuesday');
      expect(dayLabel(DateTime(2026, 9, 12, 9), now: now), 'Sep 12');
      expect(dayLabel(DateTime(2025, 9, 12, 9), now: now), 'Sep 12, 2025');
    });
  });

  test('extractor finds the medicine change, the visit and dizziness', () {
    const said = 'Saw Dr. Patel today. She moved my blood pressure pill to the morning. '
        'I felt a little dizzy on Tuesday, but it went away when I sat down. '
        'Maya is coming to visit on Sunday, and I want to bake her the lemon cake she loves.';
    final r = Extractor.extract(said, now: DateTime(2026, 9, 25));

    expect(r.updates.map((u) => u.title), [
      'Lisinopril 10 mg, now mornings',
      'Maya is coming to visit, Sunday Sep 27',
    ]);
    expect(r.flags, ['dizzy']);
  });
}
