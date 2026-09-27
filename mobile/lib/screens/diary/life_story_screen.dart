import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/time_format.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/page.dart';
import 'listening_screen.dart';

/// 3.1 Life Story: one memory question a week, answered by voice, collected
/// into "My book".
class LifeStoryScreen extends StatefulWidget {
  const LifeStoryScreen({super.key});

  @override
  State<LifeStoryScreen> createState() => _LifeStoryScreenState();
}

class _LifeStoryScreenState extends State<LifeStoryScreen> {
  static const _questions = [
    ('Tell me about your very first job. What did a day there feel like?', 'My first job'),
    ('What song takes you straight back to being twenty?', 'The song from when I was twenty'),
    ('Tell me about the house you grew up in.', 'The house I grew up in'),
    ('What is the best advice anyone ever gave you?', 'The best advice I ever got'),
  ];

  int _qi = 0;
  bool _book = false;
  String? _openId;
  DateTime? _savedAt;

  Future<void> _tell() async {
    final (question, title) = _questions[_qi];
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ListeningScreen(storyQuestion: question, storyTitle: title),
    ));
    if (saved == true && mounted) setState(() => _savedAt = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final stories = s.stories;

    return Scaffold(
      bottomNavigationBar: const DiaryNavBar(current: 2),
      body: SafeArea(
        bottom: false,
        child: _book ? _buildBook(stories) : _buildAsk(stories.length),
      ),
    );
  }

  Widget _backLink(String label, VoidCallback onTap) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: const EdgeInsets.only(right: 8)),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: GvColors.teal),
          label: Text(label, style: GvText.bold(color: GvColors.teal)),
        ),
      );

  Widget _buildAsk(int count) {
    return FillScroll(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      gap: 16,
      children: [
        _backLink('Journal', () => Navigator.of(context).pop()),
        const Spacer(),
        if (_savedAt != null)
          Banner2(
            bg: GvColors.tealSoft,
            fg: GvColors.teal,
            title: 'Added to your book at ${clock(_savedAt!)}. Your family can read it now.',
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("This week's Life Story question",
                style: GvText.bold(color: GvColors.emberDark)),
            const SizedBox(height: 14),
            Text(_questions[_qi].$1, style: GvText.body(size: 32, height: 1.25)),
          ],
        ),
        const SizedBox(height: 12),
        GvButton(
          label: 'Tell this story',
          icon: Icons.mic_rounded,
          color: GvColors.emberDark,
          onPressed: _tell,
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _qi = (_qi + 1) % _questions.length),
            child: Text('Ask me something else', style: GvText.bold(color: GvColors.emberDark)),
          ),
        ),
        const Spacer(),
        GvCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          onTap: () => setState(() => _book = true),
          child: Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: GvColors.teal),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Read my book', style: GvText.bold(size: 18)),
                    Text('$count ${count == 1 ? 'story' : 'stories'} so far',
                        style: GvText.body(size: 15, color: GvColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: GvColors.faint),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBook(List<JournalEntry> stories) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      children: [
        _backLink("This week's question", () => setState(() => _book = false)),
        const SizedBox(height: 8),
        PageTitle('My book', subtitle: '${stories.length} stories, told in your own words'),
        const SizedBox(height: 16),
        DividedCard(children: [
          for (final st in stories)
            InkWell(
              onTap: () => setState(() => _openId = _openId == st.id ? null : st.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(st.title ?? 'A story', style: GvText.title(size: 20)),
                    const SizedBox(height: 4),
                    Text(
                      'Told ${isSameDay(st.createdAt, DateTime.now()) ? 'today at ${clock(st.createdAt)} · new' : DateFormat('MMM d').format(st.createdAt)}',
                      style: GvText.body(size: 15, color: GvColors.muted),
                    ),
                    if (_openId == st.id) ...[
                      const SizedBox(height: 10),
                      Text(st.text, style: GvText.body(size: 17, height: 1.5, color: GvColors.body)),
                    ],
                  ],
                ),
              ),
            ),
        ]),
      ],
    );
  }
}
