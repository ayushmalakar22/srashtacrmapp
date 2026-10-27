import 'package:flutter/material.dart';

/// Fades and slides a list item / card in when it first appears. Only the first
/// few items animate (staggered by [index]) so scrolling a long list stays snappy.
class AnimatedEntry extends StatelessWidget {
  final int index;
  final Widget child;
  const AnimatedEntry({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (index > 9) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
      ),
      child: child,
    );
  }
}
