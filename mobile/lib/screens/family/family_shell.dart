import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../widgets/nav_bar.dart';
import 'ask_tab.dart';
import 'health_tab.dart';
import 'people_tab.dart';
import 'updates_tab.dart';

/// David's app: People, Updates, Health, Ask.
class FamilyShell extends StatelessWidget {
  const FamilyShell({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = context.select<AppState, int>((s) => s.familyTab);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: tab,
          children: const [PeopleTab(), UpdatesTab(), HealthTab(), AskTab()],
        ),
      ),
      bottomNavigationBar: GvNavBar(
        items: familyNavItems,
        current: tab,
        onTap: context.read<AppState>().setFamilyTab,
      ),
    );
  }
}
