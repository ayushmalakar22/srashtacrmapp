import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/phone.dart';
import '../widgets/animated_entry.dart';
import '../widgets/currency_selector.dart';
import '../utils/paged_list.dart';
import '../widgets/empty_state.dart';
import '../widgets/paged_footer.dart';
import 'invoice_view_screen.dart';

/// Who owes money: pending balance per customer, biggest first, with one-tap
/// WhatsApp / call reminders.
class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  late final PagedList _list = PagedList(_fetchPage);
  Map<String, dynamic>? _data; // totals + currency info of the latest answer
  String? _currencyId; // null = the base currency
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  String get _sym => (_data?['currency_symbol'] ?? '\$').toString();

  /// The totals always cover everyone; the customers come a page at a time.
  Future<Map<String, dynamic>> _fetchPage(int offset, int limit) async {
    _currencyId ??= await CurrencyPref.load();
    final res = await ApiService.getPending(
      currency: _currencyId,
      offset: offset,
      limit: limit,
      search: _search.text.trim(),
    );
    if (res['status'] != true) return res;
    _data = res['data'];
    _currencyId = res['data']['currency_id']?.toString();
    return {
      'status': true,
      'data': res['data']['customers'],
      'total': res['total'],
    };
  }

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
    _search.dispose();
    _scroll.dispose();
    _list.dispose();
    super.dispose();
  }

  /// Reload quietly, keeping the rows and scroll position.
  Future<void> _fetch() => _list.refresh(silent: true);

  String _reminderText(Map c) {
    final org = (_data?['organization'] ?? '').toString();
    final invoices = (c['invoices'] as List).map((i) => i['number']).join(', ');
    final overdue = double.tryParse(c['overdue'].toString()) ?? 0;
    final n = c['invoice_count'];
    return 'Hello ${c['company']},\n'
        'This is a reminder that a payment of $_sym${c['balance']} is pending '
        '(${n == 1 ? 'invoice' : '$n invoices'}: $invoices)'
        '${overdue > 0 ? ', of which $_sym${c['overdue']} is overdue' : ''}.\n'
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
              tile('To collect', '$_sym${_data!['total_pending']}',
                  Colors.white),
              tile('Overdue', '$_sym${_data!['total_overdue']}',
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
                    ? '$_sym${c['overdue']} overdue · ${c['invoice_count']} inv'
                    : 'Due ${c['oldest_due']} · ${c['invoice_count']} inv',
                style: TextStyle(
                    color: overdue ? Colors.red.shade700 : muted,
                    fontSize: 12.5),
              ),
            ),
            trailing: Text('$_sym${c['balance']}',
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
                  trailing: Text('$_sym${i['balance']}',
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
    final q = _search.text.trim();
    final nothingPending = (_data?['customer_count'] ?? 0) == 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Pending')),
      body: _list.loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? EmptyState(
                  icon: Icons.cloud_off_outlined,
                  message: _list.error ?? 'Could not load',
                  actionLabel: 'Retry',
                  onAction: () => _list.refresh())
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      CurrencySelector(
                        currencies: (_data?['currencies'] as List?) ?? [],
                        selectedId: _currencyId ?? '',
                        onSelected: (id) {
                          setState(() => _currencyId = id);
                          CurrencyPref.save(id);
                          _list.refresh();
                        },
                      ),
                      if (nothingPending)
                        const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: EmptyState(
                              icon: Icons.celebration_outlined,
                              message: 'Nothing pending. All paid up!'),
                        )
                      else ...[
                        _summary(),
                        if ((_data?['customer_count'] ?? 0) > 3 || q.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: _search,
                              decoration: InputDecoration(
                                hintText: 'Search customer or phone...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: q.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: _search.clear),
                              ),
                            ),
                          ),
                        if (_list.items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: EmptyState(
                                icon: Icons.search_off,
                                message: 'No customer matches'),
                          ),
                        for (var i = 0; i < _list.items.length; i++)
                          _customerCard(i, _list.items[i]),
                        PagedFooter(list: _list),
                      ],
                    ],
                  ),
                ),
    );
  }
}
