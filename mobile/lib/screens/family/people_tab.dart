import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/time_format.dart';
import '../../widgets/demo_menu.dart';

/// 4.2 My people: Rosa's status today plus other relatives.
class PeopleTab extends StatefulWidget {
  const PeopleTab({super.key});

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  final Set<String> _helloSent = {};

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final entry = s.todayEntry;
    final req = s.famRequest;
    final fam = s.famNotes.isEmpty ? null : s.famNotes.first;
    final mom = s.firstName;

    String stTitle, stSub;
    Color stBg = GvColors.tealSoft, stFg = GvColors.teal;
    var canRemind = false;
    if (entry != null && entry.shared) {
      stTitle = 'Shared her day at ${clock(entry.createdAt)}';
      stSub = 'Tap $mom to read it.';
    } else if (entry != null) {
      stTitle = 'Journaled at ${clock(entry.createdAt)}';
      stSub = "She kept today's entry private.";
    } else if (s.remind != null) {
      stBg = GvColors.warnBg;
      stFg = GvColors.warnFg;
      stTitle = 'Reminder sent at ${clock(s.remind!.at)}';
      stSub = "We'll let you know as soon as she shares.";
    } else {
      stBg = GvColors.warnBg;
      stFg = GvColors.warnFg;
      stTitle = 'No journal entry yet today';
      stSub = '$mom usually talks to Grandvoice by 7 PM.';
      canRemind = true;
    }

    String? reqText;
    Color reqBg = GvColors.warnBg, reqFg = GvColors.warnFg;
    if (req != null) {
      final first = req.name.split(' ').first;
      if (req.status == 'accepted') {
        reqText = '$first accepted your request at ${clock(req.respondedAt!)}.';
        reqBg = GvColors.tealSoft;
        reqFg = GvColors.teal;
      } else if (req.status == 'declined') {
        reqText = '$first declined for now. You can ask again later.';
        reqBg = const Color(0xFFEFE8DB);
        reqFg = GvColors.body;
      } else {
        reqText = 'Request sent to $first at ${clock(req.at)}. Waiting for her to accept.';
      }
    }

    const others = [
      ('d', 'D', 'Della', 'Your aunt', 'Shared at 6:10 PM', GvColors.tealSoft, GvColors.teal),
      ('f', 'F', 'Frank', 'Your uncle', 'Quiet for 3 days', Color(0xFFE6E1F2), Color(0xFF4B3F7A)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hi ${s.familyFirstName}', style: GvText.body(color: GvColors.muted)),
                  const SizedBox(height: 6),
                  Text('My people', style: GvText.title()),
                ],
              ),
            ),
            const DemoMenuButton(),
          ],
        ),
        const SizedBox(height: 16),
        if (reqText != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: reqBg, borderRadius: BorderRadius.circular(16)),
            child: Text(reqText, style: GvText.bold(size: 16, color: reqFg)),
          ),
          const SizedBox(height: 16),
        ],
        GvCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => s.setFamilyTab(1),
                child: Row(
                  children: [
                    LetterAvatar(letter: mom[0], size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mom, style: GvText.title(size: 24)),
                          Text('Your mom', style: GvText.body(size: 16, color: GvColors.muted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: GvColors.faint),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: stBg, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Icon(entry != null ? Icons.check_circle_outline : Icons.schedule_rounded,
                          size: 20, color: stFg),
                      const SizedBox(width: 8),
                      Expanded(child: Text(stTitle, style: GvText.bold(size: 16, color: stFg))),
                    ]),
                    const SizedBox(height: 4),
                    Text(stSub, style: GvText.body(size: 15, color: stFg)),
                    if (canRemind) ...[
                      const SizedBox(height: 10),
                      PillButton(
                        label: 'Send a gentle reminder',
                        icon: Icons.notifications_none_rounded,
                        height: 48,
                        radius: 14,
                        onPressed: s.sendRemind,
                      ),
                    ],
                  ],
                ),
              ),
              if (fam != null) ...[
                const SizedBox(height: 14),
                Row(children: [
                  const Icon(Icons.bolt_rounded, size: 18, color: GvColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${fam.text} · ${clock(fam.at)}',
                        style: GvText.body(size: 15, color: GvColors.teal)),
                  ),
                ]),
              ],
            ],
          ),
        ),
        for (final p in others) ...[
          const SizedBox(height: 16),
          GvCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    LetterAvatar(letter: p.$2, bg: p.$6, fg: p.$7),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.$3, style: GvText.title(size: 22)),
                          Text('${p.$4} · ${p.$5}',
                              style: GvText.body(size: 15, color: GvColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PillButton(
                  label: _helloSent.contains(p.$1)
                      ? 'Hello sent'
                      : p.$1 == 'f'
                          ? 'Send a gentle reminder'
                          : 'Send a hello',
                  bg: _helloSent.contains(p.$1) ? GvColors.tealSoft : Colors.white,
                  fg: GvColors.teal,
                  border: GvColors.tealBorder,
                  onPressed: () => setState(() => _helloSent.contains(p.$1)
                      ? _helloSent.remove(p.$1)
                      : _helloSent.add(p.$1)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('When someone adds your email to their circle, they appear here on their own.',
            textAlign: TextAlign.center,
            style: GvText.body(size: 15, color: GvColors.muted)),
      ],
    );
  }
}
