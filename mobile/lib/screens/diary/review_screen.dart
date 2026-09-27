import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../services/extractor.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/time_format.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/page.dart';
import 'listening_screen.dart';

/// 2.3 Here's what I heard: check the words, confirm updates, choose sharing,
/// then save. The entry is stamped with the current date and time.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.transcript, required this.durationSeconds});

  final String transcript;
  final int durationSeconds;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final TextEditingController _text;
  late Extraction _found;
  late List<bool> _checked;
  bool _share = true;
  bool _editing = false;
  bool _asking = false; // waiting for Claude
  bool _byClaude = false;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.transcript);
    _editing = widget.transcript.isEmpty; // nothing heard: let her type
    _analyse();
    if (widget.transcript.isNotEmpty) _askClaude();
  }

  /// Instant check on the phone (keyword rules).
  void _analyse() {
    _found = Extractor.extract(_text.text);
    _checked = List.filled(_found.updates.length, true);
    _byClaude = false;
  }

  /// Better check by Claude on the server; keeps the phone's result if offline.
  Future<void> _askClaude() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() => _asking = true);
    final r = await context.read<AppState>().analyze(text);
    if (!mounted) return;
    setState(() {
      _asking = false;
      if (r == null || r['source'] != 'claude' || _text.text.trim() != text) return;
      _found = Extraction(
        updates: [
          for (final u in (r['updates'] as List)) Update.fromJson(u as Map<String, dynamic>),
        ],
        flags: (r['flags'] as List).cast<String>(),
      );
      _checked = List.filled(_found.updates.length, true);
      _byClaude = true;
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      showSnack(context, 'Please say or type something first.');
      return;
    }
    final state = context.read<AppState>();
    final updates = [
      for (var i = 0; i < _found.updates.length; i++)
        if (_checked[i]) _found.updates[i],
    ];
    state.addEntry(
      text: text,
      shared: _share,
      durationSeconds: widget.durationSeconds,
      updates: updates,
      flags: _found.flags,
    );
    state.setDiaryTab(2); // open the Journal so she sees it on top
    showSnack(context, 'Saved at ${clock(DateTime.now())}');
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final people = s.circle.where((c) => !c.pending).map((c) => c.name).toList();
    final shareSub = !_share
        ? 'Only you will see it'
        : people.isEmpty
            ? 'Your circle will see it'
            : '${people.take(2).join(' and ')} will see it';
    final n = _checked.where((c) => c).length;

    return Scaffold(
      bottomNavigationBar: const DiaryNavBar(current: 0),
      body: SafeArea(
        bottom: false,
        child: FillScroll(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
          gap: 22,
          children: [
            Row(
              children: [
                Transform.translate(
                  offset: const Offset(-12, 0),
                  child: IconButton(
                    tooltip: 'Record again',
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                    onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const ListeningScreen())),
                  ),
                ),
                Expanded(child: Text("Here's what I heard", style: GvText.title(size: 30))),
              ],
            ),
            if (_editing)
              TextField(
                controller: _text,
                autofocus: widget.transcript.isEmpty,
                minLines: 4,
                maxLines: null,
                style: GvText.body(size: 22, color: const Color(0xFF2A3A3E), height: 1.45),
                decoration: InputDecoration(
                  hintText: 'Type about your day here',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: GvColors.fieldBorder, width: 2),
                  ),
                ),
                onChanged: (_) => setState(_analyse),
              )
            else
              GestureDetector(
                onTap: () => setState(() => _editing = true),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('"${_text.text}"',
                        style: GvText.body(
                            size: 22, color: const Color(0xFF2A3A3E), height: 1.45)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.edit_outlined, size: 18, color: GvColors.teal),
                      const SizedBox(width: 6),
                      Text('Tap to fix a word', style: GvText.bold(size: 15, color: GvColors.teal)),
                    ]),
                  ],
                ),
              ),
            if (_asking || _byClaude || (_editing && _text.text.trim().isNotEmpty))
              Row(
                children: [
                  if (_asking) ...[
                    const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text('Reading what you said...',
                        style: GvText.body(size: 15, color: GvColors.muted)),
                  ] else if (_byClaude) ...[
                    const Icon(Icons.auto_awesome_rounded, size: 18, color: GvColors.teal),
                    const SizedBox(width: 8),
                    Text('Checked by Claude', style: GvText.bold(size: 15, color: GvColors.teal)),
                  ] else
                    TextButton.icon(
                      onPressed: _askClaude,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: GvColors.teal),
                      label: Text('Check again', style: GvText.bold(size: 15, color: GvColors.teal)),
                    ),
                ],
              ),
            if (_found.updates.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel("I'll also update"),
                  const SizedBox(height: 10),
                  DividedCard(children: [
                    for (var i = 0; i < _found.updates.length; i++)
                      InkWell(
                        onTap: () => setState(() => _checked[i] = !_checked[i]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          child: Row(
                            children: [
                              Transform.scale(
                                scale: 1.3,
                                child: Checkbox(
                                  value: _checked[i],
                                  onChanged: (v) => setState(() => _checked[i] = v ?? false),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Opacity(
                                  opacity: _checked[i] ? 1 : 0.45,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_found.updates[i].title, style: GvText.bold(size: 18)),
                                      Text(_found.updates[i].kind,
                                          style: GvText.body(size: 15, color: GvColors.muted)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ]),
                ],
              ),
            InkWell(
              onTap: () => setState(() => _share = !_share),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Share with family', style: GvText.bold(size: 18)),
                        Text(shareSub, style: GvText.body(size: 15, color: GvColors.muted)),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 1.15,
                    child: Switch(
                      value: _share,
                      activeThumbColor: Colors.white,
                      activeTrackColor: GvColors.teal,
                      inactiveTrackColor: const Color(0xFFC9C1B3),
                      inactiveThumbColor: Colors.white,
                      onChanged: (v) => setState(() => _share = v),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GvButton(
              label: n == 0 ? 'Save entry' : 'Save entry and $n ${n == 1 ? 'update' : 'updates'}',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
