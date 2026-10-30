import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'item_sheet.dart';
import 'paged_picker.dart';

/// Picks an item for an invoice/estimate line: server-side search, a page at a
/// time, rate / unit / taxes at a glance, or a brand-new item on the spot.
/// Returns the chosen item (with all its columns), or null.
Future<Map?> showItemPicker(
  BuildContext context, {
  required List taxes,
  required String symbol,
  required double Function(Map item) rateOf,
  bool canCreate = false,
}) {
  return showPagedPicker(
    context,
    title: 'Select Item',
    emptyText: 'No items yet',
    fetch: (offset, limit, search) async {
      final res = await ApiService.getItems(
          offset: offset, limit: limit, search: search);
      if (res['status'] != true) return res;
      return {
        'status': true,
        'data': res['data']['items'],
        'total': res['total'],
      };
    },
    tileBuilder: (item, select) => _ItemTile(
        item: item, symbol: symbol, rate: rateOf(item), onTap: select),
    footerBuilder: canCreate
        ? (context, done) => SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New item'),
                onPressed: () async {
                  final res = await showModalBottomSheet<Object>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    showDragHandle: true,
                    builder: (_) => ItemSheet(taxes: taxes, symbol: symbol),
                  );
                  if (res == null || res == true) return;
                  // fetch the new item with all its columns, then use it
                  final one = await ApiService.getItems(id: res.toString());
                  final rows = one['status'] == true
                      ? (one['data']['items'] as List)
                      : const [];
                  if (rows.isNotEmpty) done(rows.first as Map);
                },
              ),
            )
        : null,
  );
}

class _ItemTile extends StatelessWidget {
  final Map item;
  final String symbol;
  final double rate;
  final VoidCallback onTap;

  const _ItemTile({
    required this.item,
    required this.symbol,
    required this.rate,
    required this.onTap,
  });

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unit = (item['unit'] ?? '').toString();
    final taxes = [
      for (final s in ['', '_2'])
        if (item['taxname$s'] != null)
          '${item['taxname$s']} ${double.tryParse('${item['taxrate$s']}') ?? 0}%',
    ];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: cs.primary.withValues(alpha: 0.12),
              child:
                  Icon(Icons.inventory_2_outlined, color: cs.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item['description']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15.5)),
                  if (unit.isNotEmpty || taxes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (unit.isNotEmpty)
                          _chip('per $unit', Colors.grey.shade700),
                        for (final t in taxes) _chip(t, cs.primary),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('$symbol${rate.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
