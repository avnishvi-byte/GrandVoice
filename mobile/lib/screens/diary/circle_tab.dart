import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/time_format.dart';
import '../../widgets/page.dart';

/// 5.1 My circle: who sees what Rosa shares, join requests, invites.
class CircleTab extends StatefulWidget {
  const CircleTab({super.key});

  @override
  State<CircleTab> createState() => _CircleTabState();
}

class _CircleTabState extends State<CircleTab> {
  final _email = TextEditingController();
  String _rel = 'Son';
  String? _msg;
  bool _ok = true;

  static const _rels = [
    'Son', 'Daughter', 'Grandson', 'Granddaughter', 'Brother or sister',
    'Niece or nephew', 'Caregiver or nurse', 'Friend',
  ];

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _send() {
    final e = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      setState(() {
        _msg = 'Please check the email address';
        _ok = false;
      });
      return;
    }
    context.read<AppState>().invite(e, _rel);
    FocusScope.of(context).unfocus();
    setState(() {
      _email.clear();
      _msg = 'Invite sent to $e';
      _ok = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final req = s.famRequest;
    const palette = [
      (GvColors.tealSoft, GvColors.teal),
      (GvColors.emberSoft, GvColors.emberDark),
      (Color(0xFFE6E1F2), Color(0xFF4B3F7A)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        const PageTitle('My circle', subtitle: 'People who see what you share'),
        const SizedBox(height: 16),
        if (req != null && req.status == 'pending') ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GvColors.emberBorder, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    LetterAvatar(
                        letter: req.from[0], size: 42, bg: GvColors.tealSoft, fg: GvColors.teal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${req.from} wants to join your circle', style: GvText.bold()),
                          Text('Says you are his ${req.rel.toLowerCase()} · ${clock(req.at)}',
                              style: GvText.body(size: 14, color: GvColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        label: 'Decline',
                        height: 46,
                        radius: 14,
                        bg: Colors.white,
                        fg: GvColors.ink,
                        border: const Color(0xFFCFC5B3),
                        onPressed: () => s.answerFamRequest(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PillButton(
                        label: 'Accept',
                        height: 46,
                        radius: 14,
                        onPressed: () => s.answerFamRequest(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (req != null && req.status != 'pending' && !s.famRequestSeen) ...[
          Banner2(
            bg: GvColors.tealSoft,
            fg: GvColors.teal,
            title: req.status == 'accepted'
                ? '${req.from} can now see what you share.'
                : 'Request declined. Nothing is shared.',
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded, color: GvColors.teal),
              onPressed: s.markFamRequestSeen,
            ),
          ),
          const SizedBox(height: 16),
        ],
        DividedCard(children: [
          for (var i = 0; i < s.circle.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  LetterAvatar(
                    letter: s.circle[i].name[0].toUpperCase(),
                    size: 46,
                    bg: s.circle[i].pending ? const Color(0xFFEFE8DB) : palette[i % 3].$1,
                    fg: s.circle[i].pending ? GvColors.muted : palette[i % 3].$2,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.circle[i].name,
                            overflow: TextOverflow.ellipsis, style: GvText.bold(size: 18)),
                        Text(
                          s.circle[i].pending
                              ? '${s.circle[i].relation} · Invite sent'
                              : s.circle[i].relation,
                          style: GvText.body(
                              size: 15,
                              color: s.circle[i].pending
                                  ? const Color(0xFF8A5A10)
                                  : GvColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ]),
        const SizedBox(height: 20),
        GvField(
          label: 'Add someone by email',
          controller: _email,
          hint: 'name@example.com',
          keyboard: TextInputType.emailAddress,
          onChanged: (_) => setState(() => _msg = null),
        ),
        const SizedBox(height: 12),
        GvSelect(
          label: 'Who are they to you?',
          value: _rel,
          options: _rels,
          onChanged: (v) => setState(() => _rel = v),
        ),
        const SizedBox(height: 12),
        GvButton(label: 'Send invite', onPressed: _send),
        const SizedBox(height: 10),
        Text(
          _msg ?? "They'll get an email. No password needed.",
          textAlign: TextAlign.center,
          style: _msg == null
              ? GvText.body(size: 15, color: GvColors.muted)
              : GvText.bold(size: 15, color: _ok ? GvColors.teal : GvColors.emberDark),
        ),
      ],
    );
  }
}
