import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/paged_list.dart';
import 'compact_search_field.dart';
import 'paged_footer.dart';
import 'popup_title.dart';

/// Page of rows for the picker: the API's `{status, data: [...], total}` map.
typedef PickerFetch = Future<Map<String, dynamic>> Function(
    int offset, int limit, String search);

/// Full-height sheet to pick one row out of a list that can be huge: the
/// search runs on the server and rows arrive a page at a time. Returns the
/// chosen row, or null when closed.
///
/// [tileBuilder] draws one row; call `select()` from its tap. [footerBuilder]
/// is an optional bottom action (e.g. "New item"); call `done(row)` to close
/// the sheet with a row.
Future<Map?> showPagedPicker(
  BuildContext context, {
  required String title,
  required PickerFetch fetch,
  required Widget Function(Map row, VoidCallback select) tileBuilder,
  String searchHint = 'Search',
  String emptyText = 'Nothing found',
  Widget Function(BuildContext context, void Function(Map? row) done)?
      footerBuilder,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<Map>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (_) => _PagedPickerSheet(
      title: title,
      fetch: fetch,
      tileBuilder: tileBuilder,
      emptyText: emptyText,
      footerBuilder: footerBuilder,
    ),
  );
}

class _PagedPickerSheet extends StatefulWidget {
  final String title;
  final PickerFetch fetch;
  final Widget Function(Map row, VoidCallback select) tileBuilder;
  final String emptyText;
  final Widget Function(BuildContext context, void Function(Map? row) done)?
      footerBuilder;

  const _PagedPickerSheet({
    required this.title,
    required this.fetch,
    required this.tileBuilder,
    required this.emptyText,
    required this.footerBuilder,
  });

  @override
  State<_PagedPickerSheet> createState() => _PagedPickerSheetState();
}

class _PagedPickerSheetState extends State<_PagedPickerSheet> {
  late final PagedList _list =
      PagedList((offset, limit) => widget.fetch(offset, limit, _query));
  final _scroll = ScrollController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _list.addListener(() {
      if (mounted) setState(() {});
    });
    _list.refresh();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) _list.loadMore();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _list.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _query = v.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _list.refresh);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
              child: PopupTitle(widget.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: CompactSearchField(autofocus: false, onChanged: _onSearch),
            ),
            const Divider(height: 1),
            Expanded(child: _body()),
            if (widget.footerBuilder != null) ...[
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
                child: widget.footerBuilder!(
                    context, (row) => Navigator.pop(context, row)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_list.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_list.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_list.error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: _list.refresh, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_list.items.isEmpty) {
      return Center(
          child: Text(
              _query.isEmpty ? widget.emptyText : 'No match for "$_query"',
              style: const TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      controller: _scroll,
      itemCount: _list.items.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, i) {
        if (i == _list.items.length) return PagedFooter(list: _list);
        final row = _list.items[i] as Map;
        return widget.tileBuilder(row, () => Navigator.pop(context, row));
      },
    );
  }
}

/// Form field that looks like a dropdown and calls [onTap] to open a picker.
class PickerField extends StatelessWidget {
  final InputDecoration decoration;
  final String? text; // null = nothing chosen yet
  final VoidCallback onTap;
  final String? Function(String?)? validator;

  const PickerField({
    super.key,
    required this.decoration,
    required this.text,
    required this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (_) => validator?.call(text),
      builder: (field) => InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: InputDecorator(
          decoration: decoration.copyWith(
            errorText: field.errorText,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          isEmpty: text == null,
          child: text == null
              ? null
              : Text(text!,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}
