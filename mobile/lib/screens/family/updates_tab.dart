import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/speech_service.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/time_format.dart';
import '../../widgets/page.dart';

/// 4.3 Mom's day: today's shared entry, medicines, and ways to reach her.
/// Below that, her earlier shared entries by date and time.
class UpdatesTab extends StatefulWidget {
  const UpdatesTab({super.key});

  @override
  State<UpdatesTab> createState() => _UpdatesTabState();
}

class _UpdatesTabState extends State<UpdatesTab> {
  bool _loveSent = false;
  bool _replySent = false;
  String? _digest;
  bool _digestByClaude = false;
  bool _digestBusy = false;

  /// Tonight's digest: Claude summarises today's shared entries.
  Future<void> _loadDigest() async {
    setState(() => _digestBusy = true);
    final r = await context.read<AppState>().digest();
    if (!mounted) return;
    setState(() {
      _digestBusy = false;
      _digest = r == null
          ? 'The digest needs the Grandvoice server. Check the connection in the ... menu.'
          : r['digest'] as String?;
      _digestByClaude = r?['source'] == 'claude';
    });
  }

  Future<void> _voiceReply() async {
    final words = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GvColors.listenBg,
      builder: (_) => const _VoiceReplySheet(),
    );
    if (!mounted || words == null || words.isEmpty) return;
    context.read<AppState>().sendVoice(words);
    setState(() => _replySent = true);
    showSnack(context, 'Voice reply sent to ${context.read<AppState>().firstName}');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final entry = s.todayEntry;
    final fam = s.famNotes.isEmpty ? null : s.famNotes.first;
    final mom = s.firstName;
    final medDue = !s.isTaken('m');
    final earlier = s.dayEntries
        .where((e) => e.shared && (entry == null || e.id != entry.id))
        .take(10)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Row(
          children: [
            LetterAvatar(letter: mom[0], size: 52),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Mom's day", style: GvText.title(size: 30)),
                Text('$mom, your mom', style: GvText.body(size: 16, color: GvColors.muted)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (fam != null) ...[
          Banner2(
            bg: GvColors.tealSoft,
            fg: GvColors.teal,
            icon: Icons.bolt_rounded,
            title: '${fam.text} · ${clock(fam.at)}',
          ),
          const SizedBox(height: 14),
        ],
        if (entry == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: GvColors.warnBg, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(Icons.schedule_rounded, color: GvColors.warnFg),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Mom hasn't shared her day yet",
                        style: GvText.bold(size: 18, color: GvColors.warnFg)),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(
                  s.remind != null
                      ? "Reminder sent at ${clock(s.remind!.at)}. We'll tell you when she shares."
                      : 'She usually talks to Grandvoice by 7 PM.',
                  style: GvText.body(size: 15, color: GvColors.warnFg),
                ),
                const SizedBox(height: 10),
                PillButton(
                  label: s.remind != null ? 'Reminder sent' : 'Send a gentle reminder',
                  height: 50,
                  radius: 14,
                  bg: s.remind != null ? Colors.white : GvColors.teal,
                  fg: s.remind != null ? GvColors.teal : Colors.white,
                  onPressed: s.remind != null ? null : s.sendRemind,
                ),
              ],
            ),
          )
        else if (entry.shared)
          GvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today at ${clock(entry.createdAt)}',
                    style: GvText.bold(size: 15, color: GvColors.teal)),
                const SizedBox(height: 8),
                Text(entry.text, style: GvText.body(size: 19, height: 1.45)),
                if (entry.flags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final f in entry.flags)
                        Chip(
                          label: Text('Mentioned: $f',
                              style: GvText.bold(size: 14, color: GvColors.emberDark)),
                          backgroundColor: GvColors.emberSoft,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          )
        else
          GvCard(
            child: Text('Mom journaled at ${clock(entry.createdAt)} and kept it private.',
                style: GvText.body(color: GvColors.body)),
          ),
        const SizedBox(height: 14),
        GvCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.auto_awesome_rounded, size: 20, color: GvColors.teal),
                const SizedBox(width: 8),
                Expanded(child: Text("Tonight's digest", style: GvText.bold(size: 18))),
                if (_digestByClaude)
                  Text('by Claude', style: GvText.body(size: 13, color: GvColors.muted)),
              ]),
              const SizedBox(height: 8),
              if (_digestBusy)
                Text('Writing a short summary...', style: GvText.body(color: GvColors.muted))
              else if (_digest != null)
                Text(_digest!, style: GvText.body(size: 17, height: 1.45))
              else
                Text("A short summary of $mom's day, written from what she shared.",
                    style: GvText.body(size: 15, color: GvColors.muted)),
              const SizedBox(height: 10),
              PillButton(
                label: _digest == null ? 'Summarize today' : 'Refresh',
                bg: GvColors.tealSoft,
                fg: GvColors.teal,
                onPressed: _digestBusy ? null : _loadDigest,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GvCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const IconTile(icon: Icons.medication_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Medicines ${s.takenCount} of 4', style: GvText.bold(size: 18)),
                    Text(
                      !medDue
                          ? 'Lunch dose taken'
                          : s.medRemind != null
                              ? 'Reminder sent at ${clock(s.medRemind!.at)}'
                              : 'Lunch dose (Metformin) not taken yet',
                      style: GvText.body(
                          size: 14, color: medDue ? GvColors.emberDark : GvColors.teal),
                    ),
                  ],
                ),
              ),
              if (medDue)
                PillButton(
                  label: s.medRemind != null ? 'Sent' : 'Remind her',
                  bg: s.medRemind != null ? GvColors.tealSoft : GvColors.teal,
                  fg: s.medRemind != null ? GvColors.teal : Colors.white,
                  onPressed: s.medRemind != null ? null : s.sendMedRemind,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GvCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onTap: () => s.setFamilyTab(2),
          child: Row(
            children: [
              const IconTile(
                  icon: Icons.event_outlined, bg: GvColors.tealSoft, fg: GvColors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr. Patel, Tue 10:30 AM', style: GvText.bold(size: 18)),
                    Text('Next visit', style: GvText.body(size: 14, color: GvColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: GvColors.faint),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PillButton(
                label: _loveSent ? 'Love sent' : 'Send love',
                icon: Icons.favorite_rounded,
                height: 56,
                radius: 18,
                bg: _loveSent ? GvColors.ember : Colors.white,
                fg: _loveSent ? Colors.white : GvColors.emberDark,
                border: GvColors.emberBorder,
                onPressed: _loveSent
                    ? null
                    : () {
                        s.sendLove();
                        setState(() => _loveSent = true);
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PillButton(
                label: _replySent ? 'Reply sent' : 'Voice reply',
                icon: Icons.mic_rounded,
                height: 56,
                radius: 18,
                bg: _replySent ? GvColors.tealSoft : Colors.white,
                fg: GvColors.teal,
                border: GvColors.tealBorder,
                onPressed: _voiceReply,
              ),
            ),
          ],
        ),
        if (earlier.isNotEmpty) ...[
          const SizedBox(height: 28),
          const SectionLabel('Earlier shared entries'),
          const SizedBox(height: 10),
          DividedCard(children: [
            for (final e in earlier)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(whenLabel(e.createdAt),
                        style: GvText.body(size: 15, color: GvColors.muted)),
                    const SizedBox(height: 4),
                    Text(e.text, style: GvText.body(size: 17, height: 1.45)),
                  ],
                ),
              ),
          ]),
        ],
      ],
    );
  }
}

/// David records a short message; it is turned into text and read aloud to
/// Rosa on her phone.
class _VoiceReplySheet extends StatefulWidget {
  const _VoiceReplySheet();

  @override
  State<_VoiceReplySheet> createState() => _VoiceReplySheetState();
}

class _VoiceReplySheetState extends State<_VoiceReplySheet> {
  final speech = SpeechService.instance;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    speech.begin();
  }

  @override
  void dispose() {
    if (!_done) speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: ListenableBuilder(
          listenable: speech,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Text('Voice reply', style: GvText.title(size: 26, color: GvColors.ivory)),
                const Spacer(),
                Text(duration(speech.seconds),
                    style: GvText.body(size: 18, color: GvColors.ivory)),
              ]),
              const SizedBox(height: 8),
              Text(speech.errorMessage ?? "Speak your message. I'll read it to Mom.",
                  style: GvText.body(color: const Color(0xFF9CC4BD))),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 90),
                child: Text(
                  speech.text.isEmpty ? '...' : speech.text,
                  style: GvText.body(size: 22, color: GvColors.ivory, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
              GvButton(
                label: 'Send to Mom',
                icon: Icons.send_rounded,
                color: GvColors.ivory,
                textColor: GvColors.listenBg,
                onPressed: () async {
                  _done = true;
                  final words = await speech.finish();
                  if (context.mounted) Navigator.of(context).pop(words);
                },
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel', style: GvText.bold(color: const Color(0xFFCFE0DC))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
