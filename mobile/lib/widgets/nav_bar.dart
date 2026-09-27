import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

class NavItem {
  const NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

const diaryNavItems = [
  NavItem('Talk', Icons.mic_none_rounded),
  NavItem('Today', Icons.medication_outlined),
  NavItem('Journal', Icons.article_outlined),
  NavItem('Circle', Icons.people_outline_rounded),
];

const familyNavItems = [
  NavItem('People', Icons.people_outline_rounded),
  NavItem('Updates', Icons.home_outlined),
  NavItem('Health', Icons.favorite_border_rounded),
  NavItem('Ask', Icons.auto_awesome_outlined),
];

/// Colour sets for the normal, listening (dark teal) and story (brown) screens.
class NavStyle {
  const NavStyle(this.bg, this.border, this.active, this.inactive, this.pill);
  final Color bg, border, active, inactive, pill;

  static const light = NavStyle(Colors.white, Color(0xFFEAE3D6), GvColors.teal,
      GvColors.muted, GvColors.tealSoft);
  static const listening = NavStyle(Color(0xFF0E2C29), Color(0xFF245450),
      GvColors.ivory, Color(0xFFB9D3CE), Color(0xFF2F6E68));
  static const story = NavStyle(Color(0xFF4A1F0F), Color(0xFF6E3822),
      GvColors.ivory, Color(0xFFE8C4AE), GvColors.emberDark);
}

class GvNavBar extends StatelessWidget {
  const GvNavBar({
    super.key,
    required this.items,
    required this.current,
    required this.onTap,
    this.style = NavStyle.light,
  });

  final List<NavItem> items;
  final int current;
  final ValueChanged<int> onTap;
  final NavStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: style.bg,
        border: Border(top: BorderSide(color: style.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 32,
                          decoration: BoxDecoration(
                            color: i == current ? style.pill : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(items[i].icon,
                              color: i == current ? style.active : style.inactive),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].label,
                          style: i == current
                              ? GvText.bold(size: 15, color: style.active)
                              : GvText.body(size: 15, color: style.inactive),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nav bar for screens pushed on top of Rosa's tabs (Listening, Review...).
/// Tapping a tab closes the pushed screens and switches tab.
class DiaryNavBar extends StatelessWidget {
  const DiaryNavBar({super.key, required this.current, this.style = NavStyle.light, this.beforeLeave});

  final int current;
  final NavStyle style;
  final Future<void> Function()? beforeLeave;

  @override
  Widget build(BuildContext context) {
    return GvNavBar(
      items: diaryNavItems,
      current: current,
      style: style,
      onTap: (i) async {
        await beforeLeave?.call();
        if (!context.mounted) return;
        context.read<AppState>().setDiaryTab(i);
        Navigator.of(context).popUntil((r) => r.isFirst);
      },
    );
  }
}
