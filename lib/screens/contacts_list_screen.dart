import 'package:flutter/material.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'add_contact_screen.dart';

class ContactsListScreen extends StatefulWidget {
  final String customerId;
  const ContactsListScreen({super.key, required this.customerId});

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  List<dynamic> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getContacts(widget.customerId);
      if (!mounted) return;
      if (response['status'] == true) {
        setState(() {
          _contacts = response['data'] ?? [];
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(response['message'] ?? 'Failed to load contacts')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Cannot reach the server. Check Wi-Fi and the server address.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteContact(String contactId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact'),
        content: const Text('Are you sure you want to delete this contact?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final response = await ApiService.deleteContact(contactId);
    if (response['status'] == true) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact deleted successfully')));
      _fetchContacts();
    } else {
      setState(() => _isLoading = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Failed to delete')));
    }
  }

  Future<void> _toggleStatus(String contactId, bool isActive) async {
    final status = isActive ? '1' : '0';
    final response = await ApiService.changeContactStatus(contactId, status);
    if (response['status'] == true) {
      _fetchContacts();
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(response['message'] ?? 'Failed to update status')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Contacts'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? const EmptyState(
                  icon: Icons.person_outline,
                  message: 'No contacts found for this customer')
              : RefreshIndicator(
                  onRefresh: _fetchContacts,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 6, bottom: 88),
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      final isActive = contact['active'] == '1';

                      return AnimatedEntry(
                        index: index,
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12.0, horizontal: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: contact['profile_image'] !=
                                          null
                                      ? NetworkImage(contact['profile_image'])
                                      : null,
                                  child: contact['profile_image'] == null
                                      ? Text((contact['firstname'] ?? '')
                                              .isNotEmpty
                                          ? contact['firstname'][0]
                                              .toUpperCase()
                                          : 'C')
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${contact['firstname'] ?? ''} ${contact['lastname'] ?? ''}'
                                                  .trim(),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16),
                                            ),
                                          ),
                                          if (contact['is_primary'] == '1')
                                            const Chip(
                                                label: Text('Primary',
                                                    style: TextStyle(
                                                        fontSize: 10)),
                                                padding: EdgeInsets.zero,
                                                visualDensity:
                                                    VisualDensity.compact),
                                        ],
                                      ),
                                      if ((contact['title'] ?? '').isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(contact['title'],
                                              style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 13)),
                                        ),
                                      const SizedBox(height: 8),
                                      if ((contact['email'] ?? '').isNotEmpty)
                                        Row(
                                          children: [
                                            const Icon(Icons.email,
                                                size: 14, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Text(contact['email'],
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.blue)),
                                          ],
                                        ),
                                      const SizedBox(height: 4),
                                      if ((contact['phonenumber'] ?? '')
                                          .isNotEmpty)
                                        Row(
                                          children: [
                                            const Icon(Icons.phone,
                                                size: 14, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Text(contact['phonenumber'],
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.blue)),
                                          ],
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time,
                                              size: 14, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                              'Last login: ${(contact['last_login'] ?? '').isNotEmpty ? contact['last_login'] : 'Never'}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    PopupMenuButton<String>(
                                      onSelected: (val) async {
                                        if (val == 'edit') {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AddContactScreen(
                                                  customerId: widget.customerId,
                                                  contact: contact),
                                            ),
                                          );
                                          if (result == true) _fetchContacts();
                                        } else if (val == 'delete') {
                                          _deleteContact(
                                              contact['id'].toString());
                                        }
                                      },
                                      itemBuilder: (BuildContext context) {
                                        final auth = Provider.of<AuthProvider>(
                                            context,
                                            listen: false);
                                        return [
                                          const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit')),
                                          if (auth
                                              .canDeleteCustomer) // Contacts deletion is considered part of deleting the customer in UI
                                            const PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete',
                                                    style: TextStyle(
                                                        color: Colors.red))),
                                        ];
                                      },
                                    ),
                                    Switch(
                                      value: isActive,
                                      onChanged: (val) => _toggleStatus(
                                          contact['id'].toString(), val),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddContactScreen(customerId: widget.customerId),
            ),
          );
          if (result == true) {
            _fetchContacts();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
