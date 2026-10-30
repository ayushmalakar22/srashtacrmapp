import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import '../utils/paged_list.dart';
import '../widgets/item_sheet.dart';
import '../widgets/paged_footer.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  late final PagedList _list = PagedList(_fetchPage);
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  List _taxes = [];
  String _symbol = '\$';

  /// The API wraps the rows with the tax list and currency; keep those and
  /// hand just the rows to the paged list.
  Future<Map<String, dynamic>> _fetchPage(int offset, int limit) async {
    final res = await ApiService.getItems(
        offset: offset, limit: limit, search: _searchController.text.trim());
    if (res['status'] != true) return res;
    final data = res['data'];
    _taxes = data['taxes'] ?? [];
    _symbol = (data['currency_symbol'] ?? '\$').toString();
    return {'status': true, 'data': data['items'], 'total': res['total']};
  }

  @override
  void initState() {
    super.initState();
    _list.addListener(() {
      if (mounted) setState(() {});
    });
    _list.refresh();
    _searchController.addListener(() {
      setState(() {}); // show/hide the clear button right away
      _debounce?.cancel();
      _debounce =
          Timer(const Duration(milliseconds: 350), () => _list.refresh());
    });
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) _list.loadMore();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scroll.dispose();
    _list.dispose();
    super.dispose();
  }

  /// Reload quietly, keeping the rows and scroll position.
  Future<void> _fetch() => _list.refresh(silent: true);

  Future<void> _openSheet([Map<String, dynamic>? item]) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final saved = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ItemSheet(
          item: item,
          taxes: _taxes,
          symbol: _symbol,
          canDelete: auth.canDeleteItem),
    );
    if (saved != null) _fetch();
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
          onTap: canEdit
              ? () => _openSheet(Map<String, dynamic>.from(item))
              : null,
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
            child: _list.loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: _list.items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: 300,
                                child: _list.error != null
                                    ? EmptyState(
                                        icon: Icons.cloud_off_outlined,
                                        message: _list.error!,
                                        actionLabel: 'Retry',
                                        onAction: () => _list.refresh())
                                    : EmptyState(
                                        icon: Icons.inventory_2_outlined,
                                        message: _searchController.text.isEmpty
                                            ? 'No items yet'
                                            : 'No items found'),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scroll,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(top: 4, bottom: 88),
                            itemCount: _list.items.length + 1,
                            itemBuilder: (_, i) => i == _list.items.length
                                ? PagedFooter(list: _list)
                                : _card(_list.items[i], i, auth.canEditItem),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
