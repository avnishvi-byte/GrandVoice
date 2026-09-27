import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/time_format.dart';
import '../../widgets/page.dart';

/// 2.5 Today: medicines with "Took it", and what's coming up.
class TodayTab extends StatelessWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final count = s.takenCount;
    final total = medicines.length;
    final firstOpen = medicines.where((m) => !s.isTaken(m.id)).firstOrNull;
    final upcoming = s.changes
        .where((c) => c.kind == 'Calendar' &&
            DateTime.now().difference(c.at).inDays < 14)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Text('Today', style: GvText.title()),
        const SizedBox(height: 6),
        Text(
          count == total ? 'All $total medicines taken. Well done.' : '$count of $total medicines taken',
          style: GvText.body(color: GvColors.muted),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: count / total),
            duration: const Duration(milliseconds: 400),
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: const Color(0xFFE6DFD2),
              color: GvColors.teal,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (s.medRemind != null && !s.isTaken('m')) ...[
          Banner2(
            bg: GvColors.teal,
            fg: Colors.white,
            subColor: const Color(0xFFCFE3DF),
            icon: Icons.notifications_active_outlined,
            title: '${s.medRemind!.who} reminded you about Metformin',
            subtitle: 'Sent at ${clock(s.medRemind!.at)}. Tap Took it when done.',
          ),
          const SizedBox(height: 20),
        ],
        GvCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < medicines.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: GvColors.line),
                _MedRow(
                  med: medicines[i],
                  takenAt: s.takenAt[medicines[i].id],
                  due: firstOpen?.id == medicines[i].id,
                  onChanged: (v) => s.setTaken(medicines[i].id, v),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionLabel('Coming up'),
        const SizedBox(height: 10),
        for (final c in upcoming)
          _Upcoming(icon: Icons.event_outlined, title: c.title, sub: 'Added ${dayLabel(c.at).toLowerCase()}'),
        const _Upcoming(
            icon: Icons.local_hospital_outlined, title: 'Dr. Patel', sub: 'Tuesday, 10:30 AM'),
      ],
    );
  }
}

class _MedRow extends StatelessWidget {
  const _MedRow({required this.med, required this.takenAt, required this.due, required this.onChanged});

  final Medicine med;
  final DateTime? takenAt;
  final bool due;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final done = takenAt != null;
    return Container(
      color: due ? const Color(0xFFFDF6EE) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(med.time, style: GvText.body(size: 15, color: GvColors.muted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name, style: GvText.bold(size: 18)),
                Text(done ? 'Taken at ${clock(takenAt!)}' : med.dose,
                    style: GvText.body(size: 15, color: GvColors.muted)),
              ],
            ),
          ),
          if (done)
            IconButton.filled(
              tooltip: 'Taken. Tap to undo',
              onPressed: () => onChanged(false),
              style: IconButton.styleFrom(
                  backgroundColor: GvColors.tealSoft, foregroundColor: GvColors.teal),
              icon: const Icon(Icons.check_rounded),
            )
          else if (due)
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () => onChanged(true),
                style: FilledButton.styleFrom(
                  backgroundColor: GvColors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Took it', style: GvText.bold(color: Colors.white)),
              ),
            )
          else
            TextButton(
              onPressed: () => onChanged(true),
              child: Text('Later', style: GvText.body(size: 15, color: GvColors.muted)),
            ),
        ],
      ),
    );
  }
}

class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.icon, required this.title, required this.sub});

  final IconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          IconTile(icon: icon, bg: GvColors.tealSoft, fg: GvColors.teal, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GvText.bold(size: 18)),
                Text(sub, style: GvText.body(size: 15, color: GvColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
