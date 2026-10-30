import 'package:flutter/material.dart';

/// Slim pill-shaped search box used inside pickers and popups.
class CompactSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final bool autofocus;
  const CompactSearchField(
      {super.key, required this.onChanged, this.autofocus = false});

  @override
  State<CompactSearchField> createState() => _CompactSearchFieldState();
}

class _CompactSearchFieldState extends State<CompactSearchField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      autofocus: widget.autofocus,
      style: const TextStyle(fontSize: 15),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search...',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        prefixIcon: const Icon(Icons.search, size: 20),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 36),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 36),
        // Rebuilds on every keystroke via the controller so the clear button
        // only shows when there is text to clear.
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _ctrl,
          builder: (_, v, __) => v.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _ctrl.clear();
                    widget.onChanged('');
                  },
                ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
      ),
      onChanged: widget.onChanged,
    );
  }
}
