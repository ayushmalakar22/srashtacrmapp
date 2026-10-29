import 'package:flutter/material.dart';

/// Perfex estimate statuses: 1 Draft, 2 Sent, 3 Declined, 4 Accepted, 5 Expired
class EstimateStatus {
  final String label;
  final Color color;
  const EstimateStatus(this.label, this.color);

  static EstimateStatus of(dynamic status) {
    switch (status?.toString()) {
      case '2':
        return const EstimateStatus('Sent', Colors.blue);
      case '3':
        return const EstimateStatus('Declined', Colors.red);
      case '4':
        return const EstimateStatus('Accepted', Colors.green);
      case '5':
        return EstimateStatus('Expired', Colors.orange.shade800);
      default:
        return const EstimateStatus('Draft', Colors.grey);
    }
  }
}

/// "EST-" + "1" -> "EST-000001" (Perfex's default estimate number format)
String estimateNumber(dynamic prefix, dynamic number) =>
    '${prefix ?? ''}${(number ?? '').toString().padLeft(6, '0')}';
