import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the currency picked on Dashboard / Pending, so both screens (and
/// the next app start) open on the same one.
class CurrencyPref {
  static const _key = 'currency_id';

  static Future<String?> load() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String id) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, id);
    } catch (_) {}
  }
}

/// "Amounts in  [ € EUR ▾ ]" - opens a scrollable list, so it keeps working
/// however many currencies the business invoices in. Hidden when there is
/// only one, since there is nothing to switch.
class CurrencySelector extends StatelessWidget {
  final List currencies;
  final String selectedId;
  final ValueChanged<String> onSelected;

  const CurrencySelector({
    super.key,
    required this.currencies,
    required this.selectedId,
    required this.onSelected,
  });

  Map? get _selected {
    for (final c in currencies) {
      if (c['id'].toString() == selectedId) return c;
    }
    return currencies.isEmpty ? null : currencies.first;
  }

  Future<void> _pick(BuildContext context) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: currencies.length > 6 ? 0.6 : 0.4,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (_, scroll) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Show amounts in',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: currencies.length,
                itemBuilder: (_, i) {
                  final c = currencies[i];
                  final isSel = c['id'].toString() == selectedId;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(ctx)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      child: Text('${c['symbol']}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    title: Text('${c['name']}'),
                    trailing: isSel
                        ? Icon(Icons.check_circle,
                            color: Theme.of(ctx).colorScheme.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, c['id'].toString()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (id != null && id != selectedId) onSelected(id);
  }

  @override
  Widget build(BuildContext context) {
    if (currencies.length < 2) return const SizedBox.shrink();
    final sel = _selected;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text('Amounts in',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _pick(context),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${sel?['symbol'] ?? ''}  ${sel?['name'] ?? ''}',
                      style: TextStyle(
                          color: cs.primary, fontWeight: FontWeight.w700)),
                  Icon(Icons.arrow_drop_down, color: cs.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
