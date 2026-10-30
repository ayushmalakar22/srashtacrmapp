import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  String _userName = '';
  Map<String, dynamic> _permissions = {};

  AuthProvider() {
    // Expired/invalid token: the API answers 401 -> back to the login screen.
    ApiService.onUnauthorized = () {
      if (_isAuthenticated) logout();
    };
  }

  bool get isAuthenticated => _isAuthenticated;
  String get userName => _userName;

  bool get canCreateCustomer => _permissions['customers']?['create'] == true;
  bool get canEditCustomer => _permissions['customers']?['edit'] == true;
  bool get canDeleteCustomer => _permissions['customers']?['delete'] == true;

  bool get canViewItems => _permissions['items']?['view'] == true;
  bool get canCreateItem => _permissions['items']?['create'] == true;
  bool get canEditItem => _permissions['items']?['edit'] == true;
  bool get canDeleteItem => _permissions['items']?['delete'] == true;

  bool get canCreateInvoice => _permissions['invoices']?['create'] == true;
  bool get canEditInvoice => _permissions['invoices']?['edit'] == true;
  bool get canDeleteInvoice => _permissions['invoices']?['delete'] == true;

  Future<void> fetchPermissions() async {
    if (!_isAuthenticated) return;
    try {
      final response = await ApiService.getPermissions();
      if (response["status"] == true && response["data"] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("user_permissions", jsonEncode(response["data"]));
        _permissions = response["data"];
        notifyListeners();
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token != null && token.isNotEmpty) {
      _isAuthenticated = true;
      _userName = prefs.getString('user_name') ?? 'Staff';
      final permsString = prefs.getString('user_permissions');
      if (permsString != null) {
        try {
          _permissions = jsonDecode(permsString);
        } catch (e) {
          _permissions = {};
        }
      }
    } else {
      _isAuthenticated = false;
    }
    notifyListeners();
    if (_isAuthenticated) {
      fetchPermissions();
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await ApiService.login(email, password);

      if (response['status'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', response['data']['token']);
        await prefs.setString('user_name', response['data']['user']['name']);

        if (response['data']['user']['permissions'] != null) {
          await prefs.setString('user_permissions',
              jsonEncode(response['data']['user']['permissions']));
          _permissions = response['data']['user']['permissions'];
        }

        _isAuthenticated = true;
        _userName = response['data']['user']['name'];
        notifyListeners();
        return {'success': true};
      } else {
        return {'success': false, 'message': response['message']};
      }
    } catch (e) {
      return {
        'success': false,
        'message':
            'Cannot reach the server. Tap "Server" below to check the address.'
      };
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_name');
    await prefs.remove('user_permissions');
    _isAuthenticated = false;
    _permissions = {};
    notifyListeners();
  }
}
