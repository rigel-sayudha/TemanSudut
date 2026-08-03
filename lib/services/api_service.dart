import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/table_model.dart';
import '../models/raw_material.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  // === URL SERVER ===
  static const String baseUrl = 'http://100.67.41.122:8000/api';
  // ========================================
  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.headers['Authorization'] == null) {
          final prefs = await SharedPreferences.getInstance();
          
          final token = prefs.getString('auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
    ));
  }

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearToken() {
    _dio.options.headers.remove('Authorization');
  }

  String getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';

    if (path.startsWith('http')) {
      final storagePrefix = '/storage/';
      int index = path.indexOf(storagePrefix);
      if (index != -1) {
        return '$baseUrl/images/${path.substring(index + storagePrefix.length)}';
      }
      return path;
    }

    return '$baseUrl/images/$path';
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await _dio.post('/login', data: {
        'email': email,
        'password': password,
      });
      print('Login Success Response: ${response.data}');
      return response.data;
    } catch (e) {
      if (e is DioException) {
        print('Failed to login (Dio): ${e.message}');
        print('Response Body: ${e.response?.data}');
      } else {
        print('Failed to login (Unknown): $e');
      }
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/logout');
    } catch (e) {}
  }

  Future<Map<String, dynamic>?> getUser() async {
    try {
      final response = await _dio.get('/user');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> updateProfile(String name, String email) async {
    try {
      final response = await _dio.put('/profile', data: {'name': name, 'email': email});
      return {'success': true, 'user': response.data['user']};
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal memperbarui profil.';
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan.'};
    }
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    try {
      await _dio.put('/profile/password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPassword,
      });
      return {'success': true};
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal mengubah password.';
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan.'};
    }
  }

  Future<Map<String, dynamic>?> getPermissions() async {
    try {
      final response = await _dio.get('/permissions');
      print('Permissions Response: ${response.data}');
      return response.data;
    } catch (e) {
      print('Failed to get permissions: $e');
      return null;
    }
  }

  Future<List<dynamic>> getHistory(String filter) async {
    try {
      final response = await _dio.get('/transactions/history', queryParameters: {'filter': filter});
      return response.data;
    } catch (e) {
      print('Failed to get history: $e');
      return [];
    }
  }

  Future<List<dynamic>> getActiveOrders() async {
    try {
      final response = await _dio.get('/transactions/active');
      return response.data;
    } catch (e) {
      print('Failed to get active orders: $e');
      return [];
    }
  }

  Future<bool> updateTransactionStatus(int id, String status, {dynamic photo, String? orderType, double? amountReceived, double? changeAmount}) async {
    try {
      Response response;
      if (photo != null) {
        // Read bytes and encode as base64
        final xfile = photo as dynamic;
        final bytes = await xfile.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        response = await _dio.put(
          '/transactions/$id/status',
          data: {
            'kitchen_status': status,
            'completion_photo_base64': base64Image,
            if (orderType != null) 'order_type': orderType,
            if (amountReceived != null) 'amount_received': amountReceived,
            if (changeAmount != null) 'change_amount': changeAmount,
          },
        );
      } else {
        response = await _dio.put(
          '/transactions/$id/status',
          data: {
            'kitchen_status': status,
            'completion_photo_base64': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
            if (orderType != null) 'order_type': orderType,
            if (amountReceived != null) 'amount_received': amountReceived,
            if (changeAmount != null) 'change_amount': changeAmount,
          },
        );
      }

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Update status failed with status code: ${response.statusCode}');
        print('Response data: ${response.data}');
        return false;
      }
    } catch (e) {
      if (e is DioException) {
        print('Dio error updating status: ${e.message}');
        print('Response: ${e.response?.data}');
      } else {
        print('Unknown error updating status: $e');
      }
      return false;
    }
  }

  // ── Saved (Held) Transactions ────────────────────────────────────────────

  Future<Map<String, dynamic>> saveTransaction(Map<String, dynamic> payload) async {
    try {
      print('=== SAVE TRANSACTION REQUEST ===');
      print('Payload: $payload');
      final response = await _dio.post('/transactions/save', data: payload);
      print('=== SAVE TRANSACTION RESPONSE ===');
      print('Status: ${response.statusCode}');
      print('Data: ${response.data}');
      return response.data ?? {'success': false};
    } catch (e) {
      print('=== SAVE TRANSACTION ERROR ===');
      if (e is DioException) {
        print('Status: ${e.response?.statusCode}');
        print('Response data: ${e.response?.data}');
        print('Message: ${e.message}');
      } else {
        print('Error: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<dynamic>> getSavedTransactions() async {
    try {
      final response = await _dio.get('/transactions/saved');
      return response.data ?? [];
    } catch (e) {
      print('Failed to load saved transactions: $e');
      return [];
    }
  }

  Future<bool> deleteSavedTransaction(int id) async {
    try {
      final response = await _dio.delete('/transactions/saved/$id');
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to delete saved transaction: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> activateSavedTransaction(int id, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('/transactions/saved/$id/activate', data: payload);
      return response.data ?? {'success': false};
    } catch (e) {
      if (e is DioException) {
        print('Activate saved error: ${e.response?.data}');
        final data = e.response?.data;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      final response = await _dio.get('/categories');
      List<dynamic> data = response.data;
      return data.map((json) => Category.fromJson(json)).toList();
    } catch (e) {
      print('Failed to load categories: $e');
      return [];
    }  
  }

  Future<List<Product>> getProducts({int? categoryId, String? search}) async {
    try {
      final response = await _dio.get(
        '/products',
        queryParameters: {
          if (categoryId != null) 'category_id': categoryId,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      List<dynamic> data = response.data;
      return data.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      print('Failed to load products: $e');
      return [];
    }
  }

  Future<bool> updateProduct(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/products/$id', data: data);
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to update product: $e');
      return false;
    }
  }

  Future<List<TableModel>> getAvailableTables() async {
    try {
      final response = await _dio.get('/tables/available');
      List<dynamic> data = response.data;
      return data.map((json) => TableModel.fromJson(json)).toList();
    } catch (e) {
      print('Failed to load tables: $e');
      return [];
    }
  }

  /// Returns {'success': true} on success, or {'success': false, 'error': '...', 'details': [...]} on failure
  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> transactionData, {dynamic photo}) async {
    try {
      if (photo != null) {
        final xfile = photo as dynamic;
        final bytes = await xfile.readAsBytes();
        final base64Image = base64Encode(bytes);
        transactionData['completion_photo_base64'] = 'data:image/jpeg;base64,$base64Image';
      }
      final response = await _dio.post('/transactions', data: transactionData);
      return {'success': response.statusCode == 201};
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 422) {
        final data = e.response?.data;
        return {
          'success': false,
          'error': data?['message'] ?? 'Stok bahan baku tidak mencukupi',
          'details': data?['details'] ?? [],
        };
      }
      print('Failed to create transaction: $e');
      return {'success': false, 'error': 'Gagal membuat transaksi'};
    }
  }

  Future<bool> deleteTransaction(int id) async {
    try {
      final response = await _dio.delete('/transactions/$id');
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to delete transaction: $e');
      return false;
    }
  }

  // ---- User Management ----

  Future<List<dynamic>> getUsers() async {
    try {
      final response = await _dio.get('/users');
      return response.data;
    } catch (e) {
      print('Failed to get users: $e');
      return [];
    }
  }

  Future<bool> createUser(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/users', data: data);
      return response.statusCode == 201;
    } catch (e) {
      print('Failed to create user: $e');
      return false;
    }
  }

  Future<bool> updateUser(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/users/$id', data: data);
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to update user: $e');
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      final response = await _dio.delete('/users/$id');
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to delete user: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCurrentShift() async {
    try {
      final response = await _dio.get('/shifts/current');
      if (response.data['status'] == 'success') {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('Failed to get current shift: $e');
      return null;
    }
  }

  Future<bool> openShift(double startingCash) async {
    try {
      final response = await _dio.post(
        '/shifts/open',
        data: {'starting_cash': startingCash},
      );
      return (response.statusCode == 200 || response.statusCode == 201) && response.data['status'] == 'success';
    } catch (e) {
      print('Failed to open shift: $e');
      return false;
    }
  }

  Future<bool> closeShift({double? endingCash}) async {
    try {
      final response = await _dio.post(
        '/shifts/close',
        data: {'ending_cash': endingCash},
      );
      return response.statusCode == 200 && response.data['status'] == 'success';
    } catch (e) {
      print('Failed to close shift: $e');
      return false;
    }
  }

  // ---- Raw Materials ----

  Future<List<RawMaterial>> getRawMaterials() async {
    try {
      final response = await _dio.get('/raw-materials');
      List<dynamic> data = response.data;
      return data.map((json) => RawMaterial.fromJson(json)).toList();
    } catch (e) {
      print('Failed to load raw materials: $e');
      return [];
    }
  }

  Future<bool> updateRawMaterial(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/raw-materials/$id', data: data);
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to update raw material: $e');
      return false;
    }
  }

  // ---- Finance Entries ----

  Future<List<dynamic>> getFinanceEntries({String? type, String? category, String? date, Map<String, String>? dateRange}) async {
    try {
      String? filterParam;
      if (dateRange != null) {
        filterParam = 'date_range:${dateRange['start']},${dateRange['end']}';
      }
      final response = await _dio.get('/finance-entries', queryParameters: {
        if (type != null && type.isNotEmpty) 'type': type,
        if (category != null && category.isNotEmpty) 'category': category,
        if (date != null && date.isNotEmpty) 'date': date,
        if (filterParam != null) 'filter': filterParam,
      });
      return response.data as List;
    } catch (e) {
      print('Failed to get finance entries: $e');
      return [];
    }
  }

  Future<bool> createFinanceEntry(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/finance-entries', data: data);
      return response.statusCode == 201;
    } catch (e) {
      print('Failed to create finance entry: $e');
      return false;
    }
  }

  Future<bool> updateFinanceEntry(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/finance-entries/$id', data: data);
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to update finance entry: $e');
      return false;
    }
  }

  Future<bool> deleteFinanceEntry(int id) async {
    try {
      final response = await _dio.delete('/finance-entries/$id');
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to delete finance entry: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getFinanceSummary(String filter, {String? specificDate, Map<String, String>? dateRange}) async {
    try {
      String effectiveFilter;
      if (dateRange != null) {
        effectiveFilter = 'date_range:${dateRange['start']},${dateRange['end']}';
      } else if (specificDate != null) {
        effectiveFilter = 'date:$specificDate';
      } else {
        effectiveFilter = filter;
      }
      final response = await _dio.get('/finance-entries/summary', queryParameters: {'filter': effectiveFilter});
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Failed to get finance summary: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getFinanceChart(String period) async {
    try {
      final response = await _dio.get('/finance-entries/chart', queryParameters: {'period': period});
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Failed to get finance chart: $e');
      return null;
    }
  }
}

