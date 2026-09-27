import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/tts.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/time_format.dart';
import '../../widgets/demo_menu.dart';
import '../../widgets/page.dart';
import 'listening_screen.dart';
import 'love_received_screen.dart';

/// 2.1 Home: greeting, today's status, the big "Tap and talk" button.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  void _talk(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ListeningScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final entry = s.todayEntry;
    final note = s.notes.isEmpty ? null : s.notes.first;
    final medDue = !s.isTaken('m');
    final question = entry != null ? 'Anything else on your mind?' : 'How was your day today?';

    // Status banner: shared already / someone asked / not yet.
    late final Widget banner;
    if (entry != null) {
      banner = Banner2(
        bg: GvColors.tealSoft,
        fg: GvColors.teal,
        icon: Icons.check_circle_outline_rounded,
        title: 'You shared your day at ${clock(entry.createdAt)}',
        subtitle: 'Thank you. Tap to read it again.',
        onTap: () => s.setDiaryTab(2),
      );
    } else if (s.remind != null) {
      final r = s.remind!;
      banner = Banner2(
        bg: GvColors.teal,
        fg: Colors.white,
        icon: Icons.favorite_border_rounded,
        title: '${r.who} is thinking of you',
        subtitle: 'He asked about your day at ${clock(r.at)}. Tap to talk.',
        onTap: () => _talk(context),
      );
    } else {
      banner = Banner2(
        bg: GvColors.warnBg,
        fg: GvColors.warnFg,
        icon: Icons.wb_twilight_rounded,
        title: "You haven't shared today yet",
        subtitle: 'Tell me about your day before bed.',
        onTap: () => _talk(context),
      );
    }

    return FillScroll(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      gap: 16,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(longDate(now), style: GvText.body(color: GvColors.muted)),
                  const SizedBox(height: 6),
                  Text('${greeting(now)}, ${s.firstName}', style: GvText.title()),
                ],
              ),
            ),
            const DemoMenuButton(),
          ],
        ),
        banner,
        if (note != null)
          GvCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoveReceivedScreen())),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                      color: GvColors.emberSoft, shape: BoxShape.circle),
                  child: Icon(
                      note.kind == 'voice'
                          ? Icons.graphic_eq_rounded
                          : Icons.favorite_rounded,
                      color: GvColors.emberDark,
                      size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note.text, style: GvText.bold()),
                      Text('${clock(note.at)} · Tap to open',
                          style: GvText.body(size: 14, color: GvColors.muted)),
                    ],
                  ),
                ),
                if (note.kind == 'voice') ...[
                  PillButton(
                    label: 'Play',
                    bg: GvColors.tealSoft,
                    fg: GvColors.teal,
                    onPressed: () => Tts.say(note.say ?? ''),
                  ),
                  const SizedBox(width: 6),
                ],
                PillButton(
                  label: note.thanked ? 'Thanks sent' : 'Say thanks',
                  bg: note.thanked ? GvColors.tealSoft : GvColors.teal,
                  fg: note.thanked ? GvColors.teal : Colors.white,
                  onPressed: note.thanked ? null : s.thankLatestNote,
                ),
              ],
            ),
          ),
        const Spacer(),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Semantics(
              button: true,
              label: 'Tap and talk',
              child: GestureDetector(
                onTap: () => _talk(context),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    color: GvColors.teal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0xFFEEF4F1), spreadRadius: 26),
                      BoxShadow(color: Color(0xFFE3EEEB), spreadRadius: 12),
                    ],
                  ),
                  child: const Icon(Icons.mic_rounded, size: 68, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        Column(
          children: [
            GestureDetector(
              onTap: () => _talk(context),
              child: Text('Tap and talk', style: GvText.bold(size: 24)),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(question,
                      textAlign: TextAlign.center,
                      style: GvText.body(size: 19, color: GvColors.body)),
                ),
                IconButton(
                  tooltip: 'Read the question aloud',
                  onPressed: () => Tts.say(question),
                  icon: const Icon(Icons.volume_up_outlined, color: GvColors.teal),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        GvCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onTap: () => s.setDiaryTab(1),
          child: Row(
            children: [
              const IconTile(icon: Icons.medication_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  s.medRemind != null && medDue
                      ? '${s.medRemind!.who} reminded you: Metformin'
                      : medDue
                          ? 'Next: Metformin with lunch'
                          : 'All medicines on track',
                  style: GvText.body(),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: GvColors.faint),
            ],
          ),
        ),
      ],
    );
  }
}
