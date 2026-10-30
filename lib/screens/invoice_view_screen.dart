import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/invoice_status.dart';
import '../utils/phone.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import '../widgets/record_payment_sheet.dart';
import 'add_invoice_screen.dart';

class InvoiceViewScreen extends StatefulWidget {
  final String invoiceId;

  const InvoiceViewScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceViewScreen> createState() => _InvoiceViewScreenState();
}

class _InvoiceViewScreenState extends State<InvoiceViewScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _invoice;
  Map<String, dynamic>? _payments;

  @override
  void initState() {
    super.initState();
    _fetchInvoice();
  }

  Future<void> _fetchInvoice() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getInvoice(widget.invoiceId),
        ApiService.getInvoicePayments(widget.invoiceId),
      ]);
      final response = results[0];
      if (response['status'] == true) {
        setState(() {
          _invoice = response['data'];
          _payments = results[1]['status'] == true ? results[1]['data'] : null;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to load invoice')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error loading invoice')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _shareText {
    final num = '${_invoice!['prefix'] ?? ''}${_invoice!['number'] ?? ''}';
    return 'Invoice $num - Total: ${_invoice!['total']}\n${_invoice!['share_url'] ?? ''}';
  }

  String get _reminderText {
    final num = '${_invoice!['prefix'] ?? ''}${_invoice!['number'] ?? ''}';
    final org = (_invoice!['organization']?['name'] ?? '').toString();
    final due = (_invoice!['duedate'] ?? '').toString();
    return 'Hello ${_invoice!['company'] ?? ''},\n'
        'This is a reminder that a payment of \$${_invoice!['balance_due']} for invoice $num is pending'
        '${due.isNotEmpty ? ' (due $due)' : ''}.\n'
        '${_invoice!['share_url'] ?? ''}\n'
        '${org.isNotEmpty ? 'Thank you, $org' : 'Thank you'}';
  }

  bool get _isPending => _invoice?['can_remind'] == true;

  Future<void> _shareWhatsApp() async {
    if (_invoice == null) return;
    final phone = waNumber((_invoice!['client_phone'] ?? '').toString(),
        (_invoice!['organization']?['country_code'] ?? '').toString());
    final text = _isPending ? _reminderText : _shareText;
    final uri =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  Future<void> _call() async {
    final phone = (_invoice?['client_phone'] ?? '').toString().trim();
    if (phone.isEmpty) return;
    if (!await launchUrl(Uri(scheme: 'tel', path: phone)) && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open dialer')));
    }
  }

  Future<void> _sendEmail() async {
    if (_invoice == null) return;
    final email = (_invoice!['client_email'] ?? '').toString();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'This customer has no contact with an email. Add a contact (with email) under the customer first.'),
      ));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email invoice?'),
        content: Text('It will be emailed to $email.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ApiService.sendInvoice(widget.invoiceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Done')));
      if (res['status'] == true) _fetchInvoice();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _downloadPdf() async {
    if (_invoice == null) return;

    try {
      final token = await ApiService.getToken();
      final url =
          '${ApiService.baseUrl}/invoice_pdf/${widget.invoiceId}?token=$token';

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Could not launch browser to download PDF')),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  bool get _canReceivePayment {
    final status = _invoice?['status']?.toString();
    final balance =
        double.tryParse(_payments?['balance_due']?.toString() ?? '0') ?? 0;
    return _payments?['can_create'] == true &&
        status != '2' &&
        status != '5' &&
        balance > 0;
  }

  Future<void> _receivePayment() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RecordPaymentSheet(
        invoiceId: widget.invoiceId,
        balanceDue: _payments!['balance_due'].toString(),
        modes: _payments!['payment_modes'] as List,
      ),
    );
    if (saved == true) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Payment recorded')));
      }
      _fetchInvoice();
    }
  }

  Future<void> _deletePayment(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete payment?'),
        content: const Text('The invoice balance and status will be updated.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ApiService.deletePayment(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Done')));
      if (res['status'] == true) _fetchInvoice();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildPayments() {
    final p = _payments;
    if (p == null) return const SizedBox.shrink();
    final rows = p['payments'] as List;
    if (rows.isEmpty && !_canReceivePayment) return const SizedBox.shrink();
    final muted = Colors.grey.shade600;
    return _card(
      4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('Payments', icon: Icons.payments_outlined),
          Row(
            children: [
              Expanded(
                  child: _paySummary(
                      'Paid', '\$${p['total_paid']}', Colors.green.shade700)),
              Expanded(
                  child: _paySummary('Balance Due', '\$${p['balance_due']}',
                      Colors.red.shade700)),
            ],
          ),
          if (_canReceivePayment) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _receivePayment,
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Receive Payment'),
            ),
          ],
          for (final r in rows) ...[
            Divider(height: 20, color: Colors.grey.shade200),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('\$${r['amount']}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                          [r['date'], r['mode']]
                              .where((e) => e.toString().isNotEmpty)
                              .join(' · '),
                          style: TextStyle(fontSize: 12.5, color: muted)),
                      if (r['note'].toString().isNotEmpty)
                        Text(r['note'].toString(),
                            style: TextStyle(fontSize: 12.5, color: muted)),
                    ],
                  ),
                ),
                if (p['can_delete'] == true)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete payment',
                    onPressed: () => _deletePayment(r['id'].toString()),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _paySummary(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _card(int index, {required Widget child, EdgeInsets? padding}) {
    return AnimatedEntry(
      index: index,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child:
            Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
      ),
    );
  }

  Widget _sectionLabel(String text, {IconData? icon}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 6)
          ],
          Text(text,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                  fontSize: 13.5)),
        ],
      ),
    );
  }

  Widget _buildHero(String invNumber) {
    final st = InvoiceStatus.of(_invoice!['status']);
    final due = (_invoice!['duedate'] ?? '').toString();
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
            Row(
              children: [
                Expanded(
                  child: Text(invNumber,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(st.label,
                      style: TextStyle(
                          color: st.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Total',
                style: TextStyle(color: Colors.white70, fontSize: 12.5)),
            Text(
              '\$${_invoice!['total'] ?? '0.00'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _heroDate(
                        'Date', (_invoice!['date'] ?? '').toString())),
                if (due.isNotEmpty) Expanded(child: _heroDate('Due', due)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroDate(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _actionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return _card(
      1,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          _actionButton(Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366),
              _shareWhatsApp),
          if (_invoice!['can_email'] == true)
            _actionButton(Icons.email_rounded, 'Email', const Color(0xFFEA4335),
                _sendEmail),
          if ((_invoice!['client_phone'] ?? '').toString().trim().isNotEmpty)
            _actionButton(
                Icons.call_rounded, 'Call', const Color(0xFF1E88E5), _call),
          _actionButton(Icons.picture_as_pdf_rounded, 'PDF',
              const Color(0xFFF57C00), _downloadPdf),
        ],
      ),
    );
  }

  Widget _buildOrganizationInfo() {
    final org = _invoice?['organization'] as Map<String, dynamic>?;
    if (org == null) return const SizedBox.shrink();

    final name = (org['name'] ?? '').toString();
    final address = (org['address'] ?? '').toString();
    final city = (org['city'] ?? '').toString();
    final state = (org['state'] ?? '').toString();
    final zip = (org['zip'] ?? '').toString();
    final countryCode = (org['country_code'] ?? '').toString();
    final phone = (org['phone'] ?? '').toString();
    final vat = (org['vat'] ?? '').toString();

    if (name.isEmpty && address.isEmpty) return const SizedBox.shrink();

    final cityLine = [city, state].where((s) => s.isNotEmpty).join(', ');
    final zipCountryLine =
        [countryCode, zip].where((s) => s.isNotEmpty).join(' ');

    return _card(
      2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('From', icon: Icons.business_rounded),
          if (name.isNotEmpty)
            Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          if (address.isNotEmpty) Text(address),
          if (cityLine.isNotEmpty) Text(cityLine),
          if (zipCountryLine.isNotEmpty) Text(zipCountryLine),
          if (phone.isNotEmpty) Text('Phone: $phone'),
          if (vat.isNotEmpty) Text('VAT: $vat'),
        ],
      ),
    );
  }

  Widget _addressBlock(String title, IconData icon, String? name, String street,
      String city, String zip, String state) {
    final lines = [
      street,
      [city, zip].where((s) => s.isNotEmpty).join(' '),
      state,
    ].where((s) => s.trim().isNotEmpty).join('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(title, icon: icon),
        if (name != null && name.isNotEmpty)
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (lines.isNotEmpty) Text(lines),
      ],
    );
  }

  Widget _buildAddresses() {
    final showShip = _invoice!['include_shipping'] == '1' &&
        _invoice!['show_shipping_on_invoice'] == '1';
    String f(String k) => (_invoice![k] ?? '').toString();
    return _card(
      3,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _addressBlock(
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
              child: _addressBlock(
                  'Ship To',
                  Icons.local_shipping_outlined,
                  null,
                  f('shipping_street'),
                  f('shipping_city'),
                  f('shipping_zip'),
                  f('shipping_state')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItems(List items) {
    final muted = Colors.grey.shade600;
    return _card(
      4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('Items', icon: Icons.list_alt_rounded),
          if (items.isEmpty) Text('No items', style: TextStyle(color: muted)),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 20, color: Colors.grey.shade200),
            _itemRow(items[i], muted),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(dynamic item, Color muted) {
    final qty = double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0;
    final rate = double.tryParse(item['rate']?.toString() ?? '0') ?? 0.0;
    final long = (item['long_description'] ?? '').toString();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['description']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (long.isNotEmpty)
                Text(long, style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 2),
              Text('${item['qty'] ?? '1'} × \$${item['rate'] ?? '0.00'}',
                  style: TextStyle(fontSize: 12.5, color: muted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text('\$${(qty * rate).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildTotals(List items) {
    final discount =
        double.tryParse(_invoice!['discount_total']?.toString() ?? '0') ?? 0;
    final adjustment =
        double.tryParse(_invoice!['adjustment']?.toString() ?? '0') ?? 0;
    return _card(
      5,
      child: Column(
        children: [
          _buildTotalRow('Sub Total', '\$${_invoice!['subtotal'] ?? '0.00'}'),
          if (discount > 0)
            _buildTotalRow('Discount', '-\$${_invoice!['discount_total']}'),
          ..._taxBreakdown(items).entries.map((tax) =>
              _buildTotalRow(tax.key, '\$${tax.value.toStringAsFixed(2)}')),
          if (adjustment != 0)
            _buildTotalRow('Adjustment', '\$${_invoice!['adjustment']}'),
          const Divider(height: 20),
          _buildTotalRow('Total', '\$${_invoice!['total'] ?? '0.00'}',
              isBold: true, fontSize: 18),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    final note = (_invoice!['clientnote'] ?? '').toString();
    final terms = (_invoice!['terms'] ?? '').toString();
    if (note.isEmpty && terms.isEmpty) return const SizedBox.shrink();
    return _card(
      6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note.isNotEmpty) ...[
            _sectionLabel('Client Note', icon: Icons.sticky_note_2_outlined),
            Text(note),
          ],
          if (note.isNotEmpty && terms.isNotEmpty) const SizedBox(height: 16),
          if (terms.isNotEmpty) ...[
            _sectionLabel('Terms & Conditions', icon: Icons.gavel_rounded),
            Text(terms),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: const EmptyState(
            icon: Icons.receipt_long_outlined, message: 'Invoice not found'),
      );
    }

    final String invNumber =
        '${_invoice!['prefix'] ?? ''}${_invoice!['number'] ?? ''}';
    final List items = _invoice!['items'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(invNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Invoice',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddInvoiceScreen(invoiceId: widget.invoiceId),
                ),
              ).then((_) => _fetchInvoice());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchInvoice,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildHero(invNumber),
            _buildActions(),
            _buildOrganizationInfo(),
            _buildAddresses(),
            _buildItems(items),
            _buildTotals(items),
            _buildPayments(),
            _buildNotes(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Per-tax breakdown (e.g. "CGST (9.00%)" -> amount), summed across all
  /// items, mirroring the CGST/SGST line items shown on the web admin panel.
  Map<String, double> _taxBreakdown(List items) {
    final Map<String, double> breakdown = {};
    for (var item in items) {
      final qty = double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0;
      final rate = double.tryParse(item['rate']?.toString() ?? '0') ?? 0.0;
      final itemSubtotal = qty * rate;
      final taxes = item['taxname'];
      if (taxes is List) {
        for (var tax in taxes) {
          if (tax is String && tax.contains('|')) {
            final parts = tax.split('|');
            if (parts.length >= 2) {
              final name = parts[0];
              final ratePercent = double.tryParse(parts[1]) ?? 0.0;
              final label = '$name (${ratePercent.toStringAsFixed(2)}%)';
              final amount = (itemSubtotal * ratePercent) / 100.0;
              breakdown[label] = (breakdown[label] ?? 0) + amount;
            }
          }
        }
      }
    }
    return breakdown;
  }

  Widget _buildTotalRow(String label, String value,
      {bool isBold = false, double fontSize = 14}) {
    final style = TextStyle(
        fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
        fontSize: fontSize);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  style.copyWith(color: isBold ? null : Colors.grey.shade700)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
