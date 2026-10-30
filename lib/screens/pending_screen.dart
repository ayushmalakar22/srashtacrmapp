import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/phone.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import 'invoice_view_screen.dart';

/// Who owes money: pending balance per customer, biggest first, with one-tap
/// WhatsApp / call reminders.
class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiService.getPending();
      if (!mounted) return;
      if (res['status'] == true) {
        setState(() => _data = res['data']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(res['message']?.toString() ?? 'Failed to load')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error loading pending list')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _reminderText(Map c) {
    final org = (_data?['organization'] ?? '').toString();
    final invoices = (c['invoices'] as List).map((i) => i['number']).join(', ');
    final overdue = double.tryParse(c['overdue'].toString()) ?? 0;
    final n = c['invoice_count'];
    return 'Hello ${c['company']},\n'
        'This is a reminder that a payment of \$${c['balance']} is pending '
        '(${n == 1 ? 'invoice' : '$n invoices'}: $invoices)'
        '${overdue > 0 ? ', of which \$${c['overdue']} is overdue' : ''}.\n'
        '${org.isNotEmpty ? 'Thank you, $org' : 'Thank you'}';
  }

  Future<void> _whatsApp(Map c) async {
    final phone = waNumber((c['phone'] ?? '').toString(),
        (_data?['country_code'] ?? '').toString());
    final uri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(_reminderText(c))}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  Future<void> _call(Map c) async {
    if (!await launchUrl(Uri(scheme: 'tel', path: c['phone'].toString())) &&
        mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open dialer')));
    }
  }

  Widget _summary() {
    Widget tile(String label, String value, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12.5)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: color, fontSize: 24, fontWeight: FontWeight.w800)),
            ],
          ),
        );
    return AnimatedEntry(
      index: 0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4285F4), Color(0xFF2B63C9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              tile('To collect', '\$${_data!['total_pending']}', Colors.white),
              tile('Overdue', '\$${_data!['total_overdue']}',
                  const Color(0xFFFFCDD2)),
            ]),
            const SizedBox(height: 8),
            Text(
              '${_data!['invoice_count']} invoices · ${_data!['customer_count']} customers',
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customerCard(int index, Map c) {
    final overdue = (double.tryParse(c['overdue'].toString()) ?? 0) > 0;
    final hasPhone = (c['phone'] ?? '').toString().trim().isNotEmpty;
    final muted = Colors.grey.shade600;
    return AnimatedEntry(
      index: index + 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            title: Text(c['company'].toString(),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                overdue
                    ? '\$${c['overdue']} overdue · ${c['invoice_count']} inv'
                    : 'Due ${c['oldest_due']} · ${c['invoice_count']} inv',
                style: TextStyle(
                    color: overdue ? Colors.red.shade700 : muted,
                    fontSize: 12.5),
              ),
            ),
            trailing: Text('\$${c['balance']}',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            children: [
              for (final i in c['invoices'] as List)
                ListTile(
                  dense: true,
                  title: Text(i['number'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Due ${i['duedate']}',
                      style: TextStyle(
                          color: i['overdue'] == true
                              ? Colors.red.shade700
                              : muted)),
                  trailing: Text('\$${i['balance']}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            InvoiceViewScreen(invoiceId: i['id'].toString())),
                  ).then((_) => _fetch()),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _whatsApp(c),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366)),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: const Text('WhatsApp reminder'),
                      ),
                    ),
                    if (hasPhone) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _call(c),
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: const Text('Call'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = (_data?['customers'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Pending')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const EmptyState(
                  icon: Icons.error_outline, message: 'Could not load')
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: customers.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          EmptyState(
                              icon: Icons.celebration_outlined,
                              message: 'Nothing pending. All paid up!'),
                        ])
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            _summary(),
                            for (var i = 0; i < customers.length; i++)
                              _customerCard(i, customers[i]),
                          ],
                        ),
                ),
    );
  }
}
