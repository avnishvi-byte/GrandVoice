import 'package:flutter/material.dart';

/// Colours taken from the Grandvoice prototype.
class GvColors {
  static const deepTeal = Color(0xFF133936);
  static const teal = Color(0xFF1F5F5B);
  static const tealSoft = Color(0xFFDCEBE7);
  static const tealBorder = Color(0xFFA9CEC6);
  static const champagne = Color(0xFFE2BE86);
  static const ember = Color(0xFFB4532A);
  static const emberDark = Color(0xFF8A3B1B);
  static const emberSoft = Color(0xFFF6E1D5);
  static const emberBorder = Color(0xFFE8B89C);
  static const ivory = Color(0xFFF6F1E8);
  static const ink = Color(0xFF1E2B2F);
  static const muted = Color(0xFF56636A);
  static const body = Color(0xFF3F4D52);
  static const faint = Color(0xFF8A969B);
  static const line = Color(0xFFF0EAE0);
  static const fieldBorder = Color(0xFFD8CFBF);
  static const track = Color(0xFFE0D8CA);
  static const warnBg = Color(0xFFFBEBD0);
  static const warnFg = Color(0xFF4F3A10);
  static const listenBg = Color(0xFF163F3C);
  static const storyBg = Color(0xFF6B2E17);
}

class GvText {
  /// Serif display face used for page titles.
  static TextStyle title({double size = 34, Color color = GvColors.ink}) =>
      TextStyle(
        fontFamily: 'Fraunces',
        fontVariations: const [FontVariation('wght', 600), FontVariation('opsz', 72)],
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.1,
        color: color,
      );

  /// Body face (Atkinson Hyperlegible, designed for low vision readers).
/// Fonts are bundled in assets/fonts so the app works offline.
  static TextStyle body({
    double size = 17,
    Color color = GvColors.ink,
    FontWeight weight = FontWeight.w400,
    double? height,
  }) =>
      TextStyle(
        fontFamily: 'Atkinson',
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
      );

  static TextStyle bold({double size = 17, Color color = GvColors.ink}) =>
      body(size: size, color: color, weight: FontWeight.w700);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Atkinson',
    colorScheme: ColorScheme.fromSeed(
      seedColor: GvColors.teal,
      primary: GvColors.teal,
      surface: GvColors.ivory,
    ),
    scaffoldBackgroundColor: GvColors.ivory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
        fontFamily: 'Atkinson', bodyColor: GvColors.ink, displayColor: GvColors.ink),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? GvColors.teal : Colors.white,
      ),
      side: const BorderSide(color: GvColors.fieldBorder, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}

const cardShadow = [
  BoxShadow(color: Color(0x0F1E2B2F), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0D1E2B2F), blurRadius: 20, offset: Offset(0, 6)),
];

/// White rounded card with the soft prototype shadow.
class GvCard extends StatelessWidget {
  const GvCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.border,
    this.color = Colors.white,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BoxBorder? border;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: cardShadow,
        border: border,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Big 64px primary button.
class GvButton extends StatelessWidget {
  const GvButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = GvColors.teal,
    this.textColor = Colors.white,
    this.borderColor,
    this.height = 64,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: borderColor == null
                ? BorderSide.none
                : BorderSide(color: borderColor!, width: 2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 24), const SizedBox(width: 10)],
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: GvText.bold(size: 21, color: textColor)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large labelled text field (60px tall, 20px text).
class GvField extends StatelessWidget {
  const GvField({
    super.key,
    required this.label,
    this.controller,
    this.obscure = false,
    this.keyboard,
    this.onChanged,
    this.hint,
    this.trailing,
    this.helper,
    this.helperColor = GvColors.muted,
    this.borderColor = GvColors.fieldBorder,
    this.width,
  });

  final String label;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;
  final String? hint;
  final Widget? trailing;
  final String? helper;
  final Color helperColor;
  final Color borderColor;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: borderColor, width: 2),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GvText.bold()),
        const SizedBox(height: 8),
        SizedBox(
          width: width,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            onChanged: onChanged,
            style: GvText.body(size: 20),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              enabledBorder: border,
              border: border,
              focusedBorder: border.copyWith(
                borderSide: const BorderSide(color: GvColors.teal, width: 2),
              ),
              suffixIcon: trailing,
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(helper!, style: GvText.body(size: 15, color: helperColor)),
        ],
      ],
    );
  }
}

/// Dropdown styled like [GvField].
class GvSelect extends StatelessWidget {
  const GvSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GvText.bold()),
        const SizedBox(height: 8),
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GvColors.fieldBorder, width: 2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: GvText.body(size: 20),
              items: [
                for (final o in options)
                  DropdownMenuItem(value: o, child: Text(o)),
              ],
              onChanged: (v) => v == null ? null : onChanged(v),
            ),
          ),
        ),
      ],
    );
  }
}

/// Back arrow + "Step x of y" + progress bar used in sign-up.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const GvBackButton(),
            const Spacer(),
            Text('Step $step of $total',
                style: GvText.body(size: 16, color: GvColors.muted)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 1; i <= total; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= step ? GvColors.teal : GvColors.track,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class GvBackButton extends StatelessWidget {
  const GvBackButton({super.key, this.color = GvColors.ink});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-12, 0),
      child: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: color, size: 22),
        tooltip: 'Back',
      ),
    );
  }
}

/// Round letter avatar ("R", "D"...).
class LetterAvatar extends StatelessWidget {
  const LetterAvatar({
    super.key,
    required this.letter,
    this.size = 48,
    this.bg = GvColors.emberSoft,
    this.fg = GvColors.emberDark,
  });

  final String letter;
  final double size;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(letter, style: GvText.bold(size: size * 0.4, color: fg)),
    );
  }
}

/// Coloured banner with icon, title and subtitle (status / reminders).
class Banner2 extends StatelessWidget {
  const Banner2({
    super.key,
    required this.title,
    this.subtitle,
    required this.bg,
    required this.fg,
    this.icon,
    this.onTap,
    this.trailing,
    this.subColor,
  });

  final String title;
  final String? subtitle;
  final Color bg;
  final Color fg;
  final Color? subColor;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg, size: 26),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GvText.bold(size: 18, color: fg)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: GvText.body(size: 15, color: subColor ?? fg)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (trailing == null && onTap != null)
                Icon(Icons.chevron_right_rounded, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small rounded square icon tile used on list cards.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.bg = GvColors.emberSoft,
    this.fg = GvColors.emberDark,
    this.size = 42,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: fg, size: size * 0.55),
    );
  }
}

/// Pill-shaped secondary button (Play, Say thanks, Remind her...).
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.bg = GvColors.teal,
    this.fg = Colors.white,
    this.border,
    this.height = 44,
    this.icon,
    this.radius = 22,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color bg;
  final Color fg;
  final Color? border;
  final double height;
  final IconData? icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: border == null
                ? BorderSide.none
                : BorderSide(color: border!, width: 2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Text(label, style: GvText.bold(size: 16, color: fg)),
          ],
        ),
      ),
    );
  }
}
