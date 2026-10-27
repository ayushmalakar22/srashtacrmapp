import 'package:flutter/material.dart';
import 'compact_search_field.dart';
import 'popup_title.dart';

class SelectOption {
  final String value;
  final String label;
  const SelectOption(this.value, this.label);
}

/// Drop-in replacement for DropdownButtonFormField that opens a full-height
/// bottom sheet with a search bar, so long lists (countries, customers, ...)
/// are easy to use on small screens.
class SearchableSelectField extends StatelessWidget {
  final String label;
  final List<SelectOption> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final InputDecoration? decoration;

  const SearchableSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.validator,
    this.decoration,
  });

  String? get _selectedLabel {
    for (final o in options) {
      if (o.value == value) return o.label;
    }
    return null;
  }

  Future<void> _open(BuildContext context, FormFieldState<String> field) async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => _SelectSheet(title: label, options: options, selected: value),
    );
    if (picked != null) {
      onChanged(picked);
      field.didChange(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (_) => validator?.call(value),
      builder: (field) {
        final text = _selectedLabel;
        final base = decoration ?? InputDecoration(labelText: label);
        return InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => _open(context, field),
          child: InputDecorator(
            decoration: base.copyWith(
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            isEmpty: text == null,
            child: text == null
                ? null
                : Text(text, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge),
          ),
        );
      },
    );
  }
}

class _SelectSheet extends StatefulWidget {
  final String title;
  final List<SelectOption> options;
  final String? selected;
  const _SelectSheet({required this.title, required this.options, required this.selected});

  @override
  State<_SelectSheet> createState() => _SelectSheetState();
}

class _SelectSheetState extends State<_SelectSheet> {
  String _query = '';

  void _setQuery(String v) => setState(() => _query = v);

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.options
        : (widget.options.where((o) => o.label.toLowerCase().contains(q)).toList()
          // Names that start with the search text come first.
          ..sort((a, b) {
            final aStarts = a.label.toLowerCase().startsWith(q) ? 0 : 1;
            final bStarts = b.label.toLowerCase().startsWith(q) ? 0 : 1;
            return aStarts.compareTo(bStarts);
          }));
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
              child: PopupTitle(widget.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: CompactSearchField(autofocus: true, onChanged: _setQuery),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No results', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final o = filtered[i];
                        final isSel = o.value == widget.selected;
                        return ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -2),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          title: Text(o.label, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                          trailing: isSel ? Icon(Icons.check, color: cs.primary) : null,
                          selected: isSel,
                          onTap: () => Navigator.pop(context, o.value),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
