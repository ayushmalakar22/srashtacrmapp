/// Digits-only number for wa.me links. A bare 10-digit number gets the Indian
/// country code when the company is in India.
String waNumber(String raw, String companyCountry) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final c = companyCountry.toLowerCase();
  final isIndia = c == 'in' || c == 'india';
  if (isIndia && digits.length == 10) return '91$digits';
  return digits;
}
