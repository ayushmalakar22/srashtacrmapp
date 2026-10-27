import 'package:flutter/material.dart';

/// A titled card that groups related form fields. Fades and slides in when the
/// screen opens; [index] staggers the animation so sections appear in order.
class FormSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final List<Widget> children;
  final int index;
  final double gap;

  const FormSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.trailing,
    this.index = 0,
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(SizedBox(height: gap));
      spaced.add(children[i]);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: child),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.primary),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 14),
              ...spaced,
            ],
          ),
        ),
      ),
    );
  }
}
