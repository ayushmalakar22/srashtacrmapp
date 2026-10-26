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

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return 'http://$_lanHost:$_dockerPort/mobile_api';
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
}
