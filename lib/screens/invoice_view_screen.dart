import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/invoice_status.dart';
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
  
  @override
  void initState() {
    super.initState();
    _fetchInvoice();
  }

  Future<void> _fetchInvoice() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getInvoice(widget.invoiceId);
      if (response['status'] == true) {
        setState(() {
          _invoice = response['data'];
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load invoice')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error loading invoice')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _shareText {
    final num = '${_invoice!['prefix'] ?? ''}${_invoice!['number'] ?? ''}';
    return 'Invoice $num - Total: ${_invoice!['total']}\n${_invoice!['share_url'] ?? ''}';
  }

  Future<void> _shareWhatsApp() async {
    if (_invoice == null) return;
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_shareText)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  Future<void> _shareEmail() async {
    if (_invoice == null) return;
    final num = '${_invoice!['prefix'] ?? ''}${_invoice!['number'] ?? ''}';
    final uri = Uri(
      scheme: 'mailto',
      path: _invoice!['client_email']?.toString() ?? '',
      query: 'subject=${Uri.encodeComponent('Invoice $num')}&body=${Uri.encodeComponent(_shareText)}',
    );
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No email app found')));
    }
  }

  Future<void> _downloadPdf() async {
    if (_invoice == null) return;

    try {
      final token = await ApiService.getToken();
      final url = '${ApiService.baseUrl}/invoice_pdf/${widget.invoiceId}?token=$token';
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch browser to download PDF')),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
  
  Widget _buildStatusBadge() {
    if (_invoice == null) return const SizedBox.shrink();
    
    final st = InvoiceStatus.of(_invoice!['status']);
    final bgColor = st.color.withOpacity(0.1);
    final textColor = st.color;
    final text = st.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor),
      ),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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
        body: const Center(child: Text('Invoice not found')),
      );
    }
    
    final String invNumber = '${_invoice!['prefix'] ?? ''}${_invoice!['number'] ?? ''}';
    final List items = _invoice!['items'] ?? [];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(invNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Share via WhatsApp',
            onPressed: _shareWhatsApp,
          ),
          IconButton(
            icon: const Icon(Icons.email),
            tooltip: 'Share via Email',
            onPressed: _shareEmail,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Download PDF',
            onPressed: _downloadPdf,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and Basic Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusBadge(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Date: ${_invoice!['date'] ?? ''}', style: const TextStyle(color: Colors.grey)),
                    if (_invoice!['duedate'] != null && _invoice!['duedate'].toString().isNotEmpty)
                      Text('Due Date: ${_invoice!['duedate']}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Addresses
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bill To', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      if ((_invoice!['company'] ?? '').toString().isNotEmpty)
                        Text(
                          _invoice!['company'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      Text('${_invoice!['billing_street'] ?? ''}\n${_invoice!['billing_city'] ?? ''} ${_invoice!['billing_zip'] ?? ''}\n${_invoice!['billing_state'] ?? ''}'),
                    ],
                  ),
                ),
                if (_invoice!['include_shipping'] == '1' && _invoice!['show_shipping_on_invoice'] == '1')
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ship To', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('${_invoice!['shipping_street'] ?? ''}\n${_invoice!['shipping_city'] ?? ''} ${_invoice!['shipping_zip'] ?? ''}\n${_invoice!['shipping_state'] ?? ''}'),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            
            // Items Table Header
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const Divider(),
            
            // Items
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['description']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                        if (item['long_description'] != null && item['long_description'].toString().isNotEmpty)
                          Text(item['long_description'].toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    )),
                    Expanded(flex: 1, child: Text(item['qty']?.toString() ?? '1', textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text('\$${item['rate']?.toString() ?? '0.00'}', textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text('\$${((double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0) * (double.tryParse(item['rate']?.toString() ?? '0') ?? 0.0)).toStringAsFixed(2)}', textAlign: TextAlign.right)),
                  ],
                ),
              );
            }),
            
            const Divider(thickness: 2),
            const SizedBox(height: 8),
            
            // Totals
            _buildTotalRow('Sub Total:', '\$${_invoice!['subtotal'] ?? '0.00'}'),
            if (double.tryParse(_invoice!['discount_total']?.toString() ?? '0') != null && double.parse(_invoice!['discount_total'].toString()) > 0)
              _buildTotalRow('Discount:', '-\$${_invoice!['discount_total']}'),
            ..._taxBreakdown(items).entries.map(
                  (tax) => _buildTotalRow('${tax.key}:', '\$${tax.value.toStringAsFixed(2)}'),
                ),
            if (double.tryParse(_invoice!['adjustment']?.toString() ?? '0') != null && double.parse(_invoice!['adjustment'].toString()) != 0)
              _buildTotalRow('Adjustment:', '\$${_invoice!['adjustment']}'),
            const SizedBox(height: 8),
            _buildTotalRow('Total:', '\$${_invoice!['total'] ?? '0.00'}', isBold: true, fontSize: 18),
            
            const SizedBox(height: 24),
            if (_invoice!['clientnote'] != null && _invoice!['clientnote'].toString().isNotEmpty) ...[
              const Text('Client Note', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_invoice!['clientnote'].toString()),
              const SizedBox(height: 16),
            ],
            if (_invoice!['terms'] != null && _invoice!['terms'].toString().isNotEmpty) ...[
              const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_invoice!['terms'].toString()),
            ],
            const SizedBox(height: 40),
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

  Widget _buildTotalRow(String label, String value, {bool isBold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }
}
