import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:srashtacrmapp/services/token_store.dart';

String jwtWithExp(int epochSeconds) {
  String b64(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64({'exp': epochSeconds})}.sig';
}

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);
  int at(Duration d) => now.add(d).millisecondsSinceEpoch ~/ 1000;

  test('expiryOf reads the exp claim', () {
    final exp = TokenStore.expiryOf(jwtWithExp(at(const Duration(minutes: 5))));
    expect(exp!.toUtc(), now.add(const Duration(minutes: 5)));
    expect(TokenStore.expiryOf('garbage'), isNull);
    expect(TokenStore.expiryOf(null), isNull);
  });

  test('needsRefresh is true when expired, expiring soon or unreadable', () {
    bool needs(String? t) => TokenStore.needsRefresh(t, now: now);
    expect(needs(jwtWithExp(at(const Duration(minutes: 20)))), false);
    expect(needs(jwtWithExp(at(const Duration(seconds: 30)))), true);
    expect(needs(jwtWithExp(at(const Duration(minutes: -1)))), true);
    expect(needs('nope'), true);
    expect(needs(null), true);
  });
}
