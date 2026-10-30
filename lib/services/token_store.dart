import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Login tokens, kept in the Android Keystore-backed secure storage (never in
/// plain SharedPreferences). The access token is short lived; the refresh
/// token lets the app get a new one without asking for the password again.
class TokenStore {
  static const _storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  static String? _access;
  static String? _refresh;
  static bool _loaded = false;

  static Future<void> _load() async {
    if (_loaded) return;
    try {
      _access = await _storage.read(key: _kAccess);
      _refresh = await _storage.read(key: _kRefresh);
    } catch (_) {
      // unreadable store (e.g. keystore reset): behave as signed out
      _access = _refresh = null;
    }
    _loaded = true;
  }

  static Future<String?> get access async {
    await _load();
    return _access;
  }

  static Future<String?> get refresh async {
    await _load();
    return _refresh;
  }

  static Future<bool> get hasSession async => (await refresh) != null;

  static Future<void> save({required String access, String? refresh}) async {
    await _load();
    _access = access;
    await _storage.write(key: _kAccess, value: access);
    if (refresh != null) {
      _refresh = refresh;
      await _storage.write(key: _kRefresh, value: refresh);
    }
  }

  static Future<void> clear() async {
    _access = _refresh = null;
    _loaded = true;
    try {
      await _storage.delete(key: _kAccess);
      await _storage.delete(key: _kRefresh);
    } catch (_) {}
  }

  /// Expiry time (`exp` claim) of a JWT, or null when it cannot be read.
  static DateTime? expiryOf(String? jwt) {
    final parts = jwt?.split('.');
    if (parts == null || parts.length != 3) return null;
    try {
      final map = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = map is Map ? map['exp'] : null;
      return exp is num
          ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000)
          : null;
    } catch (_) {
      return null;
    }
  }

  /// True when [jwt] is missing, unreadable or ends within [margin].
  static bool needsRefresh(String? jwt,
      {Duration margin = const Duration(seconds: 60), DateTime? now}) {
    final exp = expiryOf(jwt);
    if (exp == null) return true;
    return exp.isBefore((now ?? DateTime.now()).add(margin));
  }
}
