import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'add_customer_screen.dart';
import 'contacts_list_screen.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<dynamic> _customers = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    if (mounted) Provider.of<AuthProvider>(context, listen: false).fetchPermissions();
    setState(() => _isLoading = true);
    try {
      final summaryFuture = ApiService.getCustomersSummary();
      final customersFuture = ApiService.getCustomers(search: _searchQuery);
      
      final results = await Future.wait([summaryFuture, customersFuture]);
      final summaryData = results[0];
      final customersData = results[1];

      setState(() {
        if (summaryData['status'] == true) {
          _summary = summaryData['data'];
        }
        if (customersData['status'] == true) {
          _customers = customersData['data'];
        }
      });
    } catch (e) {
      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).logout();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_summary != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: SizedBox(
                // Grows with the phone's font size so the 2-line labels never overflow.
                height: 104 * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  children: [
                    _buildSummaryCard('Total Customers', _summary!['total_customers'], Icons.group, Colors.blue),
                    _buildSummaryCard('Active Customers', _summary!['active_customers'], Icons.check_circle, Colors.green),
                    _buildSummaryCard('Inactive Customers', _summary!['inactive_customers'], Icons.cancel, Colors.red),
                    _buildSummaryCard('Active Contacts', _summary!['active_contacts'], Icons.person, Colors.blueAccent),
                    _buildSummaryCard('Inactive Contacts', _summary!['inactive_contacts'], Icons.person_off, Colors.redAccent),
                    _buildSummaryCard('Contacts Logged In Today', _summary!['contacts_logged_in_today'], Icons.login, Colors.orange),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _fetchCustomers();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? const EmptyState(icon: Icons.people_outline, message: 'No customers found')
                    : RefreshIndicator(
                        onRefresh: _fetchCustomers,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 88),
                          itemCount: _customers.length,
                          itemBuilder: (context, index) {
                            final customer = _customers[index];
                            final canEdit = Provider.of<AuthProvider>(context, listen: false).canEditCustomer;
                            final phone = (customer['phonenumber'] ?? '').toString().trim();
                            final isActive = customer['active'] == '1';

                            return AnimatedEntry(
                              index: index,
                              child: Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddCustomerScreen(customerId: customer['userid'].toString(), readOnly: true),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                              child: Text(
                                                customer['company'][0].toUpperCase(),
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    customer['company'],
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(phone.isEmpty ? 'No Phone' : phone, style: TextStyle(color: Colors.grey.shade700)),
                                                  if (customer['datecreated'] != null)
                                                    Text(
                                                      'Created: ${customer['datecreated']}',
                                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                                                                onSelected: (value) async {
                                                                                  if (value == 'view') {
                                                                                    Navigator.push(
                                                                                      context,
                                                                                      MaterialPageRoute(
                                                                                        builder: (_) => AddCustomerScreen(customerId: customer['userid'].toString(), readOnly: true),
                                                                                      ),
                                                                                    );
                                                                                  } else if (value == 'edit') {
                                                                                    final result = await Navigator.push(
                                                                                      context,
                                                                                      MaterialPageRoute(
                                                                                        builder: (_) => AddCustomerScreen(customerId: customer['userid'].toString()),
                                                                                      ),
                                                                                    );
                                                                                    if (result == true) _fetchCustomers();
                                                                                  } else if (value == 'contacts') {
                                                                                    Navigator.push(
                                                                                      context,
                                                                                      MaterialPageRoute(
                                                                                        builder: (_) => ContactsListScreen(customerId: customer['userid'].toString()),
                                                                                      ),
                                                                                    );
                                                                                  } else if (value == 'delete') {
                                                                                    final confirm = await showDialog<bool>(
                                                                                      context: context,
                                                                                      builder: (ctx) => AlertDialog(
                                                                                        title: const Text('Delete Customer'),
                                                                                        content: const Text('Are you sure you want to delete this customer?'),
                                                                                        actions: [
                                                                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                                                          TextButton(
                                                                                            onPressed: () => Navigator.pop(ctx, true), 
                                                                                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                                                            child: const Text('Delete')
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                    );
                                                                                    if (confirm == true) {
                                                                                      final response = await ApiService.deleteCustomer(customer['userid'].toString());
                                                                                      if (response['status'] == true) {
                                                                                        if (mounted) {
                                                                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer deleted')));
                                                                                        }
                                                                                        _fetchCustomers();
                                                                                      } else {
                                                                                        if (mounted) {
                                                                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Delete failed')));
                                                                                        }
                                                                                      }
                                                                                    }
                                                                                  }
                                                                                },
                                                                                itemBuilder: (context) {
                                                                                  final auth = Provider.of<AuthProvider>(context, listen: false);
                                                                                  return [
                                                                                    const PopupMenuItem(value: 'view', child: Text('View')),
                                                                                    if (auth.canEditCustomer)
                                                                                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                                                                    const PopupMenuItem(value: 'contacts', child: Text('Contacts')),
                                                                                    if (auth.canDeleteCustomer)
                                                                                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                                                                  ];
                                                                                },
                                                                              ),
                                          ],
                                        ),
                                        if (phone.isNotEmpty || canEdit) ...[
                                          const Divider(height: 16),
                                          Row(
                                            children: [
                                              if (phone.isNotEmpty)
                                                TextButton.icon(
                                                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                                                  icon: const Icon(Icons.call, size: 18, color: Colors.green),
                                                  label: const Text('Call', style: TextStyle(color: Colors.green)),
                                                ),
                                              const Spacer(),
                                              if (canEdit) ...[
                                                Text(
                                                  isActive ? 'Active' : 'Inactive',
                                                  style: TextStyle(fontSize: 13, color: isActive ? Colors.green : Colors.grey),
                                                ),
                                                const SizedBox(width: 4),
                                                Switch(
                                                                                    value: customer['active'] == '1',
                                                                                    onChanged: (val) async {
                                                                                      final newStatus = val ? '1' : '0';
                                                                                      // Optimistic update
                                                                                      setState(() {
                                                                                        customer['active'] = newStatus;
                                                                                      });
                                                                                      final response = await ApiService.changeCustomerStatus(customer['userid'].toString(), newStatus);
                                                                                      if (response['status'] != true) {
                                                                                        // Revert on failure
                                                                                        setState(() {
                                                                                          customer['active'] = customer['active'] == '1' ? '0' : '1';
                                                                                        });
                                                                                        if (mounted) {
                                                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                                                            SnackBar(content: Text(response['message'] ?? 'Failed to change status')),
                                                                                          );
                                                                                        }
                                                                                      }
                                                                                    },
                                                                                    activeColor: Colors.green,
                                                                                  ),
                                                const SizedBox(width: 8),
                                              ],
                                            ],
                                          ),
                                        ],
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
      floatingActionButton: Provider.of<AuthProvider>(context).canCreateCustomer ? FloatingActionButton(
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
      ) : null,
    );
  }

  Widget _buildSummaryCard(String title, dynamic value, IconData icon, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
