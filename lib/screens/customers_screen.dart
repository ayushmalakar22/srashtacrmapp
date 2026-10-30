import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'add_customer_screen.dart';
import 'contacts_list_screen.dart';
import 'invoices_screen.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import '../widgets/app_drawer.dart';
import '../utils/paged_list.dart';
import '../widgets/list_filters.dart';
import '../widgets/paged_footer.dart';
import '../widgets/sort_button.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final PagedList _list =
      PagedList((offset, limit) => ApiService.getCustomers(
            offset: offset,
            limit: limit,
            search: _search.text.trim(),
            status: _statusFilter,
            group: _groupFilter,
            sort: _sort,
          ));
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  String? _statusFilter; // '1' active, '0' inactive, null = all
  String? _groupFilter; // customer group id, null = all
  List _groups = [];
  Map<String, dynamic>? _summary;
  String _sort = 'name';

  static const _sortOptions = [
    SortOption('name', 'Name (A to Z)'),
    SortOption('name_desc', 'Name (Z to A)'),
    SortOption('newest', 'Newest first'),
  ];

  bool get _hasFilters =>
      _statusFilter != null || _groupFilter != null || _search.text.isNotEmpty;

  void _clearFilters() {
    _statusFilter = null;
    _groupFilter = null;
    _debounce?.cancel();
    _search.clear(); // its listener refreshes the list
    _applyFilters();
  }

  static const _statusOptions = [
    FilterOption(null, 'All'),
    FilterOption('1', 'Active'),
    FilterOption('0', 'Inactive'),
  ];

  /// Groups come with the add-customer form data; fetched once for the chips.
  Future<void> _loadGroups() async {
    try {
      final res = await ApiService.getCustomerFormData();
      if (res['status'] == true && mounted) {
        setState(() => _groups = res['data']['groups'] ?? []);
      }
    } catch (_) {} // chips just stay hidden
  }

  @override
  void initState() {
    super.initState();
    _list.addListener(() {
      if (mounted) setState(() {});
    });
    _list.refresh();
    _loadSummary();
    _loadGroups();
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

  /// Search / status changed: start again at page 1.
  void _applyFilters() => _list.refresh();

  Future<void> _loadSummary() async {
    try {
      final res = await ApiService.getCustomersSummary();
      if (mounted && res['status'] == true) {
        setState(() => _summary = res['data']);
      }
    } catch (_) {}
  }

  /// Reload quietly (counts + list), keeping rows and scroll position.
  Future<void> _fetchCustomers() async {
    if (mounted) {
      Provider.of<AuthProvider>(context, listen: false).fetchPermissions();
    }
    _loadSummary();
    await _list.refresh(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_summary != null)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  _buildSummaryCard('Total', _summary!['total_customers'],
                      Icons.group, Colors.blue),
                  _buildSummaryCard('Active', _summary!['active_customers'],
                      Icons.check_circle, Colors.green),
                  _buildSummaryCard('Inactive', _summary!['inactive_customers'],
                      Icons.cancel, Colors.red),
                  _buildSummaryCard(
                      'Active contacts',
                      _summary!['active_contacts'],
                      Icons.person,
                      Colors.indigo),
                  _buildSummaryCard(
                      'Inactive contacts',
                      _summary!['inactive_contacts'],
                      Icons.person_off,
                      Colors.redAccent),
                  _buildSummaryCard(
                      'Logged in today',
                      _summary!['contacts_logged_in_today'],
                      Icons.login,
                      Colors.orange),
                ],
              ),
            ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search name, phone or GST...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _search.clear),
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
            groups: [
              for (final g in _groups)
                FilterOption(g['id'].toString(), g['name'].toString()),
            ],
            group: _groupFilter,
            onGroup: (v) {
              _groupFilter = v;
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
                            icon: Icons.people_outline,
                            message: _hasFilters
                                ? 'No customers match these filters'
                                : 'No customers yet',
                            actionLabel: _hasFilters ? 'Clear filters' : null,
                            onAction: _hasFilters ? _clearFilters : null)
                        : RefreshIndicator(
                            onRefresh: _fetchCustomers,
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
                                final customer = _list.items[index];
                                final canEdit = Provider.of<AuthProvider>(
                                        context,
                                        listen: false)
                                    .canEditCustomer;
                                final phone = (customer['phonenumber'] ?? '')
                                    .toString()
                                    .trim();
                                final isActive = customer['active'] == '1';

                                return AnimatedEntry(
                                  index: index,
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddCustomerScreen(
                                              customerId:
                                                  customer['userid'].toString(),
                                              readOnly: true),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            12, 10, 2, 10),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 22,
                                                  backgroundColor:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                              alpha: 0.12),
                                                  child: Text(
                                                    customer['company'][0]
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        customer['company'],
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Row(children: [
                                                        Icon(
                                                            phone.isEmpty
                                                                ? Icons
                                                                    .phone_disabled_outlined
                                                                : Icons
                                                                    .phone_outlined,
                                                            size: 14,
                                                            color: Colors
                                                                .grey.shade600),
                                                        const SizedBox(
                                                            width: 4),
                                                        Flexible(
                                                          child: Text(
                                                              phone.isEmpty
                                                                  ? 'No phone'
                                                                  : phone,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      13.5,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade700)),
                                                        ),
                                                      ]),
                                                      const SizedBox(height: 5),
                                                      Row(children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 2),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: (isActive
                                                                    ? Colors
                                                                        .green
                                                                    : Colors
                                                                        .grey)
                                                                .withValues(
                                                                    alpha:
                                                                        0.12),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                          ),
                                                          child: Text(
                                                              isActive
                                                                  ? 'Active'
                                                                  : 'Inactive',
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      11.5,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: isActive
                                                                      ? Colors
                                                                          .green
                                                                          .shade700
                                                                      : Colors
                                                                          .grey
                                                                          .shade700)),
                                                        ),
                                                        if (customer[
                                                                'datecreated'] !=
                                                            null) ...[
                                                          const SizedBox(
                                                              width: 8),
                                                          Flexible(
                                                            child: Text(
                                                                _day(customer[
                                                                    'datecreated']),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        11.5,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade500)),
                                                          ),
                                                        ],
                                                      ]),
                                                    ],
                                                  ),
                                                ),
                                                if (phone.isNotEmpty)
                                                  IconButton(
                                                    tooltip: 'Call',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    onPressed: () => launchUrl(
                                                        Uri(
                                                            scheme: 'tel',
                                                            path: phone)),
                                                    icon: const Icon(Icons.call,
                                                        size: 20,
                                                        color: Colors.green),
                                                    style: IconButton.styleFrom(
                                                        backgroundColor: Colors
                                                            .green
                                                            .withValues(
                                                                alpha: 0.12)),
                                                  ),
                                                if (canEdit)
                                                  Transform.scale(
                                                    scale: 0.8,
                                                    child: Switch(
                                                      value: isActive,
                                                      activeColor: Colors.green,
                                                      onChanged: (val) =>
                                                          _toggleActive(
                                                              customer, val),
                                                    ),
                                                  ),
                                                PopupMenuButton<String>(
                                                  onSelected: (value) async {
                                                    if (value == 'view') {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              AddCustomerScreen(
                                                                  customerId: customer[
                                                                          'userid']
                                                                      .toString(),
                                                                  readOnly:
                                                                      true),
                                                        ),
                                                      );
                                                    } else if (value ==
                                                        'edit') {
                                                      final result =
                                                          await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              AddCustomerScreen(
                                                                  customerId: customer[
                                                                          'userid']
                                                                      .toString()),
                                                        ),
                                                      );
                                                      if (result == true)
                                                        _fetchCustomers();
                                                    } else if (value ==
                                                        'invoices') {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => InvoicesScreen(
                                                              clientId: customer[
                                                                      'userid']
                                                                  .toString(),
                                                              clientName:
                                                                  '${customer['company']}'),
                                                        ),
                                                      );
                                                    } else if (value ==
                                                        'contacts') {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              ContactsListScreen(
                                                                  customerId: customer[
                                                                          'userid']
                                                                      .toString()),
                                                        ),
                                                      );
                                                    } else if (value ==
                                                        'delete') {
                                                      final confirm =
                                                          await showDialog<
                                                              bool>(
                                                        context: context,
                                                        builder: (ctx) =>
                                                            AlertDialog(
                                                          title: const Text(
                                                              'Delete Customer'),
                                                          content: const Text(
                                                              'Are you sure you want to delete this customer?'),
                                                          actions: [
                                                            TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        ctx,
                                                                        false),
                                                                child: const Text(
                                                                    'Cancel')),
                                                            TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        ctx,
                                                                        true),
                                                                style: TextButton
                                                                    .styleFrom(
                                                                        foregroundColor:
                                                                            Colors
                                                                                .red),
                                                                child: const Text(
                                                                    'Delete')),
                                                          ],
                                                        ),
                                                      );
                                                      if (confirm == true) {
                                                        final response =
                                                            await ApiService
                                                                .deleteCustomer(
                                                                    customer[
                                                                            'userid']
                                                                        .toString());
                                                        if (response[
                                                                'status'] ==
                                                            true) {
                                                          if (mounted) {
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                                    const SnackBar(
                                                                        content:
                                                                            Text('Customer deleted')));
                                                          }
                                                          _fetchCustomers();
                                                        } else {
                                                          if (mounted) {
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(SnackBar(
                                                                    content: Text(
                                                                        response['message'] ??
                                                                            'Delete failed')));
                                                          }
                                                        }
                                                      }
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
                                                          child: Text('View')),
                                                      if (auth.canEditCustomer)
                                                        const PopupMenuItem(
                                                            value: 'edit',
                                                            child:
                                                                Text('Edit')),
                                                      const PopupMenuItem(
                                                          value: 'invoices',
                                                          child:
                                                              Text('Invoices')),
                                                      const PopupMenuItem(
                                                          value: 'contacts',
                                                          child:
                                                              Text('Contacts')),
                                                      if (auth
                                                          .canDeleteCustomer)
                                                        const PopupMenuItem(
                                                            value: 'delete',
                                                            child: Text(
                                                                'Delete',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .red))),
                                                    ];
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
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
      floatingActionButton: Provider.of<AuthProvider>(context).canCreateCustomer
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
                );
                if (result == true) {
                  _fetchCustomers(); // Refresh list if customer was added
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  String _day(dynamic raw) => raw.toString().split(' ').first;

  Future<void> _toggleActive(Map customer, bool val) async {
    final newStatus = val ? '1' : '0';
    final old = customer['active'];
    setState(() => customer['active'] = newStatus); // optimistic
    final response = await ApiService.changeCustomerStatus(
        customer['userid'].toString(), newStatus);
    if (response['status'] != true) {
      if (!mounted) return;
      setState(() => customer['active'] = old);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(response['message'] ?? 'Failed to change status')));
    }
  }

  Widget _buildSummaryCard(
      String title, dynamic value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(value.toString(),
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 5),
          Text(title,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
