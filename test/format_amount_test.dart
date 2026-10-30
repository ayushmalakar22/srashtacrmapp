import 'package:flutter_test/flutter_test.dart';
import 'package:srashtacrmapp/screens/dashboard_screen.dart';

void main() {
  test('formatAmount groups digits and compacts huge values', () {
    expect(formatAmount(0), '0.00');
    expect(formatAmount(329.22), '329.22');
    expect(formatAmount(4060), '4,060.00');
    expect(formatAmount(1468.04), '1,468.04');
    expect(formatAmount(999999.99), '999,999.99');
    expect(formatAmount(9999999.99), '10.00M');
    expect(formatAmount(12345678), '12.35M');
    expect(formatAmount(1500000000), '1.50B');
    expect(formatAmount(3.2e12), '3.20T');
    expect(formatAmount(-4060), '-4,060.00');
  });
}
