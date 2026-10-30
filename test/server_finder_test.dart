import 'package:flutter_test/flutter_test.dart';
import 'package:srashtacrmapp/services/server_finder.dart';

void main() {
  test('subnetHosts lists the other 253 hosts of the /24', () {
    final h = ServerFinder.subnetHosts('192.168.0.182');
    expect(h.length, 253);
    expect(h.first, '192.168.0.1');
    expect(h.last, '192.168.0.254');
    expect(h.contains('192.168.0.182'), false);
    expect(ServerFinder.subnetHosts('nonsense'), isEmpty);
  });

  test('isLanAddress keeps Wi-Fi private ranges, drops mobile data', () {
    expect(ServerFinder.isLanAddress('wlan0', '192.168.1.20'), true);
    expect(ServerFinder.isLanAddress('wlan0', '10.0.0.5'), true);
    expect(ServerFinder.isLanAddress('wlan0', '172.20.1.2'), true);
    expect(ServerFinder.isLanAddress('wlan0', '172.32.1.2'), false);
    expect(ServerFinder.isLanAddress('rmnet_data1', '10.55.1.2'), false);
    expect(ServerFinder.isLanAddress('wlan0', '8.8.8.8'), false);
  });

  test('looksLikeCrmApi recognises the API reply only', () {
    expect(
        ServerFinder.looksLikeCrmApi(
            '{"status":false,"message":"Method not allowed"}'),
        true);
    expect(ServerFinder.looksLikeCrmApi('<html>router</html>'), false);
    expect(ServerFinder.looksLikeCrmApi('{"hello":1}'), false);
  });
}
