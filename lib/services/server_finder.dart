import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Finds the CRM server on the phone's own Wi-Fi network, so nobody has to
/// type the Mac's IP when it changes (router restart, new network...).
class ServerFinder {
  /// The other 253 hosts of the /24 network that [ip] belongs to.
  static List<String> subnetHosts(String ip) {
    final p = ip.split('.');
    if (p.length != 4) return const [];
    final self = int.tryParse(p[3]);
    return [
      for (var i = 1; i <= 254; i++)
        if (i != self) '${p[0]}.${p[1]}.${p[2]}.$i',
    ];
  }

  /// Private Wi-Fi/LAN addresses only; mobile data (rmnet...) is skipped.
  static bool isLanAddress(String name, String ip) {
    final n = name.toLowerCase();
    if (n.startsWith('rmnet') ||
        n.startsWith('ccmni') ||
        n.startsWith('pdp') ||
        n.startsWith('v4-') ||
        n.startsWith('tun') ||
        n.startsWith('ppp')) {
      return false;
    }
    final p = ip.split('.').map(int.tryParse).toList();
    if (p.length != 4 || p.contains(null)) return false;
    return p[0] == 10 ||
        (p[0] == 192 && p[1] == 168) ||
        (p[0] == 172 && p[1]! >= 16 && p[1]! <= 31);
  }

  /// True when [body] is what the CRM API answers on `/login` to a GET.
  static bool looksLikeCrmApi(String body) {
    try {
      final j = jsonDecode(body);
      return j is Map && j.containsKey('status') && j.containsKey('message');
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _probe(String host, String port) async {
    final base = 'http://$host:$port/mobile_api';
    try {
      final res = await http
          .get(Uri.parse('$base/login'))
          .timeout(const Duration(milliseconds: 1200));
      return looksLikeCrmApi(res.body) ? base : null;
    } catch (_) {
      return null;
    }
  }

  /// Scans the phone's Wi-Fi subnet(s) for the API; returns its base URL
  /// (`http://<ip>:<port>/mobile_api`) or null when nothing answers.
  static Future<String?> find({String port = '8080'}) async {
    final hosts = <String>{};
    try {
      for (final iface
          in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in iface.addresses) {
          if (isLanAddress(iface.name, a.address)) {
            hosts.addAll(subnetHosts(a.address));
          }
        }
      }
    } catch (_) {
      return null;
    }
    final list = hosts.toList();
    const batch = 64;
    for (var i = 0; i < list.length; i += batch) {
      final found = await Future.wait(
          list.skip(i).take(batch).map((h) => _probe(h, port)));
      final hit = found.whereType<String>();
      if (hit.isNotEmpty) return hit.first;
    }
    return null;
  }
}
