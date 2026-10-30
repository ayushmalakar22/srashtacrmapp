import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/estimate_status.dart';
import '../utils/phone.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import 'add_invoice_screen.dart';
import 'invoice_view_screen.dart';

class EstimateViewScreen extends StatefulWidget {
  final String estimateId;
  const EstimateViewScreen({super.key, required this.estimateId});

  @override
  State<EstimateViewScreen> createState() => _EstimateViewScreenState();
}

class _EstimateViewScreenState extends State<EstimateViewScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _est;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiService.getEstimate(widget.estimateId);
      if (!mounted) return;
      if (res['status'] == true) setState(() => _est = res['data']);
    } catch (e) {
      if (mounted) _snack('Error loading estimate');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String get _number => _est!['number_formatted']?.toString() ?? '';

  String get _shareText {
    final org = (_est!['organization']?['name'] ?? '').toString();
    return 'Hello ${_est!['company'] ?? ''},\n'
        'Here is our estimate $_number for $_sym${_est!['total']}'
        '${(_est!['expirydate'] ?? '').toString().isNotEmpty ? ' (valid till ${_est!['expirydate']})' : ''}.\n'
        '${_est!['share_url'] ?? ''}\n'
        '${org.isNotEmpty ? 'Thank you, $org' : 'Thank you'}';
  }

  Future<void> _whatsApp() async {
    final phone = waNumber((_est!['client_phone'] ?? '').toString(),
        (_est!['organization']?['country_code'] ?? '').toString());
    final uri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(_shareText)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted)
      _snack('Could not open WhatsApp');
  }

  Future<void> _call() async {
    final phone = (_est!['client_phone'] ?? '').toString().trim();
    if (!await launchUrl(Uri(scheme: 'tel', path: phone)) && mounted)
      _snack('Could not open dialer');
  }

  Future<void> _pdf() async {
    final token = await ApiService.getToken();
    final uri = Uri.parse(
        '${ApiService.baseUrl}/estimate_pdf/${widget.estimateId}?token=$token');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted)
      _snack('Could not open PDF');
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete estimate?'),
        content: Text('$_number will be deleted permanently.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ApiService.deleteEstimate(widget.estimateId);
      if (!mounted) return;
      _snack(res['message']?.toString() ?? 'Done');
      if (res['status'] == true) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }
  }

  Future<void> _convert() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to invoice?'),
        content:
            const Text('A new invoice will be created from this estimate.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'draft'),
              child: const Text('Save as draft')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'now'),
              child: const Text('Convert')),
        ],
      ),
    );
    if (choice == null) return;
    try {
      final res = await ApiService.convertEstimate(widget.estimateId,
          draft: choice == 'draft');
      if (!mounted) return;
      if (res['status'] == true) {
        final invoiceId = res['data']['invoice_id'].toString();
        _snack('Invoice created');
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => InvoiceViewScreen(invoiceId: invoiceId)),
        );
      } else {
        _snack(res['message']?.toString() ?? 'Failed to convert');
      }
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }
  }

  Future<void> _changeStatus() async {
    final current = _est!['status'].toString();
    const all = [
      '1',
      '2',
      '5',
      '3',
      '4'
    ]; // admin order: Draft, Sent, Expired, Declined, Accepted
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Mark as',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            for (final st in all.where((e) => e != current))
              ListTile(
                leading: Icon(Icons.circle,
                    size: 14, color: EstimateStatus.of(st).color),
                title: Text(EstimateStatus.of(st).label),
                onTap: () => Navigator.pop(ctx, st),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      final res = await ApiService.setEstimateStatus(
          widget.estimateId, int.parse(picked));
      if (!mounted) return;
      _snack(res['message']?.toString() ?? 'Done');
      if (res['status'] == true) _fetch();
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }
  }

  Widget _card(int index, {required Widget child}) => AnimatedEntry(
        index: index,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      );

  Widget _label(String text, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.primary,
                fontSize: 13.5)),
      ]),
    );
  }

  Widget _action(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color, size: 21)),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );

  Widget _hero() {
    final st = EstimateStatus.of(_est!['status']);
    final exp = (_est!['expirydate'] ?? '').toString();
    Widget date(String l, String v) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(v,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(_number,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 15))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Text(st.label,
                  style: TextStyle(
                      color: st.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5)),
            ),
          ]),
          const SizedBox(height: 10),
          const Text('Total',
              style: TextStyle(color: Colors.white70, fontSize: 12.5)),
          Text('$_sym${_est!['total'] ?? '0.00'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: date('Date', (_est!['date'] ?? '').toString())),
            if (exp.isNotEmpty) Expanded(child: date('Valid till', exp)),
          ]),
        ]),
      ),
    );
  }

  Widget _actions() {
    final hasPhone = (_est!['client_phone'] ?? '').toString().trim().isNotEmpty;
    return _card(
      1,
      child: Row(children: [
        _action(
            Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366), _whatsApp),
        if (hasPhone)
          _action(Icons.call_rounded, 'Call', const Color(0xFF1E88E5), _call),
        _action(
            Icons.picture_as_pdf_rounded, 'PDF', const Color(0xFFF57C00), _pdf),
      ]),
    );
  }

  Widget _workflow() {
    final invoiceId = _est!['invoiceid'];
    if (invoiceId != null) {
      return _card(
        2,
        child: Row(children: [
          const Icon(Icons.check_circle, color: Colors.teal),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('Converted to an invoice',
                  style: TextStyle(fontWeight: FontWeight.w600))),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      InvoiceViewScreen(invoiceId: invoiceId.toString())),
            ),
            child: const Text('View'),
          ),
        ]),
      );
    }
    final canConvert = _est!['can_convert'] == true;
    final canStatus = _est!['can_change_status'] == true;
    if (!canConvert && !canStatus) return const SizedBox.shrink();
    return _card(
      2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (canConvert)
          FilledButton.icon(
            onPressed: _convert,
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Convert to Invoice'),
          ),
        if (canConvert && canStatus) const SizedBox(height: 8),
        if (canStatus)
          OutlinedButton.icon(
            onPressed: _changeStatus,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Change status'),
          ),
      ]),
    );
  }

  Widget _items(List items) {
    final muted = Colors.grey.shade600;
    return _card(
      3,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label('Items', Icons.list_alt_rounded),
        if (items.isEmpty) Text('No items', style: TextStyle(color: muted)),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Divider(height: 20, color: Colors.grey.shade200),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(items[i]['description']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if ((items[i]['long_description'] ?? '')
                        .toString()
                        .isNotEmpty)
                      Text(items[i]['long_description'].toString(),
                          style: TextStyle(fontSize: 12, color: muted)),
                    Text(
                        '${items[i]['qty'] ?? '1'} × $_sym${items[i]['rate'] ?? '0.00'}',
                        style: TextStyle(fontSize: 12.5, color: muted)),
                  ]),
            ),
            const SizedBox(width: 12),
            Text(
              '$_sym${((double.tryParse('${items[i]['qty']}') ?? 1) * (double.tryParse('${items[i]['rate']}') ?? 0)).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ]),
        ],
      ]),
    );
  }

  Map<String, double> _taxes(List items) {
    final out = <String, double>{};
    for (final it in items) {
      final line = (double.tryParse('${it['qty']}') ?? 1) *
          (double.tryParse('${it['rate']}') ?? 0);
      final taxes = it['taxname'];
      if (taxes is! List) continue;
      for (final t in taxes) {
        final parts = t.toString().split('|');
        if (parts.length < 2) continue;
        final pct = double.tryParse(parts[1]) ?? 0;
        final key = '${parts[0]} (${pct.toStringAsFixed(2)}%)';
        out[key] = (out[key] ?? 0) + line * pct / 100;
      }
    }
    return out;
  }

  Widget _row(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  fontSize: bold ? 18 : 14,
                  color: bold ? null : Colors.grey.shade700)),
          Text(v,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  fontSize: bold ? 18 : 14)),
        ]),
      );

  Widget _totals(List items) {
    final discount = double.tryParse('${_est!['discount_total'] ?? 0}') ?? 0;
    final adjustment = double.tryParse('${_est!['adjustment'] ?? 0}') ?? 0;
    return _card(
      4,
      child: Column(children: [
        _row('Sub Total', '$_sym${_est!['subtotal'] ?? '0.00'}'),
        if (discount > 0) _row('Discount', '-$_sym${_est!['discount_total']}'),
        for (final t in _taxes(items).entries)
          _row(t.key, '$_sym${t.value.toStringAsFixed(2)}'),
        if (adjustment != 0) _row('Adjustment', '$_sym${_est!['adjustment']}'),
        const Divider(height: 20),
        _row('Total', '$_sym${_est!['total'] ?? '0.00'}', bold: true),
      ]),
    );
  }

  Widget _from() {
    final org = _est!['organization'] as Map<String, dynamic>?;
    if (org == null) return const SizedBox.shrink();
    String f(String k) => (org[k] ?? '').toString();
    if (f('name').isEmpty && f('address').isEmpty)
      return const SizedBox.shrink();
    final cityLine =
        [f('city'), f('state')].where((e) => e.isNotEmpty).join(', ');
    final zipLine =
        [f('country_code'), f('zip')].where((e) => e.isNotEmpty).join(' ');
    return _card(
      5,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('From', Icons.business_rounded),
        if (f('name').isNotEmpty)
          Text(f('name'),
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        if (f('address').isNotEmpty) Text(f('address')),
        if (cityLine.isNotEmpty) Text(cityLine),
        if (zipLine.isNotEmpty) Text(zipLine),
        if (f('phone').isNotEmpty) Text('Phone: ${f('phone')}'),
        if (f('vat').isNotEmpty) Text('VAT: ${f('vat')}'),
      ]),
    );
  }

  Widget _addr(String title, IconData icon, String? name, String street,
      String city, String zip, String state) {
    final lines = [
      street,
      [city, zip].where((e) => e.isNotEmpty).join(' '),
      state
    ].where((e) => e.trim().isNotEmpty).join('\n');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(title, icon),
      if (name != null && name.isNotEmpty)
        Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      if (lines.isNotEmpty) Text(lines),
    ]);
  }

  Widget _addresses() {
    String f(String k) => (_est![k] ?? '').toString();
    final showShip = _est!['include_shipping'] == '1' &&
        _est!['show_shipping_on_estimate'] == '1';
    return _card(
      6,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: _addr(
              'Bill To',
              Icons.person_pin_circle_outlined,
              f('company'),
              f('billing_street'),
              f('billing_city'),
              f('billing_zip'),
              f('billing_state')),
        ),
        if (showShip) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _addr(
                'Ship To',
                Icons.local_shipping_outlined,
                null,
                f('shipping_street'),
                f('shipping_city'),
                f('shipping_zip'),
                f('shipping_state')),
          ),
        ],
      ]),
    );
  }

  Widget _notes() {
    final note = (_est!['clientnote'] ?? '').toString();
    final terms = (_est!['terms'] ?? '').toString();
    if (note.isEmpty && terms.isEmpty) return const SizedBox.shrink();
    return _card(
      7,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (note.isNotEmpty) ...[
          _label('Client Note', Icons.sticky_note_2_outlined),
          Text(note)
        ],
        if (note.isNotEmpty && terms.isNotEmpty) const SizedBox(height: 16),
        if (terms.isNotEmpty) ...[
          _label('Terms & Conditions', Icons.gavel_rounded),
          Text(terms)
        ],
      ]),
    );
  }

  String get _sym => (_est?['symbol'] ?? '\$').toString();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
          appBar: AppBar(title: const Text('Loading...')),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_est == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estimate')),
        body: const EmptyState(
            icon: Icons.request_quote_outlined, message: 'Estimate not found'),
      );
    }
    final List items = _est!['items'] ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(_number),
        actions: [
          if (_est!['can_delete'] == true)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Estimate',
              onPressed: _delete,
            ),
          if (_est!['can_edit'] == true)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Estimate',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddInvoiceScreen(
                      invoiceId: widget.estimateId, isEstimate: true),
                ),
              ).then((_) => _fetch()),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _hero(),
            _actions(),
            _workflow(),
            _from(),
            _addresses(),
            _items(items),
            _totals(items),
            _notes(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
