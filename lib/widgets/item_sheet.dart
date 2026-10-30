import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'popup_title.dart';

/// Bottom sheet to add or edit an item: name, rate, unit and taxes only.
/// Pops with `true` once saved or deleted.
class ItemSheet extends StatefulWidget {
  /// Null when adding a new item.
  final Map<String, dynamic>? item;
  final List taxes;
  final bool canDelete;
  final String symbol;

  const ItemSheet(
      {super.key,
      this.item,
      required this.taxes,
      this.symbol = '\$',
      this.canDelete = false});

  @override
  State<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<ItemSheet> {
  late final _name =
      TextEditingController(text: widget.item?['description']?.toString());
  late final _rate = TextEditingController(
      text: widget.item == null
          ? ''
          : (double.tryParse('${widget.item!['rate']}') ?? 0).toString());
  late final _unit =
      TextEditingController(text: widget.item?['unit']?.toString());
  late final Set<String> _taxIds = {
    for (final k in ['tax', 'tax2'])
      if (widget.item?[k] != null) widget.item![k].toString(),
  };
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _run(Future<Map<String, dynamic>> Function() call,
      String fallbackError) async {
    setState(() => _saving = true);
    try {
      final res = await call();
      if (!mounted) return;
      if (res['status'] == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _saving = false);
        _toast(res['message']?.toString() ?? fallbackError);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Cannot reach the server. Check Wi-Fi and try again.');
    }
  }

  void _save() {
    final rate = double.tryParse(_rate.text.trim());
    if (_name.text.trim().isEmpty) return _toast('Enter the item name');
    if (rate == null || rate < 0) return _toast('Enter a valid rate');
    _run(
      () => ApiService.saveItem({
        if (_isEdit) 'id': widget.item!['id'],
        'description': _name.text.trim(),
        'rate': rate,
        'unit': _unit.text.trim(),
        'taxes': _taxIds.toList(),
      }),
      'Failed to save item',
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(
            '"${widget.item!['description']}" will be removed from the list. '
            'Invoices that already use it are not changed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (ok == true) {
      _run(() => ApiService.deleteItem(widget.item!['id'].toString()),
          'Failed to delete item');
    }
  }

  void _toggleTax(String id, bool on) {
    if (on && _taxIds.length >= 2) {
      return _toast('An item can have at most 2 taxes');
    }
    setState(() => on ? _taxIds.add(id) : _taxIds.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PopupTitle(_isEdit ? 'Edit Item' : 'New Item',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Item name *'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _rate,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Rate *', prefixText: '${widget.symbol} '),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _unit,
                    decoration: const InputDecoration(
                        labelText: 'Unit', hintText: 'pcs, kg'),
                  ),
                ),
              ],
            ),
            if (widget.taxes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Tax',
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in widget.taxes)
                    FilterChip(
                      label: Text('${t['name']} ${t['taxrate']}%'),
                      selected: _taxIds.contains(t['id'].toString()),
                      onSelected: (on) => _toggleTax(t['id'].toString(), on),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: Text(_isEdit ? 'Save Changes' : 'Add Item'),
            ),
            if (_isEdit && widget.canDelete)
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                label: Text('Delete item',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}
