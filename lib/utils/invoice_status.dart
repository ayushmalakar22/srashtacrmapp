import 'package:flutter/material.dart';

/// Perfex invoice statuses: 1 Unpaid, 2 Paid, 3 Partially Paid, 4 Overdue, 5 Cancelled, 6 Draft
class InvoiceStatus {
  final String label;
  final Color color;
  const InvoiceStatus(this.label, this.color);

  static InvoiceStatus of(dynamic status) {
    switch (status?.toString()) {
      case '1':
        return const InvoiceStatus('Unpaid', Colors.red);
      case '2':
        return const InvoiceStatus('Paid', Colors.green);
      case '3':
        return const InvoiceStatus('Partially Paid', Colors.blue);
      case '4':
        return InvoiceStatus('Overdue', Colors.red.shade900);
      case '5':
        return const InvoiceStatus('Cancelled', Colors.blueGrey);
      default:
        return const InvoiceStatus('Draft', Colors.grey);
    }
  }
}

/// Status as people read it: an unpaid or partly paid invoice whose due date
/// has passed is overdue even before the server's nightly job marks it so.
/// Same rule the Dashboard and Pending screens use.
String effectiveInvoiceStatus(dynamic status, dynamic dueDate, [DateTime? now]) {
  final s = status?.toString() ?? '';
  if (s == '1' || s == '3') {
    final due = DateTime.tryParse((dueDate ?? '').toString());
    final n = now ?? DateTime.now();
    if (due != null && due.isBefore(DateTime(n.year, n.month, n.day))) {
      return '4';
    }
  }
  return s;
}
