import 'package:flutter_test/flutter_test.dart';
import 'package:srashtacrmapp/utils/invoice_status.dart';
import 'package:srashtacrmapp/widgets/list_filters.dart';

void main() {
  final now = DateTime(2026, 10, 30);

  test('effectiveInvoiceStatus marks past-due unpaid/partial as overdue', () {
    expect(effectiveInvoiceStatus('1', '2026-10-29', now), '4');
    expect(effectiveInvoiceStatus('3', '2026-01-01', now), '4');
    expect(effectiveInvoiceStatus('1', '2026-10-30', now), '1'); // due today
    expect(effectiveInvoiceStatus('1', '2026-11-25', now), '1');
    expect(effectiveInvoiceStatus('2', '2020-01-01', now), '2'); // paid stays
    expect(effectiveInvoiceStatus('6', '2020-01-01', now), '6'); // draft stays
    expect(effectiveInvoiceStatus('1', null, now), '1');
  });

  test('DateFilter presets and contains', () {
    final p = {for (final f in DateFilter.presets(now)) f.label: f};
    expect(p['All time']!.contains('1999-01-01'), true);
    expect(p['This month']!.contains('2026-10-01'), true);
    expect(p['This month']!.contains('2026-10-30'), true);
    expect(p['This month']!.contains('2026-09-30'), false);
    expect(p['Last month']!.contains('2026-09-15'), true);
    expect(p['Last month']!.contains('2026-10-01'), false);
    expect(p['Last 30 days']!.contains('2026-10-01'), true);
    expect(p['Last 30 days']!.contains('2026-09-30'), false);
    expect(p['This month']!.contains(null), false);
    expect(p['This month']!.contains('2026-10-15 10:00:00'), true);
  });
}
