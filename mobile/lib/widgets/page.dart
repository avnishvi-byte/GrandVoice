import 'package:flutter/material.dart';

import '../theme.dart';

/// Full-height page that scrolls when the keyboard is open or the text is
/// large, while still letting a [Spacer] push the main button to the bottom.
class FillScroll extends StatelessWidget {
  const FillScroll({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 24),
    this.gap = 20,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - padding.vertical),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: crossAxisAlignment,
              children: _withGaps(children, gap),
            ),
          ),
        ),
      ),
    );
  }
}

List<Widget> _withGaps(List<Widget> children, double gap) {
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0 && children[i] is! Spacer && children[i - 1] is! Spacer) {
      out.add(SizedBox(height: gap));
    }
    out.add(children[i]);
  }
  return out;
}

/// Page title + optional subtitle.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.size = 34});

  final String title;
  final String? subtitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GvText.title(size: size)),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: GvText.body(color: GvColors.muted)),
        ],
      ],
    );
  }
}

/// "Section" label like "I'll also update" or "Coming up".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: GvText.bold());
}

/// Rows inside a white card separated by thin lines.
class DividedCard extends StatelessWidget {
  const DividedCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GvCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: GvColors.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text, style: GvText.body(size: 16, color: Colors.white)),
      backgroundColor: GvColors.ink,
      behavior: SnackBarBehavior.floating,
    ));
}
