import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'server_finder.dart';
import 'token_store.dart';

class ApiService {
  // Override per run: flutter run --dart-define=API_BASE_URL=http://<lan-ip>:8080/mobile_api
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  // Mac's Bonjour/mDNS hostname instead of a raw LAN IP, so the app keeps
  // working even if the Mac's IP changes (new Wi-Fi, router restart, etc.).
  // Find it with `scutil --get LocalHostName` on the Mac. Only resolves on
  // the same local network, and a few Android ROMs don't support mDNS
  // hostname resolution - if the app can't connect, fall back to the LAN
  // IP via --dart-define=API_BASE_URL=http://<ip>:8080/mobile_api.
  static const String _lanHost = 'macmini9s-Mac-mini.local';

  // Backend now always runs via Docker (docker compose up, see srashtacrm/
  // DOCKER.md), which publishes the app on port 8080 - not the old 8000
  // bare-metal "php -S" port.
  static const String _dockerPort = '8080';

  // Address chosen in the app (login screen > Server). Wins over everything
  // else, so it survives rebuilds / `flutter run` without --dart-define.
  static String? _savedBaseUrl;

  static String get defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return 'http://$_lanHost:$_dockerPort/mobile_api';
  }

  static String get baseUrl => _savedBaseUrl ?? defaultBaseUrl;

  static Future<void> loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('server_url');
    _savedBaseUrl = (saved == null || saved.isEmpty) ? null : saved;
    // Check in the background so the app opens at once; calls that fail
    // meanwhile join this same search.
    unawaited(rediscover(force: true));
  }

  static Future<bool>? _finding;
  static DateTime? _lastSearch;

  /// The server did not answer: look for it again (saved address, default
  /// hostname, then a scan of the phone's Wi-Fi network) and remember what
  /// works. True when the address changed, so the failed call can be retried.
  /// A search at most every 20 s unless [force]; calls share one search.
  static Future<bool> rediscover({bool force = false}) {
    final running = _finding;
    if (running != null) return running;
    final last = _lastSearch;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 20)) {
      return Future.value(false);
    }
    _lastSearch = DateTime.now();
    return _finding = _rediscover().whenComplete(() => _finding = null);
  }

  static Future<bool> _rediscover() async {
    final old = baseUrl;
    if (await _reachable(old)) return false;
    final prefs = await SharedPreferences.getInstance();
    if (old != defaultBaseUrl && await _reachable(defaultBaseUrl)) {
      await prefs.remove('server_url');
      _savedBaseUrl = null;
      return true;
    }
    final found = await ServerFinder.find();
    if (found == null || found == old) return false;
    await prefs.setString('server_url', found);
    _savedBaseUrl = found;
    return true;
  }

  static Future<bool> _reachable(String url) async {
    try {
      await http
          .get(Uri.parse('$url/login'))
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// "192.168.0.197:8080", "http://host:8080" or the full ".../mobile_api" URL
  /// -> full API base URL. Null when the input is empty.
  static String? normalizeServerUrl(String input) {
    var u = input.trim();
    if (u.isEmpty) return null;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    u = u.replaceAll(RegExp(r'/+$'), '');
    if (!u.endsWith('/mobile_api')) u = '$u/mobile_api';
    return u;
  }

  /// Saves the address; an empty value goes back to the default.
  static Future<void> setServerUrl(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final url = normalizeServerUrl(input);
    if (url == null) {
      await prefs.remove('server_url');
      _savedBaseUrl = null;
    } else {
      await prefs.setString('server_url', url);
      _savedBaseUrl = url;
    }
  }

  /// Null when [url] answers like the CRM API, otherwise a short reason.
  static Future<String?> testServer(String url) async {
    try {
      final res = await http
          .get(Uri.parse('$url/login'))
          .timeout(const Duration(seconds: 6));
      final body = jsonDecode(res.body);
      if (body is Map && body.containsKey('status')) return null;
      return 'Reached a server, but it is not the CRM API';
    } on FormatException {
      return 'Reached a server, but it is not the CRM API';
    } catch (_) {
      return 'Cannot reach the server. Check the address and that you are on the same Wi-Fi.';
    }
  }

  // Every API call goes through these so a dead server fails after
  // [_timeout] instead of hanging, an expiring login is renewed quietly, and
  // a session the server no longer accepts signs the user out.
  static const Duration _timeout = Duration(seconds: 15);

  /// Set by AuthProvider; called when the server has ended the session
  /// (refresh token expired, revoked, password changed...).
  static void Function()? onUnauthorized;

  // A dead address fails after 5 s (not the OS default) so the search for
  // the server's new address can start quickly.
  static final http.Client _client =
      IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 5));

  static bool _isUnreachable(Object e) =>
      e is TimeoutException ||
      e is SocketException ||
      e is http.ClientException;

  /// Runs [call]; if the server cannot be reached, searches for its new
  /// address and repeats the call once there. Safe for POSTs too: the retry
  /// only happens when the address changed, i.e. the first try never arrived.
  static Future<http.Response> _attempt(
      Uri url, Future<http.Response> Function(Uri url) call) async {
    final base = baseUrl;
    try {
      return await call(url).timeout(_timeout);
    } catch (e) {
      if (!_isUnreachable(e) || !await rediscover()) rethrow;
      final text = url.toString();
      if (!text.startsWith(base)) rethrow;
      return call(Uri.parse(text.replaceFirst(base, baseUrl)))
          .timeout(_timeout);
    }
  }

  /// One API call. A 401 means the access token ran out: renew it with the
  /// refresh token and repeat the call once. Only when the server refuses the
  /// renewal too is the user signed out - being offline never logs anyone out.
  static Future<http.Response> _send(
    Uri url,
    Map<String, String>? headers,
    Future<http.Response> Function(Uri url, Map<String, String>? headers) call,
  ) async {
    final res = await _attempt(url, (u) => call(u, headers));
    if (res.statusCode != 401 || headers?['Authorization'] == null) return res;

    final renewed = await refreshSession(); // throws when unreachable
    if (renewed) {
      final fresh = {
        ...headers!,
        'Authorization': 'Bearer ${await TokenStore.access}',
      };
      final again = await _attempt(url, (u) => call(u, fresh));
      if (again.statusCode != 401) return again;
    }
    onUnauthorized?.call();
    return res;
  }

  static Future<http.Response> _get(Uri url, {Map<String, String>? headers}) =>
      _send(url, headers, (u, h) => _client.get(u, headers: h));

  static Future<http.Response> _post(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _send(url, headers, (u, h) => _client.post(u, headers: h, body: body));

  // --- SESSION ---
  static Future<bool>? _refreshing;

  /// Swaps the refresh token for a new access + refresh token. True when
  /// renewed, false when the server refused (session over). Throws when the
  /// server cannot be reached or errors, so the caller keeps the session.
  /// Concurrent callers share one request (refresh tokens are single use).
  static Future<bool> refreshSession() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  static Future<bool> _doRefresh() async {
    final refresh = await TokenStore.refresh;
    if (refresh == null) return false;
    final res = await _attempt(
      Uri.parse('$baseUrl/refresh'),
      (u) => _client.post(u,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refresh})),
    );
    if (res.statusCode == 401) {
      await TokenStore.clear();
      return false;
    }
    final body = res.statusCode == 200 ? jsonDecode(res.body) : null;
    final data = body is Map ? body['data'] : null;
    if (body is Map && body['status'] == true && data is Map) {
      await TokenStore.save(
          access: data['token'], refresh: data['refresh_token']);
      return true;
    }
    throw http.ClientException(
        'Could not renew the session (${res.statusCode})');
  }

  /// Renews the access token ahead of time when it is about to run out, so
  /// requests do not need a failed first try.
  static Future<void> _renewIfExpiring() async {
    if (!await TokenStore.hasSession) return;
    if (!TokenStore.needsRefresh(await TokenStore.access)) return;
    try {
      await refreshSession();
    } catch (_) {} // offline: the request itself reports it
  }

  static Future<Map<String, String>> _getHeaders() async {
    await _renewIfExpiring();
    final token = await TokenStore.access;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Public accessor for auth headers (used by screens that need direct HTTP calls)
  static Future<Map<String, String>> getAuthHeaders() async {
    return _getHeaders();
  }

  /// A current access token (renewed first when it is about to expire).
  static Future<String?> getToken() async {
    await _renewIfExpiring();
    return TokenStore.access;
  }

  /// Ends this device's session on the server (best effort), then forgets
  /// the tokens here.
  static Future<void> endSession() async {
    final refresh = await TokenStore.refresh;
    final access = await TokenStore.access;
    await TokenStore.clear();
    if (refresh == null) return;
    try {
      await _client
          .post(Uri.parse('$baseUrl/logout'),
              headers: {
                'Content-Type': 'application/json',
                if (access != null) 'Authorization': 'Bearer $access',
              },
              body: jsonEncode({'refresh_token': refresh}))
          .timeout(const Duration(seconds: 5));
    } catch (_) {} // offline: the refresh token simply expires on its own
  }

  // --- AUTHENTICATION ---
  static Future<Map<String, dynamic>> getPermissions() async {
    final response = await _get(
      Uri.parse('$baseUrl/permissions'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await _post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final json = jsonDecode(response.body);
    final data = json is Map ? json['data'] : null;
    if (json is Map && json['status'] == true && data is Map) {
      await TokenStore.save(
          access: data['token'], refresh: data['refresh_token']);
    }
    return json;
  }

  /// Full address of a file the server hosts (e.g. a profile photo), built on
  /// the current server address so it follows the server when its IP changes.
  static String fileUrl(String path) {
    final origin = baseUrl.replaceFirst(RegExp(r'/mobile_api/?$'), '');
    return '$origin/${path.replaceFirst(RegExp(r'^/+'), '')}';
  }

  // --- MY PROFILE ---
  static Future<Map<String, dynamic>> getProfile() async {
    final response =
        await _get(Uri.parse('$baseUrl/profile'), headers: await _getHeaders());
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> data) async {
    final response = await _post(
      Uri.parse('$baseUrl/update_profile'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  /// Uploads [filePath] (a JPG or PNG) as the staff photo.
  static Future<Map<String, dynamic>> uploadProfileImage(
      String filePath) async {
    final headers = await _getHeaders();
    headers.remove('Content-Type'); // multipart sets its own
    final request = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl/profile_image'))
      ..headers.addAll(headers)
      ..files.add(await http.MultipartFile.fromPath('profile_image', filePath));
    final res = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 60)));
    if (res.statusCode == 401) onUnauthorized?.call();
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> removeProfileImage() async {
    final response = await _post(Uri.parse('$baseUrl/remove_profile_image'),
        headers: await _getHeaders());
    return jsonDecode(response.body);
  }

  /// Other devices are signed out by the server; this one gets fresh tokens.
  static Future<Map<String, dynamic>> changePassword(
      String oldPassword, String newPassword) async {
    final response = await _post(
      Uri.parse('$baseUrl/change_password'),
      headers: await _getHeaders(),
      body: jsonEncode(
          {'old_password': oldPassword, 'new_password': newPassword}),
    );
    final json = jsonDecode(response.body);
    final data = json is Map ? json['data'] : null;
    if (json is Map && json['status'] == true && data is Map) {
      await TokenStore.save(
          access: data['token'], refresh: data['refresh_token']);
    }
    return json;
  }

  // --- DASHBOARD ---
  static Future<Map<String, dynamic>> getDashboardStats(
      {String? currency}) async {
    final headers = await _getHeaders();
    final q = currency == null ? '' : '?currency=$currency';
    final response =
        await _get(Uri.parse('$baseUrl/dashboard$q'), headers: headers);
    return jsonDecode(response.body);
  }

  // --- CUSTOMERS ---
  /// One page of customers; the API answers `{data, total}`. [status] is
  /// '1' (active) or '0' (inactive).
  static Future<Map<String, dynamic>> getCustomers({
    int limit = 30,
    int offset = 0,
    String search = '',
    String? status,
    String? group,
    String? sort,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/customers').replace(queryParameters: {
      if (group != null) 'group': group,
      if (sort != null) 'sort': sort,
      'limit': '$limit',
      'offset': '$offset',
      if (search.isNotEmpty) 'search': search,
      if (status != null) 'status': status,
    });
    final response = await _get(uri, headers: headers);
    return jsonDecode(response.body);
  }

  /// Customers for the invoice/estimate customer picker (address + currency
  /// included). With [id] just that customer, even if inactive.
  static Future<Map<String, dynamic>> getCustomerOptions({
    int limit = 30,
    int offset = 0,
    String search = '',
    String? id,
  }) async {
    final headers = await _getHeaders();
    final uri =
        Uri.parse('$baseUrl/customer_options').replace(queryParameters: {
      'limit': '$limit',
      'offset': '$offset',
      if (search.isNotEmpty) 'search': search,
      if (id != null) 'id': id,
    });
    final response = await _get(uri, headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCustomersSummary() async {
    final headers = await _getHeaders();
    final response =
        await _get(Uri.parse('$baseUrl/customers_summary'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCustomerFormData() async {
    final headers = await _getHeaders();
    final response =
        await _get(Uri.parse('$baseUrl/customer_form_data'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getStaff() async {
    final headers = await _getHeaders();
    final response = await _get(Uri.parse('$baseUrl/staff'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCustomerAdmins(
      String customerId) async {
    final headers = await _getHeaders();
    final response = await _get(
        Uri.parse('$baseUrl/customer_admins/$customerId'),
        headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> assignCustomerAdmins(
      String customerId, List<String> staffIds) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/customer_admins/$customerId'),
      headers: headers,
      body: jsonEncode({'customer_admins': staffIds}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addCustomer(
      Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/customers'),
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateCustomer(
      Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/customers'), // POST handles update if id is provided
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCustomer(String id) async {
    final headers = await _getHeaders();
    final response = await _get(
      Uri.parse('$baseUrl/customers/$id'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addContact(
      Map<String, dynamic> data) async {
    final headers = await _getHeaders();

    if (data.containsKey('profile_image_path') &&
        data['profile_image_path'] != null) {
      final request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/contacts'));

      // Add all string headers
      headers.forEach((key, value) {
        request.headers[key] = value;
      });

      // Add text fields
      data.forEach((key, value) {
        if (key != 'profile_image_path' && key != 'permissions') {
          request.fields[key] = value.toString();
        }
      });

      // Handle array field manually for PHP
      if (data.containsKey('permissions')) {
        List<int> perms = data['permissions'] as List<int>;
        for (int i = 0; i < perms.length; i++) {
          request.fields['permissions[$i]'] = perms[i].toString();
        }
      }

      // Add image file
      request.files.add(await http.MultipartFile.fromPath(
          'profile_image', data['profile_image_path']));

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body);
    } else {
      final response = await _post(
        Uri.parse('$baseUrl/contacts'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    }
  }

  static Future<Map<String, dynamic>> getContacts(String customerId) async {
    final headers = await _getHeaders();
    final response = await _get(
      Uri.parse('$baseUrl/contacts/$customerId'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateContact(
      Map<String, dynamic> data) async {
    // We can reuse the same logic as addContact because the backend handles both via POST
    return addContact(data);
  }

  static Future<Map<String, dynamic>> deleteContact(String id) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/delete_contact/$id'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> changeContactStatus(
      String id, String status) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/change_contact_status/$id/$status'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteCustomer(String id) async {
    final headers = await _getHeaders();
    final response = await _post(
      // Using POST to map to the new delete_customer method if DELETE method has issues, but we can also use DELETE.
      Uri.parse('$baseUrl/delete_customer/$id'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> changeCustomerStatus(
      String id, String status) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/change_customer_status/$id/$status'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addCustomerGroup(String name) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/customer_groups'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    return jsonDecode(response.body);
  }

  // --- INVOICES ---
  static Future<Map<String, dynamic>> getMasterData() async {
    final headers = await _getHeaders();
    final response =
        await _get(Uri.parse('$baseUrl/master_data'), headers: headers);
    return jsonDecode(response.body);
  }

  /// One page of invoices; the API answers `{data, total}`. [status] is the
  /// effective status (4 = overdue incl. past-due unpaid), [from]/[to] are
  /// `yyyy-MM-dd`.
  static Future<Map<String, dynamic>> getInvoices({
    int limit = 30,
    int offset = 0,
    String search = '',
    String? status,
    String? from,
    String? to,
    String? client,
    String? sort,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/invoices').replace(queryParameters: {
      if (sort != null) 'sort': sort,
      'limit': '$limit',
      'offset': '$offset',
      if (search.isNotEmpty) 'search': search,
      if (status != null) 'status': status,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (client != null) 'client': client,
    });
    final response = await _get(uri, headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getInvoice(String id) async {
    final headers = await _getHeaders();
    final response =
        await _get(Uri.parse('$baseUrl/invoices/$id'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getInvoiceFormData() async {
    final headers = await _getHeaders();
    final response =
        await _get(Uri.parse('$baseUrl/invoice_form_data'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addInvoice(
      Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/invoices'),
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateInvoice(
      String id, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/invoices/$id'),
      headers: headers,
      body: jsonEncode(data),
    );
    try {
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception(
          'API Error: Status ${response.statusCode}, Body: "${response.body}"');
    }
  }

  static Future<Map<String, dynamic>> deleteInvoice(String id) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/delete_invoice/$id'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  // --- PAYMENTS ---
  static Future<Map<String, dynamic>> getInvoicePayments(
      String invoiceId) async {
    final headers = await _getHeaders();
    final response = await _get(
        Uri.parse('$baseUrl/invoice_payments/$invoiceId'),
        headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addPayment(
      String invoiceId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/add_payment/$invoiceId'),
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  // --- ITEMS ---
  /// One page of items: `{data: {items, taxes, currency_symbol}, total}`.
  static Future<Map<String, dynamic>> getItems({
    int limit = 30,
    int offset = 0,
    String search = '',
    String? id, // just this item
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/items').replace(queryParameters: {
      'limit': '$limit',
      'offset': '$offset',
      if (id != null) 'id': id,
      if (search.isNotEmpty) 'search': search,
    });
    final response = await _get(uri, headers: headers);
    return jsonDecode(response.body);
  }

  /// Creates the item, or updates it when [data] has an `id`.
  static Future<Map<String, dynamic>> saveItem(
      Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/items'),
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteItem(String id) async {
    final headers = await _getHeaders();
    final response =
        await _post(Uri.parse('$baseUrl/delete_item/$id'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deletePayment(String paymentId) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/delete_payment/$paymentId'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  // --- SEND ---
  static Future<Map<String, dynamic>> sendInvoice(String invoiceId) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/send_invoice/$invoiceId'),
      headers: headers,
      body: jsonEncode({}),
    );
    return jsonDecode(response.body);
  }

  // --- PENDING LEDGER ---
  /// Pending money: totals for everyone plus one page of customers
  /// (`data.customers`, `total` = customers matching [search]).
  static Future<Map<String, dynamic>> getPending({
    String? currency,
    int limit = 30,
    int offset = 0,
    String search = '',
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/pending').replace(queryParameters: {
      'limit': '$limit',
      'offset': '$offset',
      if (currency != null) 'currency': currency,
      if (search.isNotEmpty) 'search': search,
    });
    final response = await _get(uri, headers: headers);
    return jsonDecode(response.body);
  }

  // --- ESTIMATES ---
  /// One page of estimates; same query options as [getInvoices].
  static Future<Map<String, dynamic>> getEstimates({
    int limit = 30,
    int offset = 0,
    String search = '',
    String? status,
    String? from,
    String? to,
    String? client,
    String? sort,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/estimates').replace(queryParameters: {
      if (sort != null) 'sort': sort,
      'limit': '$limit',
      'offset': '$offset',
      if (search.isNotEmpty) 'search': search,
      if (status != null) 'status': status,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (client != null) 'client': client,
    });
    final response = await _get(uri, headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getEstimate(String id) async {
    final headers = await _getHeaders();
    final response =
        await _get(Uri.parse('$baseUrl/estimates/$id'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> convertEstimate(String id,
      {bool draft = false}) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/convert_estimate/$id'),
      headers: headers,
      body: jsonEncode({'save_as_draft': draft}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> setEstimateStatus(
      String id, int status) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/estimate_status/$id/$status'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addEstimate(
      Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/estimates'),
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateEstimate(
      String id, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/estimates/$id'),
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteEstimate(String id) async {
    final headers = await _getHeaders();
    final response = await _post(
      Uri.parse('$baseUrl/delete_estimate/$id'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }
}
