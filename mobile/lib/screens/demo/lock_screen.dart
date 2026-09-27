import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/time_format.dart';
import '../diary/listening_screen.dart';
import '../diary/love_received_screen.dart';

/// 5.2 / 5.3 A preview of the notifications Rosa or David would see on
/// their lock screen. Built from the same app state as the real screens.
class LockScreen extends StatelessWidget {
  const LockScreen({super.key, required this.forRosa});

  final bool forRosa;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final entry = s.todayEntry;
    final items = <_Notice>[];

    void open(Widget screen) => Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => screen));

    if (forRosa) {
      final req = s.famRequest;
      if (req != null && req.status == 'pending') {
        items.add(_Notice(req.at, '${req.from} wants to join your circle',
            'Open Circle to accept or decline.', onOpen: () {
          s.setDiaryTab(3);
          Navigator.of(context).pop();
        }));
      }
      if (s.remind != null && entry == null) {
        items.add(_Notice(s.remind!.at, '${s.remind!.who} is thinking of you',
            'He would love to hear about your day. Tap to talk.',
            onOpen: () => open(const ListeningScreen())));
      }
      if (entry == null) {
        items.add(_Notice(DateTime(now.year, now.month, now.day, 19), 'Good evening, ${s.firstName}',
            'You have not told me about today yet. It only takes a minute.',
            onOpen: () => open(const ListeningScreen())));
      } else {
        items.add(_Notice(entry.createdAt, 'Your day is saved',
            'Thank you, ${s.firstName}. Sleep well.', onOpen: () {
          s.setDiaryTab(2);
          Navigator.of(context).pop();
        }));
      }
      if (s.medRemind != null && !s.isTaken('m')) {
        items.add(_Notice(s.medRemind!.at, 'Reminder from ${s.medRemind!.who}',
            'Time for Metformin 500 mg with food.',
            actLabel: 'I took it', onAct: () => s.setTaken('m', true), onOpen: () {
          s.setDiaryTab(1);
          Navigator.of(context).pop();
        }));
      }
      if (s.notes.isNotEmpty) {
        final n = s.notes.first;
        items.add(_Notice(n.at, n.text,
            n.kind == 'voice' ? 'Tap Open to listen.' : 'Your family is thinking of you.',
            onOpen: () => open(const LoveReceivedScreen())));
      }
    } else {
      if (entry == null) {
        items.add(_Notice(
          DateTime(now.year, now.month, now.day, 20),
          "Mom hasn't shared her day yet",
          s.remind != null
              ? "You sent a reminder at ${clock(s.remind!.at)}. We'll tell you when she shares."
              : '${s.firstName} has not talked to Grandvoice today. Send her a gentle reminder?',
          actLabel: s.remind == null ? 'Send reminder' : null,
          onAct: s.sendRemind,
          onOpen: () {
            s.setFamilyTab(0);
            Navigator.of(context).pop();
          },
        ));
      } else {
        items.add(_Notice(entry.createdAt, 'Mom shared her day',
            entry.shared ? entry.text : 'She journaled today and kept it private.', onOpen: () {
          s.setFamilyTab(1);
          Navigator.of(context).pop();
        }));
      }
      if (!s.isTaken('m')) {
        items.add(_Notice(
          DateTime(now.year, now.month, now.day, 14),
          'Lunch medicine not taken',
          s.medRemind != null
              ? 'Reminder sent at ${clock(s.medRemind!.at)}.'
              : '${s.firstName} has not marked Metformin as taken.',
          actLabel: s.medRemind == null ? 'Remind her' : null,
          onAct: s.sendMedRemind,
          onOpen: () {
            s.setFamilyTab(1);
            Navigator.of(context).pop();
          },
        ));
      }
      if (s.famNotes.isNotEmpty) {
        final f = s.famNotes.first;
        items.add(_Notice(f.at, f.text, 'From ${s.firstName}', onOpen: () {
          s.setFamilyTab(1);
          Navigator.of(context).pop();
        }));
      }
    }

    final clockText = clock(now).replaceAll(RegExp(r'\s?[AP]M', caseSensitive: false), '');

    return Scaffold(
      backgroundColor: const Color(0xFF1B2B30),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF8FA7A3)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 24),
            Text(longDate(now), style: GvText.body(size: 18, color: const Color(0xFFC9D6D3))),
            Text(clockText,
                style: GvText.bold(size: 84, color: GvColors.ivory).copyWith(letterSpacing: -2, height: 1.1)),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final n in items.take(3)) ...[
                    _NoticeCard(n),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                forRosa
                    ? 'Notifications Rosa sees on her lock screen'
                    : 'Notifications David sees on his lock screen',
                style: GvText.body(size: 15, color: const Color(0xFF8FA7A3)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice {
  _Notice(this.at, this.title, this.body, {this.actLabel, this.onAct, required this.onOpen});
  final DateTime at;
  final String title;
  final String body;
  final String? actLabel;
  final VoidCallback? onAct;
  final VoidCallback onOpen;
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard(this.n);
  final _Notice n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: GvColors.ivory.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  color: GvColors.deepTeal, borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.record_voice_over_outlined,
                  size: 14, color: GvColors.champagne),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('Grandvoice', style: GvText.bold(size: 14))),
            Text(clock(n.at), style: GvText.body(size: 14, color: GvColors.muted)),
          ]),
          const SizedBox(height: 10),
          Text(n.title, style: GvText.bold()),
          const SizedBox(height: 2),
          Text(n.body, style: GvText.body(size: 16, height: 1.4)),
          const SizedBox(height: 10),
          Row(children: [
            if (n.actLabel != null) ...[
              Expanded(
                child: PillButton(
                  label: n.actLabel!,
                  radius: 14,
                  onPressed: n.onAct,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: PillButton(
                label: 'Open',
                radius: 14,
                bg: const Color(0xFFE6DFD2),
                fg: GvColors.ink,
                onPressed: n.onOpen,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
