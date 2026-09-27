import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../widgets/nav_bar.dart';
import 'circle_tab.dart';
import 'home_tab.dart';
import 'journal_tab.dart';
import 'today_tab.dart';

/// Rosa's app: Talk, Today, Journal, Circle.
class DiaryShell extends StatelessWidget {
  const DiaryShell({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = context.select<AppState, int>((s) => s.diaryTab);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: tab,
          children: const [HomeTab(), TodayTab(), JournalTab(), CircleTab()],
        ),
      ),
      bottomNavigationBar: GvNavBar(
        items: diaryNavItems,
        current: tab,
        onTap: context.read<AppState>().setDiaryTab,
      ),
    );
  }
}
