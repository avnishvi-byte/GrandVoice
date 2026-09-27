import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';

/// Ask about Mom: questions answered by Claude, only from what she shared.
class AskTab extends StatefulWidget {
  const AskTab({super.key});

  @override
  State<AskTab> createState() => _AskTabState();
}

class _QA {
  _QA(this.question);
  final String question;
  String? answer;
  List<String> sources = [];
}

class _AskTabState extends State<AskTab> {
  final _q = TextEditingController();
  final List<_QA> _history = [];
  bool _busy = false;

  static const _suggestions = [
    'When did Mom last feel dizzy?',
    'What did Dr. Patel say?',
    'Who is visiting soon?',
  ];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _ask(String question) async {
    question = question.trim();
    if (question.isEmpty || _busy) return;
    final qa = _QA(question);
    setState(() {
      _history.insert(0, qa);
      _busy = true;
      _q.clear();
    });
    FocusScope.of(context).unfocus();
    final r = await context.read<AppState>().ask(question);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r == null) {
        qa.answer = 'Ask needs the Grandvoice server. Check the connection in the ... menu.';
      } else {
        qa.answer = r['answer'] as String?;
        qa.sources = ((r['sources'] as List?) ?? []).cast<String>();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mom = context.select<AppState, String>((s) => s.firstName);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Text('Ask about Mom', style: GvText.title(size: 30)),
        const SizedBox(height: 4),
        Text('Answers come only from what $mom shared',
            style: GvText.body(size: 16, color: GvColors.muted)),
        const SizedBox(height: 18),
        TextField(
          controller: _q,
          textInputAction: TextInputAction.send,
          onSubmitted: _ask,
          style: GvText.body(size: 18),
          decoration: InputDecoration(
            hintText: 'Type a question',
            filled: true,
            fillColor: Colors.white,
            suffixIcon: IconButton(
              icon: const Icon(Icons.send_rounded, color: GvColors.teal),
              onPressed: () => _ask(_q.text),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: GvColors.fieldBorder, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: GvColors.fieldBorder, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _suggestions)
              ActionChip(
                label: Text(s, style: GvText.body(size: 15, color: GvColors.teal)),
                backgroundColor: GvColors.tealSoft,
                side: BorderSide.none,
                onPressed: () => _ask(s),
              ),
          ],
        ),
        const SizedBox(height: 20),
        for (final qa in _history) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: GvColors.teal,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(qa.question, style: GvText.body(size: 17, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
          GvCard(
            child: qa.answer == null
                ? Row(children: [
                    const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Text('Looking through her entries...',
                        style: GvText.body(color: GvColors.muted)),
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(qa.answer!, style: GvText.body(size: 18, height: 1.45)),
                      if (qa.sources.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('From: ${qa.sources.join(', ')}',
                            style: GvText.body(size: 14, color: GvColors.muted)),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}
