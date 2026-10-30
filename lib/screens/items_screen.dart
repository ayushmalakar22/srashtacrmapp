import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_sheet.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _searchController = TextEditingController();
  List _items = [];
  List _taxes = [];
  String _symbol = '\$';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiService.getItems();
      if (!mounted) return;
      setState(() {
        if (res['status'] == true) {
          _items = res['data']['items'] ?? [];
          _taxes = res['data']['taxes'] ?? [];
          _symbol = (res['data']['currency_symbol'] ?? '\$').toString();
          _error = null;
        } else {
          _error = res['message']?.toString() ?? 'Failed to load items';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Cannot reach the server. Check Wi-Fi and pull down to retry.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((i) {
      return '${i['description']} ${i['unit'] ?? ''}'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openSheet([Map<String, dynamic>? item]) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          ItemSheet(
          item: item,
          taxes: _taxes,
          symbol: _symbol,
          canDelete: auth.canDeleteItem),
    );
    if (saved == true) _fetch();
  }

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

  Widget _card(Map item, int index, bool canEdit) {
    final cs = Theme.of(context).colorScheme;
    final rate = double.tryParse('${item['rate']}') ?? 0;
    final unit = (item['unit'] ?? '').toString();
    final taxes = [
      for (final s in ['', '_2'])
        if (item['taxname$s'] != null)
          '${item['taxname$s']} ${double.tryParse('${item['taxrate$s']}') ?? 0}%',
    ];

    return AnimatedEntry(
      index: index,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canEdit ? () => _openSheet(Map<String, dynamic>.from(item)) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.inventory_2_outlined, color: cs.primary),
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
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (unit.isNotEmpty || taxes.isNotEmpty) ...[
                        const SizedBox(height: 6),
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
                Text('$_symbol${rate.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final list = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      floatingActionButton: auth.canCreateItem
          ? FloatingActionButton.extended(
              onPressed: () => _openSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _searchController.clear),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: list.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: 300,
                                child: _error != null
                                    ? EmptyState(
                                        icon: Icons.cloud_off_outlined,
                                        message: _error!)
                                    : EmptyState(
                                        icon: Icons.inventory_2_outlined,
                                        message: _items.isEmpty
                                            ? 'No items yet'
                                            : 'No items found'),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.only(top: 4, bottom: 88),
                            itemCount: list.length,
                            itemBuilder: (_, i) =>
                                _card(list[i], i, auth.canEditItem),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
