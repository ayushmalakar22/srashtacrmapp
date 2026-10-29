import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
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

  /// Get just the raw token string
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // --- AUTHENTICATION ---
  static Future<Map<String, dynamic>> getPermissions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/permissions'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  // --- DASHBOARD ---
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final headers = await _getHeaders();
    final response =
        await http.get(Uri.parse('$baseUrl/dashboard'), headers: headers);
    return jsonDecode(response.body);
  }

  // --- CUSTOMERS ---
  static Future<Map<String, dynamic>> getCustomers({String search = ''}) async {
    final headers = await _getHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/customers?search=$search'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCustomersSummary() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/customers_summary'),
        headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCustomerFormData() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/customer_form_data'),
        headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getStaff() async {
    final headers = await _getHeaders();
    final response =
        await http.get(Uri.parse('$baseUrl/staff'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCustomerAdmins(
      String customerId) async {
    final headers = await _getHeaders();
    final response = await http.get(
        Uri.parse('$baseUrl/customer_admins/$customerId'),
        headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> assignCustomerAdmins(
      String customerId, List<String> staffIds) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/customer_admins/$customerId'),
      headers: headers,
      body: jsonEncode({'customer_admins': staffIds}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addCustomer(
      Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/customers'),
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateCustomer(
      Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/customers'), // POST handles update if id is provided
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCustomer(String id) async {
    final headers = await _getHeaders();
    final response = await http.get(
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

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body);
    } else {
      final response = await http.post(
        Uri.parse('$baseUrl/contacts'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    }
  }

  static Future<Map<String, dynamic>> getContacts(String customerId) async {
    final headers = await _getHeaders();
    final response = await http.get(
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
    final response = await http.post(
      Uri.parse('$baseUrl/delete_contact/$id'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> changeContactStatus(
      String id, String status) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/change_contact_status/$id/$status'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteCustomer(String id) async {
    final headers = await _getHeaders();
    final response = await http.post(
      // Using POST to map to the new delete_customer method if DELETE method has issues, but we can also use DELETE.
      Uri.parse('$baseUrl/delete_customer/$id'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> changeCustomerStatus(
      String id, String status) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/change_customer_status/$id/$status'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addCustomerGroup(String name) async {
    final headers = await _getHeaders();
    final response = await http.post(
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
        await http.get(Uri.parse('$baseUrl/master_data'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getInvoices(
      {int limit = 1000, int offset = 0}) async {
    final headers = await _getHeaders();
    final response = await http.get(
        Uri.parse('$baseUrl/invoices?limit=$limit&offset=$offset'),
        headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getInvoice(String id) async {
    final headers = await _getHeaders();
    final response =
        await http.get(Uri.parse('$baseUrl/invoices/$id'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getInvoiceFormData() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/invoice_form_data'),
        headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addInvoice(
      Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/invoices'),
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateInvoice(
      String id, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
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
    final response = await http.post(
      Uri.parse('$baseUrl/delete_invoice/$id'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  // --- PAYMENTS ---
  static Future<Map<String, dynamic>> getInvoicePayments(String invoiceId) async {
    final headers = await _getHeaders();
    final response = await http.get(
        Uri.parse('$baseUrl/invoice_payments/$invoiceId'),
        headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addPayment(
      String invoiceId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/add_payment/$invoiceId'),
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deletePayment(String paymentId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/delete_payment/$paymentId'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  // --- SEND ---
  static Future<Map<String, dynamic>> sendInvoice(String invoiceId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/send_invoice/$invoiceId'),
      headers: headers,
      body: jsonEncode({}),
    );
    return jsonDecode(response.body);
  }

  // --- PENDING LEDGER ---
  static Future<Map<String, dynamic>> getPending() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/pending'), headers: headers);
    return jsonDecode(response.body);
  }

  // --- ESTIMATES ---
  static Future<Map<String, dynamic>> getEstimates(
      {int limit = 1000, int offset = 0}) async {
    final headers = await _getHeaders();
    final response = await http.get(
        Uri.parse('$baseUrl/estimates?limit=$limit&offset=$offset'),
        headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getEstimate(String id) async {
    final headers = await _getHeaders();
    final response =
        await http.get(Uri.parse('$baseUrl/estimates/$id'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> convertEstimate(String id,
      {bool draft = false}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/convert_estimate/$id'),
      headers: headers,
      body: jsonEncode({'save_as_draft': draft}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> setEstimateStatus(
      String id, int status) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/estimate_status/$id/$status'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addEstimate(
      Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/estimates'),
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateEstimate(
      String id, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/estimates/$id'),
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteEstimate(String id) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/delete_estimate/$id'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }
}
