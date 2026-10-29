import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'popup_title.dart';

/// Bottom sheet to receive a payment against an invoice.
/// Pops with `true` once the payment is saved.
class RecordPaymentSheet extends StatefulWidget {
  final String invoiceId;
  final String balanceDue;
  final List modes;

  const RecordPaymentSheet({
    super.key,
    required this.invoiceId,
    required this.balanceDue,
    required this.modes,
  });

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  late final TextEditingController _amount = TextEditingController(text: widget.balanceDue);
  final _note = TextEditingController();
  final _txn = TextEditingController();
  late String? _mode = _defaultMode();
  DateTime _date = DateTime.now();
  bool _sendReceipt = false;
  bool _saving = false;

  String? _defaultMode() {
    if (widget.modes.isEmpty) return null;
    final preset = widget.modes.firstWhere(
      (m) => m['selected_by_default']?.toString() == '1',
      orElse: () => widget.modes.first,
    );
    return preset['id'].toString();
  }

  String get _dateText =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final balance = double.tryParse(widget.balanceDue) ?? 0;
    String? error;
    if (amount <= 0) {
      error = 'Enter a valid amount';
    } else if (amount > balance) {
      error = 'Amount is more than the balance due ($balance)';
    } else if (_mode == null) {
      error = 'Select a payment mode';
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await ApiService.addPayment(widget.invoiceId, {
        'amount': amount,
        'paymentmode': _mode,
        'date': _dateText,
        'note': _note.text.trim(),
        'transactionid': _txn.text.trim(),
        'send_receipt': _sendReceipt,
      });
      if (!mounted) return;
      if (res['status'] == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Failed to record payment')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _txn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PopupTitle('Receive Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Balance due: \$${widget.balanceDue}', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ '),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Payment Mode'),
              items: [
                for (final m in widget.modes)
                  DropdownMenuItem(value: m['id'].toString(), child: Text(m['name'].toString())),
              ],
              onChanged: (v) => setState(() => _mode = v),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Payment Date',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(_dateText),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _txn,
              decoration: const InputDecoration(labelText: 'Transaction ID (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _sendReceipt,
              onChanged: (v) => setState(() => _sendReceipt = v ?? false),
              title: const Text('Email receipt to customer'),
            ),
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: const Text('Save Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
