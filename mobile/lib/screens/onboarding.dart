import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/demo_menu.dart';
import '../widgets/page.dart';
import 'diary/diary_shell.dart';
import 'family/family_shell.dart';

/// Replace the whole stack with Rosa's or David's app.
void openApp(BuildContext context, String role) {
  final state = context.read<AppState>();
  state.setRole(role);
  if (role == 'rosa') {
    state.setDiaryTab(0);
  } else {
    state.setFamilyTab(0);
  }
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => role == 'rosa' ? const DiaryShell() : const FamilyShell(),
    ),
    (_) => false,
  );
}

// ---------------------------------------------------------------- 1.1 Splash

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.forFamily = false});

  final bool forFamily;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _showFor = Duration(seconds: 5);
  Timer? _timer;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_showFor, _next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// After 5 seconds (or a tap): straight into the app if already signed in,
  /// otherwise the sign-in screen.
  void _next() {
    if (_left || !mounted) return;
    _left = true;
    _timer?.cancel();
    final state = context.read<AppState>();
    if (state.signedIn) {
      openApp(context, state.role);
    } else {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignInScreen()));
    }
  }

  bool get forFamily => widget.forFamily;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GvColors.deepTeal,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: Stack(
          children: [
            // Four faint arcs rising from the bottom edge.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SvgPicture.string(_splashArcsSvg, fit: BoxFit.fitWidth),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 56),
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 148,
                              height: 148,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: const Color(0xFF3C6A64), width: 1.5),
                              ),
                              child: SvgPicture.string(_splashFamilySvg, width: 108, height: 108),
                            ),
                            const SizedBox(height: 22),
                            Text('Grandvoice',
                                style: GvText.title(size: 46, color: GvColors.ivory)
                                    .copyWith(height: 1)),
                            const SizedBox(height: 14),
                            Container(width: 44, height: 1.5, color: GvColors.champagne),
                            const SizedBox(height: 14),
                            Text('Speak your day. Family stays close.',
                                style: GvText.body(color: GvColors.champagne)),
                            if (forFamily) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: GvColors.champagne,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('For family and caregivers',
                                    style: GvText.bold(size: 15, color: GvColors.deepTeal)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final o in [1.0, 0.55, 0.25])
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: GvColors.champagne.withValues(alpha: o),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.string(_splashShieldSvg, width: 15, height: 15),
                        const SizedBox(width: 6),
                        Text('HIPAA compliant · Private and encrypted',
                            style: GvText.body(size: 13, color: const Color(0xFF9CC4BD))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Artwork copied unchanged from the Grandvoice prototype splash screen.
const _splashArcsSvg = '''
<svg width="390" height="300" viewBox="0 0 390 300" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M-40 300 A235 235 0 0 1 430 300" stroke="#1B4845" stroke-width="2"/>
<path d="M10 300 A185 185 0 0 1 380 300" stroke="#1B4845" stroke-width="2"/>
<path d="M60 300 A135 135 0 0 1 330 300" stroke="#1B4845" stroke-width="2"/>
<path d="M110 300 A85 85 0 0 1 280 300" stroke="#1B4845" stroke-width="2"/>
</svg>''';

const _splashFamilySvg = '''
<svg width="108" height="108" viewBox="0 0 120 120" fill="none" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg"><circle cx="41" cy="25" r="10" fill="#E2BE86"/><path d="M28 74 V47 Q28 37 38 37 H42 Q52 37 52 47 V74 Z" fill="#E2BE86"/><path d="M28 76 H52 L50 106 H43 L40 86 L37 106 H30 Z" fill="#E2BE86"/><path d="M20 106 V61 Q20 55 26 56" stroke="#E2BE86" stroke-width="4.5" stroke-linecap="round" fill="none"/><path d="M31 43 L22.5 61" stroke="#E2BE86" stroke-width="6.5" stroke-linecap="round"/><path d="M49 43 L59.5 62" stroke="#E2BE86" stroke-width="6.5" stroke-linecap="round"/><circle cx="22.5" cy="61" r="4.5" fill="#E2BE86"/><circle cx="60" cy="63" r="4.5" fill="#E2BE86"/><path d="M86 52 C82 48 75 48 72 50 V66 C75 64 82 64 86 68 C90 64 97 64 100 66 V50 C97 48 90 48 86 52 Z" fill="#D98C5F"/><path d="M86 52 V68" stroke="#133936" stroke-width="2"/><path d="M75.5 55 H82.5 M75.5 59.5 H82.5 M89.5 55 H96.5 M89.5 59.5 H96.5" stroke="#133936" stroke-width="1.8" stroke-linecap="round"/><path d="M76 90 V76 Q76 70 82 70 H90 Q96 70 96 76 V90 Z" fill="#D98C5F"/><path d="M76 91.5 H96 L95 106 H89 L86 97 L83 106 H77 Z" fill="#D98C5F"/><path d="M78.5 74 L65 65" stroke="#D98C5F" stroke-width="6.5" stroke-linecap="round"/><path d="M93.5 74 L100 88" stroke="#D98C5F" stroke-width="6.5" stroke-linecap="round"/><circle cx="64.5" cy="65" r="4.5" fill="#D98C5F"/><circle cx="100" cy="88" r="4.5" fill="#D98C5F"/></svg>''';

const _splashShieldSvg = '''
<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#9CC4BD" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg"><path d="M12 3l7 3v5c0 5-3.5 8.5-7 10-3.5-1.5-7-5-7-10V6z"/><path d="M9 12l2 2 4-4"/></svg>''';

// ---------------------------------------------------------------- 1.2 Sign in

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController(text: 'rosa.m@example.com');
  final _password = TextEditingController(text: 'bridge2026');
  bool _show = false;
  bool _reset = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    final result = await state.login(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      setState(() => _error = result.error);
      return;
    }
    if (result.offline) {
      showSnack(context, "Can't reach the server. Using offline mode on this phone.");
    }
    openApp(context, state.role);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FillScroll(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
          gap: 24,
          children: [
            Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: GvColors.deepTeal,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.record_voice_over_outlined,
                      size: 44, color: GvColors.champagne),
                ),
                const SizedBox(height: 12),
                Text('Grandvoice', style: GvText.title(size: 36, color: GvColors.deepTeal)),
                const SizedBox(height: 12),
                Text('Speak your day. We keep it safe.',
                    textAlign: TextAlign.center,
                    style: GvText.body(size: 18, color: const Color(0xFF4A565C))),
                const SizedBox(height: 8),
              ],
            ),
            GvField(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress),
            GvField(
              label: 'Password',
              controller: _password,
              obscure: !_show,
              trailing: TextButton(
                onPressed: () => setState(() => _show = !_show),
                child: Text(_show ? 'Hide' : 'Show',
                    style: GvText.bold(size: 16, color: GvColors.teal)),
              ),
            ),
            if (_error != null)
              Text(_error!,
                  textAlign: TextAlign.center, style: GvText.bold(color: GvColors.emberDark)),
            GvButton(
                label: _busy ? 'Signing in...' : 'Sign in', onPressed: _busy ? null : _signIn),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('New here?', style: GvText.body(color: GvColors.muted)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateRoleScreen())),
                  child: Text('Create an account',
                      style: GvText.bold(color: GvColors.teal)
                          .copyWith(decoration: TextDecoration.underline)),
                ),
              ],
            ),
            Text('Demo: rosa.m@example.com / bridge2026 opens the diary. david.m@example.com / familyfirst opens the family app.',
                textAlign: TextAlign.center,
                style: GvText.body(size: 14, color: GvColors.muted)),
            const Spacer(),
            TextButton(
              onPressed: () async {
                await context.read<AppState>().resetDemo();
                if (mounted) setState(() => _reset = true);
              },
              child: Text(_reset ? 'Demo reset. Start fresh.' : 'Reset demo data',
                  style: GvText.body(size: 14, color: GvColors.muted)
                      .copyWith(decoration: TextDecoration.underline)),
            ),
            TextButton.icon(
              onPressed: () => showServerDialog(context),
              icon: const Icon(Icons.dns_outlined, size: 16, color: GvColors.muted),
              label: Text('Server settings',
                  style: GvText.body(size: 14, color: GvColors.muted)
                      .copyWith(decoration: TextDecoration.underline)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 16, color: GvColors.muted),
                const SizedBox(width: 8),
                Text('Your words stay private.',
                    style: GvText.body(size: 15, color: GvColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 1.3 Role

class CreateRoleScreen extends StatelessWidget {
  const CreateRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget choice({
      required IconData icon,
      required Color iconBg,
      required Color border,
      required Color linkColor,
      required String title,
      required String body,
      required String link,
      required Widget next,
    }) {
      return GvCard(
        border: Border.all(color: border, width: 2),
        padding: const EdgeInsets.all(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => next)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title, style: GvText.bold(size: 22)),
            const SizedBox(height: 12),
            Text(body, style: GvText.body(color: GvColors.body, height: 1.4)),
            const SizedBox(height: 12),
            Row(children: [
              Text(link, style: GvText.bold(color: linkColor)),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, color: linkColor, size: 20),
            ]),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: FillScroll(
          gap: 18,
          children: [
            const Align(alignment: Alignment.centerLeft, child: GvBackButton()),
            const PageTitle('Welcome to Grandvoice',
                subtitle: 'Who is setting up this phone? You can add the other person later.'),
            choice(
              icon: Icons.mic_none_rounded,
              iconBg: GvColors.teal,
              border: GvColors.tealBorder,
              linkColor: GvColors.teal,
              title: 'I want to keep my own diary',
              body: 'Talk about your day, keep track of your medicines, and share with the people you love.',
              link: 'Set up my diary',
              next: const DiaryNameScreen(),
            ),
            choice(
              icon: Icons.favorite_border_rounded,
              iconBg: GvColors.ember,
              border: GvColors.emberBorder,
              linkColor: GvColors.emberDark,
              title: "I'm caring for someone I love",
              body: "Stay close to a parent, grandparent or relative, and know they're okay each day.",
              link: 'Set up family access',
              next: const FamilyAccountScreen(),
            ),
            const Spacer(),
            Text('Work at a care home? Your team signs up on the Grandvoice website.',
                textAlign: TextAlign.center,
                style: GvText.body(size: 15, color: GvColors.muted, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 1.4 Name

class DiaryNameScreen extends StatefulWidget {
  const DiaryNameScreen({super.key});

  @override
  State<DiaryNameScreen> createState() => _DiaryNameScreenState();
}

class _DiaryNameScreenState extends State<DiaryNameScreen> {
  final _name = TextEditingController(text: 'Rosa Martinez');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = _name.text.trim().split(' ').first;
    return Scaffold(
      body: SafeArea(
        child: FillScroll(
          children: [
            const StepHeader(step: 1, total: 3),
            const SizedBox(height: 4),
            const PageTitle("What's your name?", subtitle: "This is how we'll greet you."),
            GvField(label: 'Your name', controller: _name, onChanged: (_) => setState(() {})),
            if (first.isNotEmpty)
              Text('Lovely to meet you, $first.',
                  style: GvText.body(size: 21, color: GvColors.teal)),
            const Spacer(),
            GvButton(
              label: 'Continue',
              onPressed: _name.text.trim().isEmpty
                  ? null
                  : () {
                      context.read<AppState>().setDiaryName(_name.text);
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DiaryAboutScreen()));
                    },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 1.5 About

class DiaryAboutScreen extends StatefulWidget {
  const DiaryAboutScreen({super.key});

  @override
  State<DiaryAboutScreen> createState() => _DiaryAboutScreenState();
}

class _DiaryAboutScreenState extends State<DiaryAboutScreen> {
  final _age = TextEditingController(text: '78');
  String _gender = 'Female';

  @override
  void dispose() {
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const options = ['Female', 'Male', 'Non-binary', 'Prefer not to say'];
    return Scaffold(
      body: SafeArea(
        child: FillScroll(
          children: [
            const StepHeader(step: 2, total: 3),
            const SizedBox(height: 4),
            const PageTitle('A little about you',
                subtitle: 'This helps us ask the right questions.'),
            GvField(
                label: 'Age', controller: _age, keyboard: TextInputType.number, width: 140),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gender', style: GvText.bold()),
                const SizedBox(height: 8),
                for (var row = 0; row < options.length; row += 2) ...[
                  if (row > 0) const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final o in options.sublist(row, row + 2)) ...[
                        if (o != options[row]) const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: OutlinedButton(
                              onPressed: () => setState(() => _gender = o),
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    _gender == o ? GvColors.tealSoft : Colors.white,
                                side: BorderSide(
                                    color: _gender == o ? GvColors.teal : GvColors.track,
                                    width: 2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(o,
                                  textAlign: TextAlign.center,
                                  style: _gender == o
                                      ? GvText.bold(size: 18)
                                      : GvText.body(size: 18)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
            const Spacer(),
            GvButton(
              label: 'Continue',
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const DiarySecureScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 1.6 Secure

class DiarySecureScreen extends StatefulWidget {
  const DiarySecureScreen({super.key});

  @override
  State<DiarySecureScreen> createState() => _DiarySecureScreenState();
}

class _DiarySecureScreenState extends State<DiarySecureScreen> {
  final _email = TextEditingController(text: 'rosa.m@example.com');
  final _p1 = TextEditingController(text: 'bridge2026');
  final _p2 = TextEditingController(text: 'bridge2026');
  bool _busy = false;
  String? _error;

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    final result = await state.signup(
        name: state.diaryName, email: _email.text, password: _p1.text, diary: true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      setState(() => _error = result.error);
      return;
    }
    if (result.offline) showSnack(context, "Can't reach the server. Using offline mode.");
    openApp(context, 'rosa');
  }

  @override
  void dispose() {
    _email.dispose();
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _p1.text, b = _p2.text;
    final ok = a.length >= 8 && a == b;
    var msg = 'Passwords match';
    if (a.length < 8) {
      msg = 'Use at least 8 letters or numbers';
    } else if (b.isNotEmpty && a != b) {
      msg = "These don't match yet";
    } else if (b.isEmpty) {
      msg = ' ';
    }
    return Scaffold(
      body: SafeArea(
        child: FillScroll(
          children: [
            const StepHeader(step: 3, total: 3),
            const PageTitle('Keep it safe', subtitle: "You'll use these to sign in."),
            GvField(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress),
            GvField(
                label: 'Password',
                controller: _p1,
                obscure: true,
                onChanged: (_) => setState(() {})),
            GvField(
              label: 'Type it again',
              controller: _p2,
              obscure: true,
              onChanged: (_) => setState(() {}),
              borderColor: ok ? GvColors.teal : GvColors.fieldBorder,
              helper: msg,
              helperColor: ok ? GvColors.teal : GvColors.emberDark,
            ),
            const Spacer(),
            if (_error != null) Text(_error!, style: GvText.bold(color: GvColors.emberDark)),
            GvButton(
              label: _busy ? 'Creating...' : 'Create my account',
              onPressed: ok && !_busy ? _create : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 1.7 Family

class FamilyAccountScreen extends StatefulWidget {
  const FamilyAccountScreen({super.key});

  @override
  State<FamilyAccountScreen> createState() => _FamilyAccountScreenState();
}

class _FamilyAccountScreenState extends State<FamilyAccountScreen> {
  final _name = TextEditingController(text: 'David Martinez');
  final _email = TextEditingController(text: 'david.m@example.com');
  final _password = TextEditingController(text: 'familyfirst');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    var result = await state.signup(
        name: _name.text, email: _email.text, password: _password.text, diary: false);
    // The demo David already has an account on the server: sign him in instead.
    if (!result.ok && (result.error ?? '').contains('already has an account')) {
      result = await state.login(_email.text, _password.text);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      setState(() => _error = result.error);
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FamilyConnectScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FillScroll(
          children: [
            const StepHeader(step: 1, total: 2),
            const PageTitle('About you',
                subtitle: 'So your loved one knows who is asking to join.'),
            GvField(label: 'Your name', controller: _name),
            GvField(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress),
            GvField(
              label: 'Password',
              controller: _password,
              obscure: true,
              helper: 'At least 8 letters or numbers',
            ),
            const Spacer(),
            if (_error != null) Text(_error!, style: GvText.bold(color: GvColors.emberDark)),
            GvButton(
                label: _busy ? 'Please wait...' : 'Continue',
                onPressed: _busy ? null : _continue),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 1.8 Connect

class FamilyConnectScreen extends StatefulWidget {
  const FamilyConnectScreen({super.key});

  @override
  State<FamilyConnectScreen> createState() => _FamilyConnectScreenState();
}

class _FamilyConnectScreenState extends State<FamilyConnectScreen> {
  final _name = TextEditingController(text: 'Rosa Martinez');
  final _contact = TextEditingController(text: 'rosa.m@example.com');
  String _rel = 'Mom';

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FillScroll(
          children: [
            const StepHeader(step: 2, total: 2),
            const PageTitle('Who are you caring for?',
                subtitle: "We'll send them a request. You'll see their updates once they say yes."),
            GvField(label: 'Their name', controller: _name),
            GvField(label: 'Their email or phone', controller: _contact),
            GvSelect(
              label: 'They are my',
              value: _rel,
              options: const [
                'Mom', 'Dad', 'Grandma', 'Grandpa', 'Aunt', 'Uncle', 'Other relative', 'Friend'
              ],
              onChanged: (v) => setState(() => _rel = v),
            ),
            const Spacer(),
            GvButton(
              label: 'Send request',
              icon: Icons.send_rounded,
              onPressed: () async {
                final error = await context.read<AppState>().sendFamRequest(
                    name: _name.text.trim(), contact: _contact.text.trim(), rel: _rel);
                if (!context.mounted) return;
                if (error != null) {
                  showSnack(context, error);
                  return;
                }
                openApp(context, 'david');
              },
            ),
            Center(
              child: TextButton(
                onPressed: () => openApp(context, 'david'),
                child: Text('They already invited me',
                    style: GvText.bold(color: GvColors.teal)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
