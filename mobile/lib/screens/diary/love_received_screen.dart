import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/tts.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/time_format.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/page.dart';
import 'listening_screen.dart';

/// 5.4 Love from David: a love note or voice message, with "Send love back".
class LoveReceivedScreen extends StatelessWidget {
  const LoveReceivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final note = s.notes.isEmpty ? null : s.notes.first;
    final who = s.familyFirstName;
    final voice = note?.kind == 'voice';
    final back = note?.lovedBack ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFFBEFE7),
      bottomNavigationBar: const DiaryNavBar(current: 0),
      body: SafeArea(
        bottom: false,
        child: FillScroll(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
          gap: 14,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: GvColors.emberDark),
                label: Text('Home', style: GvText.bold(color: GvColors.emberDark)),
              ),
            ),
            const Spacer(),
            Center(
              child: Container(
                margin: const EdgeInsets.all(34),
                width: 132,
                height: 132,
                decoration: const BoxDecoration(
                  color: GvColors.ember,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0xFFFAE8DD), spreadRadius: 34),
                    BoxShadow(color: Color(0xFFF6D9C8), spreadRadius: 16),
                  ],
                ),
                child: Icon(voice ? Icons.graphic_eq_rounded : Icons.favorite_rounded,
                    color: Colors.white, size: 60),
              ),
            ),
            Text(
              note == null ? 'From $who' : 'From $who, your son · ${clock(note.at)}',
              textAlign: TextAlign.center,
              style: GvText.bold(color: GvColors.emberDark),
            ),
            Text(
              note == null
                  ? 'No messages yet'
                  : voice
                      ? 'A voice message from $who'
                      : '$who sent you love',
              textAlign: TextAlign.center,
              style: GvText.title(size: 32, color: const Color(0xFF3A1A0C)),
            ),
            if (note != null)
              GvCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      voice ? '"${note.say}"' : 'Thinking of you tonight, Mom. Sleep well.',
                      style: GvText.body(size: 19, height: 1.45),
                    ),
                    if (voice) ...[
                      const SizedBox(height: 10),
                      PillButton(
                        label: "Play $who's message",
                        icon: Icons.play_arrow_rounded,
                        height: 48,
                        radius: 14,
                        bg: GvColors.tealSoft,
                        fg: GvColors.teal,
                        onPressed: () => Tts.say(note.say ?? ''),
                      ),
                    ],
                  ],
                ),
              ),
            const Spacer(),
            if (note != null)
              back
                  ? GvButton(
                      label: 'Love sent. Back to Home',
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : GvButton(
                      label: 'Send love back',
                      icon: Icons.favorite_rounded,
                      color: GvColors.ember,
                      onPressed: s.loveBack,
                    ),
            GvButton(
              label: 'Reply with my voice',
              icon: Icons.mic_rounded,
              height: 56,
              color: Colors.white,
              textColor: GvColors.teal,
              borderColor: GvColors.tealBorder,
              onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ListeningScreen())),
            ),
          ],
        ),
      ),
    );
  }
}
