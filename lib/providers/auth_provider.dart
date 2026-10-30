import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/token_store.dart';

class AuthProvider with ChangeNotifier, WidgetsBindingObserver {
  bool _isAuthenticated = false;
  String _userName = '';
  String _avatarPath = '';
  Map<String, dynamic> _permissions = {};

  AuthProvider() {
    // The server ended the session (refresh token expired or revoked, password
    // changed...) -> back to the login screen with a note why.
    ApiService.onUnauthorized = () {
      if (_isAuthenticated) logout(expired: true);
    };
    WidgetsBinding.instance.addObserver(this);
  }

  /// Back in the app after a while: re-check the session, so an ended one
  /// goes to the login screen now instead of on the next tap.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isAuthenticated) {
      fetchPermissions();
    }
  }

  bool _sessionExpired = false;

  /// True once after a forced sign-out; the login screen shows a message.
  bool takeSessionExpired() {
    final v = _sessionExpired;
    _sessionExpired = false;
    return v;
  }

  bool get isAuthenticated => _isAuthenticated;
  String get userName => _userName;
  String get avatarPath => _avatarPath;

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
    await prefs
        .remove('jwt_token'); // old plain-text login token, no longer used

    if (await TokenStore.hasSession) {
      _isAuthenticated = true;
      _userName = prefs.getString('user_name') ?? 'Staff';
      _avatarPath = prefs.getString('user_avatar') ?? '';
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
        await prefs.setString('user_name', response['data']['user']['name']);

        if (response['data']['user']['permissions'] != null) {
          await prefs.setString('user_permissions',
              jsonEncode(response['data']['user']['permissions']));
          _permissions = response['data']['user']['permissions'];
        }

        _isAuthenticated = true;
        _userName = response['data']['user']['name'];
        await setAvatar(
            response['data']['user']['avatar_path']?.toString() ?? '');
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

  /// Photo changed (or loaded) on the profile screen.
  Future<void> setAvatar(String path) async {
    if (path == _avatarPath) return;
    _avatarPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_avatar', path);
    notifyListeners();
  }

  /// Name changed on the profile screen: keep the menu / greeting in step.
  Future<void> setUserName(String name) async {
    if (name.isEmpty || name == _userName) return;
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    notifyListeners();
  }

  Future<void> logout({bool expired = false}) async {
    _sessionExpired = expired;
    // show the login screen at once; ending the session on the server
    // (best effort) follows in the background
    final ending = ApiService.endSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_avatar');
    _avatarPath = '';
    await prefs.remove('user_permissions');
    _isAuthenticated = false;
    _permissions = {};
    notifyListeners();
    await ending;
  }
}
