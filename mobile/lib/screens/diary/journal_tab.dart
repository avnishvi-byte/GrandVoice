import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/time_format.dart';
import '../../widgets/page.dart';
import 'life_story_screen.dart';

/// 2.4 My journal: every entry grouped by day, newest first, with its time.
class JournalTab extends StatefulWidget {
  const JournalTab({super.key});

  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<JournalTab> {
  final _search = TextEditingController();
  String? _openId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final q = _search.text.trim().toLowerCase();
    final list = s.dayEntries.where((e) => q.isEmpty || e.text.toLowerCase().contains(q)).toList();

    // Group by calendar day, keeping newest first.
    final groups = <DateTime, List<JournalEntry>>{};
    for (final e in list) {
      groups.putIfAbsent(dayOnly(e.createdAt), () => []).add(e);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Text('My journal', style: GvText.title()),
        const SizedBox(height: 20),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: GvText.body(size: 18),
          decoration: InputDecoration(
            hintText: 'Search my days',
            prefixIcon: const Icon(Icons.search_rounded, color: GvColors.muted),
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(_search.clear),
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE6DFD2), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: GvColors.teal, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Material(
          color: GvColors.emberSoft,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LifeStoryScreen())),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.auto_stories_outlined, color: GvColors.emberDark),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Life Story', style: GvText.bold(size: 19)),
                        Text('A new question is waiting',
                            style: GvText.body(size: 15, color: const Color(0xFF6B3A22))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: GvColors.emberDark),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (q.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionLabel('${list.length} ${list.length == 1 ? 'match' : 'matches'}'),
          )
        else if (s.todayEntry == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Nothing yet today. Tap Talk to add your day.',
                style: GvText.body(color: GvColors.muted)),
          ),
        if (list.isEmpty && q.isNotEmpty)
          GvCard(
            child: Center(
              child: Text('Nothing found for "${_search.text.trim()}"',
                  style: GvText.body(color: GvColors.muted)),
            ),
          ),
        for (final day in groups.keys) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Row(
              children: [
                SectionLabel(dayLabel(day)),
                const SizedBox(width: 8),
                if (dayLabel(day) == 'Today' || dayLabel(day) == 'Yesterday')
                  Text(longDate(day), style: GvText.body(size: 15, color: GvColors.muted)),
              ],
            ),
          ),
          DividedCard(children: [
            for (final e in groups[day]!) _EntryRow(
              entry: e,
              open: _openId == e.id,
              onTap: () => setState(() => _openId = _openId == e.id ? null : e.id),
            ),
          ]),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.open, required this.onTap});

  final JournalEntry entry;
  final bool open;
  final VoidCallback onTap;

  Future<void> _confirmDelete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Delete this entry?', style: GvText.title(size: 24)),
        content: Text('It will be removed from your journal.', style: GvText.body()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text('Delete', style: GvText.bold(color: GvColors.emberDark)),
          ),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      context.read<AppState>().deleteEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 16, color: GvColors.muted),
                const SizedBox(width: 6),
                Text(clock(entry.createdAt), style: GvText.body(size: 15, color: GvColors.muted)),
                if (entry.durationSeconds > 0) ...[
                  Text(' · ${duration(entry.durationSeconds)} spoken',
                      style: GvText.body(size: 15, color: GvColors.muted)),
                ],
                const Spacer(),
                Text(
                  entry.shared ? 'Shared' : 'Only me',
                  style: entry.shared
                      ? GvText.bold(size: 15, color: GvColors.teal)
                      : GvText.body(size: 15, color: GvColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.text,
              maxLines: open ? null : 3,
              overflow: open ? null : TextOverflow.ellipsis,
              style: GvText.body(size: 18, height: 1.45),
            ),
            if (open) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PillButton(
                    label: entry.shared ? 'Make private' : 'Share with family',
                    icon: entry.shared ? Icons.lock_outline : Icons.people_outline_rounded,
                    bg: GvColors.tealSoft,
                    fg: GvColors.teal,
                    onPressed: () => context.read<AppState>().toggleShared(entry.id),
                  ),
                  PillButton(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    bg: Colors.white,
                    fg: GvColors.emberDark,
                    border: GvColors.emberBorder,
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
