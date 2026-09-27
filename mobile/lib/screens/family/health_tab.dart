import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/time_format.dart';

/// 4.4 Mom's week: mood bars, medicine dots and recent changes.
/// The past six days are sample data; today's column comes from the app.
class HealthTab extends StatelessWidget {
  const HealthTab({super.key});

  // Past 6 days of sample data (oldest first).
  static const _moodPast = [96.0, 84.0, 72.0, 40.0, 60.0, 84.0];
  static const _dizzyPast = [false, false, false, true, false, false];
  static const _takenPast = {
    'l': [true, true, true, true, true, true],
    'v': [true, true, true, true, true, true],
    'm': [true, false, true, false, true, true],
    'a': [true, true, true, true, false, true],
  };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final today = dayOnly(DateTime.now());
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final todayEntry = s.todayEntry;
    final dizzyToday = todayEntry?.flags.contains('dizzy') ?? false;
    final moodToday = todayEntry == null ? 20.0 : (dizzyToday ? 64.0 : 88.0);

    var taken = 0;
    for (final m in medicines) {
      taken += _takenPast[m.id]!.where((t) => t).length + (s.isTaken(m.id) ? 1 : 0);
    }

    final df = DateFormat('MMM d');
    const shown = ['l', 'm', 'a'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Mom's week", style: GvText.title(size: 30)),
              const SizedBox(height: 2),
              Text('${df.format(days.first)} to ${df.format(days.last)}, from shared entries',
                  style: GvText.body(size: 16, color: const Color(0xFF4A565C))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Mood',
          trailing: Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration:
                    const BoxDecoration(color: GvColors.ember, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('Dizziness noted', style: GvText.body(size: 14, color: const Color(0xFF4A565C))),
          ]),
          child: SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (i < 6 ? _dizzyPast[i] : dizzyToday) ...[
                          Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                  color: GvColors.ember, shape: BoxShape.circle)),
                          const SizedBox(height: 6),
                        ],
                        Container(
                          height: i < 6 ? _moodPast[i] : moodToday,
                          decoration: BoxDecoration(
                            color: (i < 6 ? _dizzyPast[i] : dizzyToday)
                                ? const Color(0xFF6FA79E)
                                : GvColors.teal,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6), bottom: Radius.circular(3)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('E').format(days[i]),
                          style: i == 6
                              ? GvText.bold(size: 14)
                              : GvText.body(size: 14, color: const Color(0xFF4A565C)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Medicines',
          trailing: Text('$taken of 28 doses',
              style: GvText.body(size: 15, color: const Color(0xFF4A565C))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final id in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(medicines.firstWhere((m) => m.id == id).name,
                            style: GvText.body(size: 16)),
                      ),
                      for (var d = 0; d < 7; d++)
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: _Dot(
                            state: d < 6
                                ? (_takenPast[id]![d] ? _DotState.taken : _DotState.missed)
                                : (s.isTaken(id) ? _DotState.taken : _DotState.later),
                          ),
                        ),
                    ],
                  ),
                ),
              Text('Filled dot taken, orange ring missed, grey ring later today',
                  style: GvText.body(size: 14, color: const Color(0xFF4A565C))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Recent changes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in s.changes.take(5))
                _ChangeLine(date: df.format(c.at), text: '${c.title}, confirmed by Mom'),
              if (s.changes.isEmpty)
                Text('Nothing new this week.',
                    style: GvText.body(size: 16, color: GvColors.muted)),
              _ChangeLine(
                date: df.format(today.add(const Duration(days: 4))),
                text: 'Cardiology follow up, 10:30 AM',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4DCCD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(title, style: GvText.bold())),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

enum _DotState { taken, missed, later }

class _Dot extends StatelessWidget {
  const _Dot({required this.state});
  final _DotState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: state == _DotState.taken ? GvColors.teal : null,
        border: state == _DotState.taken
            ? null
            : Border.all(
                color: state == _DotState.missed ? GvColors.ember : const Color(0xFFCFC5B3),
                width: 2),
      ),
    );
  }
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.date, required this.text});
  final String date;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$date  ', style: GvText.bold(size: 16)),
          TextSpan(text: text),
        ]),
        style: GvText.body(size: 16, height: 1.4),
      ),
    );
  }
}
