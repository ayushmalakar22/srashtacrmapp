import 'package:flutter/material.dart';

class SortOption {
  final String value;
  final String label;
  const SortOption(this.value, this.label);
}

/// "Sort by" list in a bottom sheet; returns the chosen value (or null).
Future<String?> showSortSheet(
  BuildContext context, {
  required List<SortOption> options,
  required String value,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Sort by',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ),
          for (final o in options)
            ListTile(
              title: Text(o.label),
              trailing: o.value == value
                  ? Icon(Icons.check_circle,
                      color: Theme.of(ctx).colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, o.value),
            ),
        ],
      ),
    ),
  );
}
