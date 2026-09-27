import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/demo/lock_screen.dart';
import '../screens/onboarding.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'page.dart';

/// Small "..." button for hackathon demos: switch between Rosa's and David's
/// phone, preview their lock-screen notifications, pick the server, or reset.
/// A dot on the button shows whether the server is connected.
class DemoMenuButton extends StatelessWidget {
  const DemoMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Stack(
      alignment: Alignment.topRight,
      children: [
        IconButton(
          tooltip: 'Demo menu',
          icon: const Icon(Icons.more_horiz_rounded, color: GvColors.muted),
          onPressed: () => _open(context),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s.signedIn && s.online ? const Color(0xFF2E9E6A) : const Color(0xFFCFC5B3),
            ),
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context) {
    final state = context.read<AppState>();
    final isRosa = state.role == 'rosa';
    final status = !state.signedIn
        ? 'Offline mode (data on this phone only)'
        : state.online
            ? 'Connected to ${state.api.baseUrl}'
            : 'Server not reachable. Retrying...';
    showModalBottomSheet(
      context: context,
      backgroundColor: GvColors.ivory,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) {
        Widget item(IconData icon, String label, VoidCallback onTap) => ListTile(
              leading: Icon(icon, color: GvColors.teal),
              title: Text(label, style: GvText.bold(size: 18)),
              onTap: () {
                Navigator.of(sheet).pop();
                onTap();
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Text('Demo menu', style: GvText.title(size: 24)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(status, style: GvText.body(size: 14, color: GvColors.muted)),
              ),
              item(
                Icons.swap_horiz_rounded,
                isRosa ? "Switch to David's phone" : "Switch to Rosa's phone",
                () => _switchPhone(context, isRosa ? 'david' : 'rosa'),
              ),
              item(Icons.notifications_none_rounded, "Rosa's lock screen", () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LockScreen(forRosa: true)));
              }),
              item(Icons.notifications_none_rounded, "David's lock screen", () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LockScreen(forRosa: false)));
              }),
              item(Icons.dns_outlined, 'Server', () => showServerDialog(context)),
              item(Icons.logout_rounded, 'Sign out', () async {
                await state.signOut();
                if (!context.mounted) return;
                _toSignIn(context);
              }),
              item(Icons.restart_alt_rounded, 'Reset demo data', () async {
                await state.resetDemo();
                if (!context.mounted) return;
                _toSignIn(context);
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// With a server, "switching phones" means signing in as the other person.
  Future<void> _switchPhone(BuildContext context, String role) async {
    final state = context.read<AppState>();
    if (state.signedIn) {
      await state.signOut();
      final result = role == 'david'
          ? await state.login('david.m@example.com', 'familyfirst')
          : await state.login('rosa.m@example.com', 'bridge2026');
      if (!context.mounted) return;
      if (!result.ok) {
        showSnack(context, result.error ?? 'Could not switch.');
        _toSignIn(context);
        return;
      }
      openApp(context, state.role);
    } else {
      openApp(context, role);
    }
  }

  void _toSignIn(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()), (_) => false);
  }
}

/// Set the backend address (a real phone needs the laptop's Wi-Fi IP).
Future<void> showServerDialog(BuildContext context) async {
  final state = context.read<AppState>();
  final url = TextEditingController(text: state.api.baseUrl);
  String? result;
  await showDialog<void>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setState) => AlertDialog(
        backgroundColor: GvColors.ivory,
        title: Text('Server', style: GvText.title(size: 24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Where the FastAPI backend runs. On a real phone use your laptop\'s '
              'Wi-Fi address, e.g. http://192.168.1.20:8000',
              style: GvText.body(size: 15, color: GvColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              style: GvText.body(size: 17),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            if (result != null) ...[
              const SizedBox(height: 10),
              Text(result!, style: GvText.bold(size: 15, color: GvColors.teal)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await state.setServerUrl(url.text);
              final health = await state.checkServer();
              setState(() {
                result = health == null
                    ? 'Not reachable. Is the server running?'
                    : health['claude'] == true
                        ? 'Connected. Claude is on (${health['model']}).'
                        : 'Connected. Claude is off (no API key), using simple rules.';
              });
            },
            child: const Text('Test'),
          ),
          FilledButton(
            onPressed: () async {
              await state.setServerUrl(url.text);
              if (d.mounted) Navigator.of(d).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
