import 'package:flutter/material.dart';

/// Title row for dialogs and bottom sheets with a close (X) button on the right.
class PopupTitle extends StatelessWidget {
  final String title;
  final TextStyle? style;
  const PopupTitle(this.title, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: style)),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
