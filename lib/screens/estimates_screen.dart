import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/estimate_status.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import 'add_invoice_screen.dart';
import 'estimate_view_screen.dart';

class EstimatesScreen extends StatefulWidget {
  const EstimatesScreen({super.key});

  @override
  State<EstimatesScreen> createState() => _EstimatesScreenState();
}

class _EstimatesScreenState extends State<EstimatesScreen> {
  List<dynamic> _estimates = [];
  bool _isLoading = true;
  String? _error;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiService.getEstimates();
      if (!mounted) return;
      setState(() {
        _error = res['status'] == true
            ? null
            : (res['message']?.toString() ?? 'Failed to load');
        if (res['status'] == true) _estimates = res['data'];
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Error loading estimates');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _estimates;
    return _estimates.where((e) {
      final num = estimateNumber(e['prefix'], e['number']).toLowerCase();
      return num.contains(q) ||
          (e['company'] ?? '').toString().toLowerCase().contains(q) ||
          (e['total'] ?? '').toString().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('Estimates')),
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? EmptyState(icon: Icons.error_outline, message: _error!)
                    : RefreshIndicator(
                        onRefresh: _fetch,
                        child: list.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 120),
                                EmptyState(
                                    icon: Icons.request_quote_outlined,
                                    message: 'No estimates yet'),
                              ])
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.only(top: 4, bottom: 88),
                                itemCount: list.length,
                                itemBuilder: (context, i) => _card(i, list[i]),
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
