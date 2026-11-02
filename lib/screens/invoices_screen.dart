import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/invoice_status.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'add_invoice_screen.dart';
import 'invoice_view_screen.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import '../widgets/app_drawer.dart';
import '../utils/paged_list.dart';
import '../widgets/list_filters.dart';
import '../widgets/paged_footer.dart';
import '../widgets/record_payment_sheet.dart';
import '../widgets/sort_button.dart';

class InvoicesScreen extends StatefulWidget {
  /// Set to show only one customer's invoices (opened from the Customers list).
  final String? clientId;
  final String? clientName;
  const InvoicesScreen({super.key, this.clientId, this.clientName});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late final PagedList _list =
      PagedList((offset, limit) => ApiService.getInvoices(
            offset: offset,
            limit: limit,
            search: _searchController.text.trim(),
            status: _statusFilter,
            from: _dateFilter.fromYmd,
            to: _dateFilter.toYmd,
            client: widget.clientId,
            sort: _sort,
          ));
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;
  String? _statusFilter; // effective status code, null = all
  DateFilter _dateFilter = DateFilter.all;
  String _sort = 'newest';

  static const _sortOptions = [
    SortOption('newest', 'Newest first'),
    SortOption('oldest', 'Oldest first'),
    SortOption('amount', 'Highest amount'),
    SortOption('due', 'Due date (earliest)'),
  ];

  bool get _hasFilters =>
      _statusFilter != null ||
      _dateFilter.isActive ||
      _searchController.text.isNotEmpty;

  void _clearFilters() {
    _statusFilter = null;
    _dateFilter = DateFilter.all;
    _debounce?.cancel();
    _searchController.clear(); // its listener refreshes the list
    _applyFilters();
  }

  @override
  void initState() {
    super.initState();
    _list.addListener(() {
      if (mounted) setState(() {});
    });
    _list.refresh();
    _searchController.addListener(_onSearchTyped);
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

  static const _statusOptions = [
    FilterOption(null, 'All'),
    FilterOption('1', 'Unpaid'),
    FilterOption('3', 'Partial'),
    FilterOption('4', 'Overdue'),
    FilterOption('2', 'Paid'),
    FilterOption('6', 'Draft'),
  ];

  /// Waits for a pause in typing, then asks the server again.
  void _onSearchTyped() {
    setState(() {}); // show/hide the clear button right away
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _applyFilters);
  }

  /// Search text + status chip + date window changed: start again at page 1.
  void _applyFilters() => _list.refresh();

  /// Reload quietly, keeping the rows (and scroll position) on screen.
  Future<void> _fetchInvoices() async {
    if (mounted) {
      Provider.of<AuthProvider>(context, listen: false).fetchPermissions();
    }
    await _list.refresh(silent: true);
  }

  Widget _swipeBg(Color color, IconData icon, String label, Alignment at) {
    return Container(
      alignment: at,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (at == Alignment.centerLeft) Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          if (at == Alignment.centerRight) Icon(icon, color: Colors.white),
        ],
      ),
    );
  }

  /// Swipe action: open the payment sheet (pre-filled with the balance, so
  /// saving as-is marks the invoice paid).
  Future<void> _receivePayment(String id, String symbol) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ApiService.getInvoicePayments(id);
      if (res['status'] != true) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Could not load payment details')));
        return;
      }
      final data = res['data'];
      final balance =
          double.tryParse(data['balance_due']?.toString() ?? '0') ?? 0;
      if (data['can_create'] != true || balance <= 0) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Nothing to receive on this invoice')));
        return;
      }
      if (!mounted) return;
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => RecordPaymentSheet(
          invoiceId: id,
          symbol: symbol,
          balanceDue: data['balance_due'].toString(),
          modes: data['payment_modes'] as List,
        ),
      );
      if (saved == true) {
        messenger
            .showSnackBar(const SnackBar(content: Text('Payment recorded')));
        _fetchInvoices();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteInvoice(String id) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await ApiService.deleteInvoice(id);
        if (response['status'] == true) {
          _fetchInvoices();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invoice deleted successfully')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(response['message']?.toString() ??
                      'Failed to delete invoice')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error deleting invoice')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // opened from a customer: plain back arrow instead of the side menu
      drawer: widget.clientId == null ? const AppDrawer() : null,
      appBar: AppBar(
        title: Text(widget.clientName ?? 'Invoices'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search invoice #, customer or total...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _searchController.clear),
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
                    : _list.items.isEmpty
                        ? EmptyState(
                            icon: Icons.receipt_long_outlined,
                            message: _hasFilters
                                ? 'No invoices match these filters'
                                : 'No invoices yet',
                            actionLabel: _hasFilters ? 'Clear filters' : null,
                            onAction: _hasFilters ? _clearFilters : null)
                        : RefreshIndicator(
                            onRefresh: _fetchInvoices,
                            child: ListView.builder(
                              controller: _scroll,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.only(top: 4, bottom: 88),
                              itemCount: _list.items.length + 1,
                              itemBuilder: (context, index) {
                                if (index == _list.items.length) {
                                  return PagedFooter(list: _list);
                                }
                                final invoice = _list.items[index];
                                final st = InvoiceStatus.of(
                                    effectiveInvoiceStatus(
                                        invoice['status'], invoice['duedate']));
                                final statusColor = st.color;
                                final statusText = st.label;

                                void openView() {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InvoiceViewScreen(
                                          invoiceId: invoice['id'].toString()),
                                    ),
                                  ).then((_) => _fetchInvoices());
                                }

                                final auth = Provider.of<AuthProvider>(context,
                                    listen: false);
                                final canReceive = auth.canCreatePayment &&
                                    const ['1', '3', '4']
                                        .contains(invoice['status'].toString());
                                final canDelete = auth.canDeleteInvoice &&
                                    invoice['can_delete'] != false;

                                return AnimatedEntry(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    // Swipe right = receive payment, left =
                                    // delete. The row never leaves the list
                                    // here: the list reloads after the action.
                                    child: Dismissible(
                                      key: ValueKey('inv-${invoice['id']}'),
                                      direction: canReceive && canDelete
                                          ? DismissDirection.horizontal
                                          : canReceive
                                              ? DismissDirection.startToEnd
                                              : canDelete
                                                  ? DismissDirection.endToStart
                                                  : DismissDirection.none,
                                      background: _swipeBg(
                                          Colors.green,
                                          Icons.payments_outlined,
                                          'Receive payment',
                                          Alignment.centerLeft),
                                      secondaryBackground: _swipeBg(
                                          Colors.red,
                                          Icons.delete_outline,
                                          'Delete',
                                          Alignment.centerRight),
                                      confirmDismiss: (dir) async {
                                        if (dir ==
                                            DismissDirection.startToEnd) {
                                          _receivePayment(
                                              invoice['id'].toString(),
                                              (invoice['symbol'] ?? '\$')
                                                  .toString());
                                        } else {
                                          _deleteInvoice(
                                              invoice['id'].toString());
                                        }
                                        return false;
                                      },
                                      child: Card(
                                        margin: EdgeInsets.zero,
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          onTap: openView,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                12, 12, 4, 12),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 22,
                                                  backgroundColor: statusColor
                                                      .withValues(alpha: 0.12),
                                                  child: Icon(
                                                      Icons.receipt_long,
                                                      color: statusColor),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        '${invoice['prefix']}${invoice['number']}',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 10,
                                                                vertical: 3),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: statusColor
                                                              .withValues(
                                                                  alpha: 0.12),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                        child: Text(
                                                          statusText,
                                                          style: TextStyle(
                                                              color:
                                                                  statusColor,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                        '${invoice['symbol'] ?? '\$'}${invoice['total']}',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16)),
                                                    Text('Total',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey.shade600,
                                                            fontSize: 12)),
                                                  ],
                                                ),
                                                PopupMenuButton<String>(
                                                  onSelected: (value) {
                                                    if (value == 'view') {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              InvoiceViewScreen(
                                                                  invoiceId: invoice[
                                                                          'id']
                                                                      .toString()),
                                                        ),
                                                      ).then((_) =>
                                                          _fetchInvoices());
                                                    } else if (value ==
                                                        'edit') {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              AddInvoiceScreen(
                                                                  invoiceId: invoice[
                                                                          'id']
                                                                      .toString()),
                                                        ),
                                                      ).then((_) =>
                                                          _fetchInvoices());
                                                    } else if (value ==
                                                        'delete') {
                                                      _deleteInvoice(
                                                          invoice['id']
                                                              .toString());
                                                    }
                                                  },
                                                  itemBuilder: (context) {
                                                    final auth = Provider.of<
                                                            AuthProvider>(
                                                        context,
                                                        listen: false);
                                                    return [
                                                      const PopupMenuItem(
                                                        value: 'view',
                                                        child: Text('View'),
                                                      ),
                                                      if (auth.canEditInvoice)
                                                        const PopupMenuItem(
                                                          value: 'edit',
                                                          child: Text('Edit'),
                                                        ),
                                                      if (auth.canDeleteInvoice &&
                                                          invoice['can_delete'] !=
                                                              false)
                                                        const PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text('Delete',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red)),
                                                        ),
                                                    ];
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: Provider.of<AuthProvider>(context).canCreateInvoice
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddInvoiceScreen()),
                ).then((_) => _fetchInvoices());
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
