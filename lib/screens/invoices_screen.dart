import 'package:flutter/material.dart';
import '../utils/invoice_status.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'add_invoice_screen.dart';
import 'invoice_view_screen.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<dynamic> _invoices = [];
  List<dynamic> _filteredInvoices = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredInvoices = _invoices;
      });
    } else {
      setState(() {
        _filteredInvoices = _invoices.where((invoice) {
          final invNumber = '${invoice['prefix'] ?? ''}${invoice['number'] ?? ''}'.toLowerCase();
          final total = invoice['total']?.toString().toLowerCase() ?? '';
          return invNumber.contains(query) || total.contains(query);
        }).toList();
      });
    }
  }


  Future<void> _fetchInvoices() async {
    if (mounted) Provider.of<AuthProvider>(context, listen: false).fetchPermissions();
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getInvoices();
      if (data['status'] == true) {
        setState(() {
          _invoices = data['data'];
          _onSearchChanged(); // update filtered list
        });
      }
    } catch (e) {
      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).logout();
      }
    } finally {
      setState(() => _isLoading = false);
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
      setState(() => _isLoading = true);
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
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response['message']?.toString() ?? 'Failed to delete invoice')),
            );
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
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
      appBar: AppBar(
        title: const Text('Invoices'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Invoice # or Total...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.close), onPressed: _searchController.clear),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? const EmptyState(icon: Icons.receipt_long_outlined, message: 'No invoices found')
                    : RefreshIndicator(
                        onRefresh: _fetchInvoices,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 88),
                          itemCount: _filteredInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _filteredInvoices[index];
                      final st = InvoiceStatus.of(invoice['status']);
                      final statusColor = st.color;
                      final statusText = st.label;

                      void openView() {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InvoiceViewScreen(invoiceId: invoice['id'].toString()),
                          ),
                        ).then((_) => _fetchInvoices());
                      }

                      return AnimatedEntry(
                        index: index,
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: openView,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: statusColor.withValues(alpha: 0.12),
                                    child: Icon(Icons.receipt_long, color: statusColor),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${invoice['prefix']}${invoice['number']}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            statusText,
                                            style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('\$${invoice['total']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text('Total', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    ],
                                  ),
                                  PopupMenuButton<String>(
                                                                onSelected: (value) {
                                                                  if (value == 'view') {
                                                                    Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder: (_) => InvoiceViewScreen(invoiceId: invoice['id'].toString()),
                                                                      ),
                                                                    ).then((_) => _fetchInvoices());
                                                                  } else if (value == 'edit') {
                                                                    Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder: (_) => AddInvoiceScreen(invoiceId: invoice['id'].toString()),
                                                                      ),
                                                                    ).then((_) => _fetchInvoices());
                                                                  } else if (value == 'delete') {
                                                                    _deleteInvoice(invoice['id'].toString());
                                                                  }
                                                                },
                                                                itemBuilder: (context) {
                                                                  final auth = Provider.of<AuthProvider>(context, listen: false);
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
                                                                    if (auth.canDeleteInvoice && invoice['can_delete'] != false)
                                                                      const PopupMenuItem(
                                                                        value: 'delete',
                                                                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                                                                      ),
                                                                  ];
                                                                },
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
      floatingActionButton: Provider.of<AuthProvider>(context).canCreateInvoice ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddInvoiceScreen()),
          ).then((_) => _fetchInvoices());
        },
        child: const Icon(Icons.add),
      ) : null,
    );
  }
}
