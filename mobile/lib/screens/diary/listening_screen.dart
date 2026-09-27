import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/speech_service.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/time_format.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/page.dart';
import 'review_screen.dart';

/// Colours for the daily "Listening" screen and the Life Story screen.
class _Palette {
  const _Palette({
    required this.bg,
    required this.soft,
    required this.status,
    required this.text,
    required this.tail,
    required this.barA,
    required this.barB,
    required this.barIdle,
    required this.chip,
    required this.nav,
  });

  final Color bg, soft, status, text, tail, barA, barB, barIdle, chip;
  final NavStyle nav;

  static const day = _Palette(
    bg: GvColors.listenBg,
    soft: Color(0xFFCFE0DC),
    status: Color(0xFF9CC4BD),
    text: GvColors.ivory,
    tail: Color(0xFF7FAEA6),
    barA: Color(0xFF8CC0B7),
    barB: Color(0xFFF2A57E),
    barIdle: Color(0xFF3C6A64),
    chip: Color(0x14F6F1E8),
    nav: NavStyle.listening,
  );

  static const story = _Palette(
    bg: GvColors.storyBg,
    soft: Color(0xFFF3D9C9),
    status: Color(0xFFE8B89C),
    text: Color(0xFFFBEFE7),
    tail: Color(0xFFD9A387),
    barA: GvColors.champagne,
    barB: Color(0xFFFBEFE7),
    barIdle: Color(0xFF8A5A44),
    chip: Color(0x1AFBEFE7),
    nav: NavStyle.story,
  );
}

/// 2.2 Listening (and 3.2 Telling the story when [storyQuestion] is set).
/// Words appear on screen as Rosa speaks.
class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key, this.storyQuestion, this.storyTitle});

  final String? storyQuestion;
  final String? storyTitle;

  bool get isStory => storyQuestion != null;

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> {
  final speech = SpeechService.instance;
  Timer? _waveTimer;
  int _tick = 0;
  bool _leaving = false;

  _Palette get p => widget.isStory ? _Palette.story : _Palette.day;

  @override
  void initState() {
    super.initState();
    speech.begin();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      if (mounted && speech.isActive) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    if (!_leaving) speech.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    _leaving = true;
    await speech.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _done() async {
    _leaving = true;
    final seconds = speech.seconds;
    final text = await speech.finish();
    if (!mounted) return;

    if (widget.isStory) {
      if (text.isEmpty) {
        _leaving = false;
        showSnack(context, "I didn't catch that. Tap Start over and try again.");
        speech.begin();
        return;
      }
      context.read<AppState>().addStory(
            title: widget.storyTitle ?? 'A new story',
            text: text,
            durationSeconds: seconds,
          );
      Navigator.of(context).pop(true);
      return;
    }

    // Daily entry: go to "Here's what I heard". If speech was not available
    // Rosa can type there instead.
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ReviewScreen(transcript: text, durationSeconds: seconds),
    ));
  }

  String _status() {
    if (speech.errorMessage != null) return speech.errorMessage!;
    if (speech.paused) {
      return widget.isStory
          ? 'Paused. Take all the time you need.'
          : "Paused. Tap Resume when you're ready.";
    }
    if (speech.text.isEmpty) {
      return widget.isStory ? 'Recording your story. Go ahead.' : "Go ahead, I'm listening";
    }
    return widget.isStory
        ? 'Recording your story. Tap Save to my book when you finish.'
        : "I'm listening. Tap I'm done when you finish.";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        bottomNavigationBar: DiaryNavBar(
          current: widget.isStory ? 2 : 0,
          style: p.nav,
          beforeLeave: () async {
            _leaving = true;
            await speech.cancel();
          },
        ),
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: speech,
            builder: (context, _) {
              final live = speech.isActive && speech.errorMessage == null;
              final words = speech.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
              final cut = math.max(0, words.length - 3);
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        TextButton(
                          onPressed: _cancel,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: Text('Cancel', style: GvText.bold(size: 18, color: p.soft)),
                        ),
                        const Spacer(),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: live ? const Color(0xFFF2A57E) : p.tail,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(duration(speech.seconds),
                            style: GvText.body(size: 18, color: p.text)),
                      ],
                    ),
                    if (widget.isStory) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: p.chip,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LIFE STORY',
                                style: GvText.bold(size: 14, color: p.status)),
                            const SizedBox(height: 4),
                            Text(widget.storyQuestion!,
                                style: GvText.body(size: 19, color: p.text, height: 1.35)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(_status(), style: GvText.body(size: 17, color: p.status)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        reverse: true,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: words.take(cut).join(' ')),
                              if (cut > 0) const TextSpan(text: ' '),
                              TextSpan(
                                text: words.skip(cut).join(' '),
                                style: TextStyle(color: p.tail),
                              ),
                            ]),
                            style: GvText.body(
                                size: widget.isStory ? 24 : 26, color: p.text, height: 1.42),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 56,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 15; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 6,
                              height: live
                                  ? 8 +
                                      (0.3 + 0.7 * speech.level) *
                                          42 *
                                          math.sin(_tick * 0.8 + i * 1.7).abs()
                                  : 6,
                              decoration: BoxDecoration(
                                color: live ? (i % 3 == 1 ? p.barB : p.barA) : p.barIdle,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Semantics(
                        button: true,
                        label: widget.isStory ? 'Save to my book' : "I'm done",
                        child: GestureDetector(
                          onTap: _done,
                          child: Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              color: p.text,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: p.text.withValues(alpha: 0.12), spreadRadius: 10),
                              ],
                            ),
                            child: Icon(
                                widget.isStory ? Icons.menu_book_rounded : Icons.check_rounded,
                                size: 44,
                                color: p.bg),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(widget.isStory ? 'Save to my book' : "I'm done",
                        textAlign: TextAlign.center,
                        style: GvText.bold(size: 20, color: p.text)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PillButton(
                          label: speech.paused ? 'Resume' : 'Pause',
                          icon: speech.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          bg: p.chip,
                          fg: p.text,
                          onPressed: speech.paused ? speech.resume : speech.pause,
                        ),
                        const SizedBox(width: 8),
                        PillButton(
                          label: 'Start over',
                          icon: Icons.replay_rounded,
                          bg: p.chip,
                          fg: p.text,
                          onPressed: speech.startOver,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
