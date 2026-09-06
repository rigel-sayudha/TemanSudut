import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isAuthenticated = false;
  String? _token;
  String _role = 'cashier'; // default role
  Map<String, dynamic>? _user;
  Map<String, dynamic> _permissions = {};

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;
  String? get token => _token;
  String get role => _role;
  bool get isOwner => _role == 'owner';
  bool get isCashier => _role == 'cashier';

  bool can(String feature) {
    if (_permissions.containsKey(feature)) {
      return _permissions[feature][_role] == true ||
          _permissions[feature][_role] == 1;
    }
    return false;
  }

  AuthProvider() {
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (_token != null) {
      _apiService.setToken(_token!);
      await fetchUser();
    } else {
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    developer.log('Attempting login for: $email');
    try {
      final response = await _apiService.login(email, password);
      if (response != null && response['access_token'] != null) {
        developer.log('Login success, parsing user data...');
        _token = response['access_token'];
        _user = response['user'];
        _role = response['user']?['role'] ?? 'cashier';
        _isAuthenticated = true;
        developer.log('Set role to: $_role');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);

        _apiService.setToken(_token!);
        developer.log('Fetching permissions...');
        await fetchPermissions();
        developer.log('Ready! Notifying listeners.');
        notifyListeners();
        return true;
      } else {
        developer.log('Login response was null or missing token.');
      }
    } catch (e) {
      developer.log('Login Exception: $e');
    }
    return false;
  }

  Future<void> fetchUser() async {
    try {
      _user = await _apiService.getUser();
      if (_user != null) {
        _isAuthenticated = true;
        _role = _user?['role'] ?? 'cashier';
        await fetchPermissions();
      } else {
        await logout();
      }
      notifyListeners();
    } catch (e) {
      developer.log('Fetch user error: $e');
      await logout();
    }
  }

  Future<void> fetchPermissions() async {
    try {
      final perms = await _apiService.getPermissions();
      if (perms != null) {
        _permissions = perms;
      }
    } catch (e) {
      developer.log('Fetch permissions error: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (e) {
      developer.log('Logout error: $e');
    }
    _token = null;
    _user = null;
    _permissions = {};
    _isAuthenticated = false;
    _apiService.clearToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');

    notifyListeners();
  }
}
