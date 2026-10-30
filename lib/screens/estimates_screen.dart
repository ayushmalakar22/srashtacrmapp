import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/estimate_status.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import '../utils/paged_list.dart';
import '../widgets/list_filters.dart';
import '../widgets/paged_footer.dart';
import '../widgets/sort_button.dart';
import 'add_invoice_screen.dart';
import 'estimate_view_screen.dart';

class EstimatesScreen extends StatefulWidget {
  const EstimatesScreen({super.key});

  @override
  State<EstimatesScreen> createState() => _EstimatesScreenState();
}

class _EstimatesScreenState extends State<EstimatesScreen> {
  late final PagedList _list =
      PagedList((offset, limit) => ApiService.getEstimates(
            offset: offset,
            limit: limit,
            search: _search.text.trim(),
            status: _statusFilter,
            from: _dateFilter.fromYmd,
            to: _dateFilter.toYmd,
            sort: _sort,
          ));
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  String? _statusFilter;
  DateFilter _dateFilter = DateFilter.all;
  String _sort = 'newest';

  static const _sortOptions = [
    SortOption('newest', 'Newest first'),
    SortOption('oldest', 'Oldest first'),
    SortOption('amount', 'Highest amount'),
    SortOption('expiry', 'Expiry date (earliest)'),
  ];

  bool get _hasFilters =>
      _statusFilter != null || _dateFilter.isActive || _search.text.isNotEmpty;

  void _clearFilters() {
    _statusFilter = null;
    _dateFilter = DateFilter.all;
    _debounce?.cancel();
    _search.clear(); // its listener refreshes the list
    _applyFilters();
  }

  static const _statusOptions = [
    FilterOption(null, 'All'),
    FilterOption('1', 'Draft'),
    FilterOption('2', 'Sent'),
    FilterOption('4', 'Accepted'),
    FilterOption('3', 'Declined'),
    FilterOption('5', 'Expired'),
  ];

  @override
  void initState() {
    super.initState();
    _list.addListener(() {
      if (mounted) setState(() {});
    });
    _list.refresh();
    _search.addListener(() {
      setState(() {}); // show/hide the clear button right away
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), _applyFilters);
    });
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) _list.loadMore();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    _list.dispose();
    super.dispose();
  }

  /// Search / status / date changed: start again at page 1.
  void _applyFilters() => _list.refresh();

  /// Reload quietly, keeping the rows (and scroll position) on screen.
  Future<void> _fetch() => _list.refresh(silent: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estimates'),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New Estimate',
        onPressed: () async {
          final id = await Navigator.push<String>(
            context,
            MaterialPageRoute(
                builder: (_) => const AddInvoiceScreen(isEstimate: true)),
          );
          if (id == null || !context.mounted) return;
          await _fetch();
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => EstimateViewScreen(estimateId: id)),
          ).then((_) => _fetch());
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search by estimate #, customer or total...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          ListFilters(
            statuses: _statusOptions,
            sortOptions: _sortOptions,
            sort: _sort,
            onSort: (v) {
              _sort = v;
              _applyFilters();
            },
            status: _statusFilter,
            onStatus: (v) {
              _statusFilter = v;
              _applyFilters();
            },
            dateFilter: _dateFilter,
            onDate: (d) {
              _dateFilter = d;
              _applyFilters();
            },
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _list.loading
                ? const Center(child: CircularProgressIndicator())
                : _list.error != null
                    ? EmptyState(
                        icon: Icons.cloud_off_outlined,
                        message: _list.error!,
                        actionLabel: 'Retry',
                        onAction: _applyFilters)
                    : RefreshIndicator(
                        onRefresh: _fetch,
                        child: _list.items.isEmpty
                            ? ListView(children: [
                                const SizedBox(height: 120),
                                EmptyState(
                                    icon: Icons.request_quote_outlined,
                                    message: _hasFilters
                                        ? 'No estimates match these filters'
                                        : 'No estimates yet',
                                    actionLabel:
                                        _hasFilters ? 'Clear filters' : null,
                                    onAction:
                                        _hasFilters ? _clearFilters : null),
                              ])
                            : ListView.builder(
                                controller: _scroll,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.only(top: 4, bottom: 88),
                                itemCount: _list.items.length + 1,
                                itemBuilder: (context, i) =>
                                    i == _list.items.length
                                        ? PagedFooter(list: _list)
                                        : _card(i, _list.items[i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _card(int index, Map e) {
    final st = EstimateStatus.of(e['status']);
    final invoiced = e['invoiceid'] != null;
    return AnimatedEntry(
      index: index,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    EstimateViewScreen(estimateId: e['id'].toString())),
          ).then((_) => _fetch()),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: st.color.withValues(alpha: 0.12),
                  child: Icon(Icons.request_quote, color: st.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(estimateNumber(e['prefix'], e['number']),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text((e['company'] ?? '').toString(),
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        _chip(st.label, st.color),
                        if (invoiced) _chip('Invoiced', Colors.teal),
                      ]),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${e['symbol'] ?? '\$'}${e['total']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Exp ${e['expirydate'] ?? '-'}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
