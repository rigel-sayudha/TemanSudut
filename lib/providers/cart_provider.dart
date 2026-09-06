import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/table_model.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class CartItem {
  final Product product;
  int quantity;
  String? notes;
  double extraCharge;
  String? extraChargeLabel;
  bool isFree;
  bool useCup;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.notes,
    this.extraCharge = 0,
    this.extraChargeLabel,
    this.isFree = false,
    this.useCup = true,
  });

  double get subtotal => isFree ? 0 : (product.price + extraCharge) * quantity;

  bool get isDrink {
    final catName = product.category?.name.toLowerCase() ?? '';
    return catName.contains('kopi') ||
        catName.contains('coffee') ||
        catName.contains('non-kopi') ||
        catName.contains('non coffee') ||
        catName.contains('milk');
  }
}

class CartProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Product> _availableProducts = [];
  List<Product> get availableProducts => _availableProducts;

  List<Category> _categories = [];
  List<Category> get categories => _categories;

  Category? _selectedCategory;
  Category? get selectedCategory => _selectedCategory;

  final List<CartItem> _items = [];
  String _orderType = 'dine_in';
  TableModel? _selectedTable;
  String? _customerName;
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _isShiftOpen = false;
  bool _isLoadingShift = true;
  Map<String, dynamic>? _currentShift;

  CartProvider() {
    _fetchProducts();
    checkShiftStatus();
  }

  Future<void> checkShiftStatus() async {
    _isLoadingShift = true;
    notifyListeners();
    _currentShift = await _apiService.getCurrentShift();
    _isShiftOpen = _currentShift != null;
    _isLoadingShift = false;
    notifyListeners();
  }

  Future<bool> openShift(double amount) async {
    bool success = await _apiService.openShift(amount);
    if (success) {
      await checkShiftStatus();
    }
    return success;
  }

  Future<bool> closeShift(double amount) async {
    bool success = await _apiService.closeShift(endingCash: amount);
    if (success) {
      _isShiftOpen = false;
      _currentShift = null;
      _items.clear();
      notifyListeners();
    }
    return success;
  }

  bool get isShiftOpen => _isShiftOpen;
  bool get isLoadingShift => _isLoadingShift;
  Map<String, dynamic>? get currentShift => _currentShift;

  // All products
  List<Product> _allProducts = [];

  Future<void> filterByCategory(Category? category) async {
    _selectedCategory = category;
    _applyFilter();
  }

  Future<void> setSearchQuery(String query) async {
    _searchQuery = query;
    _applyFilter();
  }

  // Apply category + search filter locally (no network call)
  void _applyFilter() {
    List<Product> result = _allProducts;
    if (_selectedCategory != null) {
      result = result
          .where((p) => p.categoryId == _selectedCategory!.id)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((p) => p.name.toLowerCase().contains(q)).toList();
    }
    _availableProducts = result;
    notifyListeners();
  }

  /// Initial load: use cache if valid, otherwise fetch and store in cache.
  Future<void> _fetchProducts() async {
    // -- Categories --
    if (_categories.isEmpty) {
      final cachedCats = await CacheService.getCategories();
      if (cachedCats != null) {
        _categories = cachedCats.map((j) => Category.fromJson(j)).toList();
      } else {
        _categories = await _apiService.getCategories();
        await CacheService.saveCategories(
          _categories.map((c) => c.toJson()).toList(),
        );
      }
    }

    // -- Products --
    if (_allProducts.isEmpty) {
      final cachedProds = await CacheService.getProducts();
      if (cachedProds != null) {
        _allProducts = cachedProds.map((j) => Product.fromJson(j)).toList();
      } else {
        _allProducts = await _apiService.getProducts();
        await CacheService.saveProducts(
          _allProducts.map((p) => p.toJson()).toList(),
        );
      }
    }

    _applyFilter();
  }

  Future<void> refreshProducts() async {
    await CacheService.invalidateAll();
    _allProducts = [];
    _categories = [];
    await _fetchProducts();
  }

  List<CartItem> get items => _items;
  String get orderType => _orderType;
  TableModel? get selectedTable => _selectedTable;
  String? get customerName => _customerName;

  double get subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get tax => 0;
  double get total => subtotal;

  void setOrderType(String type) {
    _orderType = type;
    if (type == 'take_away') {
      _selectedTable = null;
    }
    notifyListeners();
  }

  void setSelectedTable(TableModel? table) {
    _selectedTable = table;
    notifyListeners();
  }

  void setCustomerName(String? name) {
    _customerName = name;
    notifyListeners();
  }

  void addToCart(Product product, {String? notes}) {
    int index = _items.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.notes == notes &&
          item.extraCharge == 0 &&
          item.isFree == false,
    );
    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(product: product, notes: notes));
    }
    notifyListeners();
  }

  void removeFromCart(CartItem cartItem) {
    _items.remove(cartItem);
    notifyListeners();
  }

  void updateQuantity(CartItem cartItem, int quantity) {
    if (quantity <= 0) {
      removeFromCart(cartItem);
    } else {
      cartItem.quantity = quantity;
      notifyListeners();
    }
  }

  void updateItemNote(CartItem cartItem, String newNote) {
    cartItem.notes = newNote;
    notifyListeners();
  }

  void toggleFreeCup(CartItem cartItem) {
    cartItem.isFree = !cartItem.isFree;
    notifyListeners();
  }

  void updateExtraCharge(CartItem cartItem, double charge, {String? label}) {
    cartItem.extraCharge = charge;
    cartItem.extraChargeLabel = label;
    notifyListeners();
  }

  void splitExtraCharge(CartItem originalItem, double charge, String? label) {
    if (originalItem.quantity > 1) {
      originalItem.quantity -= 1;
      final newItem = CartItem(
        product: originalItem.product,
        quantity: 1,
        notes: originalItem.notes,
        extraCharge: charge,
        extraChargeLabel: label,
        isFree: originalItem.isFree,
        useCup: originalItem.useCup,
      );
      _items.add(newItem);
      notifyListeners();
    }
  }

  void toggleUseCup(CartItem cartItem) {
    cartItem.useCup = !cartItem.useCup;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _selectedTable = null;
    _customerName = null;
    _orderType = 'dine_in';
    notifyListeners();
  }

  /// Save cart as a held/draft transaction (no stock deduction).
  Future<bool> saveTransaction(String customerName, {String? orderType}) async {
    if (_items.isEmpty) return false;
    final payload = {
      'customer_name': customerName.isNotEmpty ? customerName : 'Tamu',
      'order_type': orderType ?? _orderType,
      'items': _items.map((item) {
        double extraCharge = item.extraCharge;
        String? notes = item.notes;
        if (item.isFree) {
          extraCharge = -(item.product.price);
          final freeInfo = '[FREE CUP / GRATIS]';
          notes = notes != null && notes.isNotEmpty
              ? '$notes | $freeInfo'
              : freeInfo;
        }
        return {
          'product_id': item.product.id,
          'quantity': item.quantity,
          'notes': notes,
          'extra_charge': extraCharge,
          'use_cup': item.isDrink ? item.useCup : null,
        };
      }).toList(),
    };

    final result = await _apiService.saveTransaction(payload);
    if (result['success'] == true) {
      clearCart();
      return true;
    }
    return false;
  }

  String? _lastCheckoutError;
  String? get lastCheckoutError => _lastCheckoutError;

  Future<bool> checkout(
    String paymentMethod, {
    double? amountReceived,
    double? changeAmount,
    dynamic photo,
  }) async {
    if (_items.isEmpty) return false;
    _lastCheckoutError = null;
    String finalOrderType = _orderType;
    if (_orderType == 'dine_in' && _selectedTable == null) {
      finalOrderType = 'take_away';
    }

    Map<String, dynamic> payload = {
      'payment_method': paymentMethod,
      'order_type': finalOrderType,
      'table_id': _selectedTable?.id,
      'customer_name': _customerName,
      'amount_received': amountReceived,
      'change_amount': changeAmount,
      'items': _items.map((item) {
        String? finalNotes = item.notes;
        if (item.extraCharge > 0) {
          String extraInfo =
              '[Extra: ${item.extraChargeLabel ?? "Tambahan"} +Rp${item.extraCharge.toInt()}]';
          finalNotes = finalNotes != null && finalNotes.isNotEmpty
              ? '$finalNotes | $extraInfo'
              : extraInfo;
        }
        if (item.isFree) {
          String freeInfo = '[FREE CUP / GRATIS]';
          finalNotes = finalNotes != null && finalNotes.isNotEmpty
              ? '$finalNotes | $freeInfo'
              : freeInfo;
        }

        double finalExtraCharge = item.extraCharge;
        if (item.isFree) {
          finalExtraCharge = -(item.product.price);
        }

        return {
          'product_id': item.product.id,
          'quantity': item.quantity,
          'notes': finalNotes,
          'extra_charge': finalExtraCharge,
          'use_cup': item.isDrink ? item.useCup : null,
        };
      }).toList(),
    };

    try {
      final result = await _apiService.createTransaction(payload, photo: photo);
      if (result['success'] == true) {
        clearCart();
        await checkShiftStatus();
        return true;
      } else {
        // Stock shortage or other error
        final details = result['details'];
        if (details != null && details is List && details.isNotEmpty) {
          _lastCheckoutError = details.join('\n');
        } else {
          _lastCheckoutError = result['error'] ?? 'Gagal membuat transaksi';
        }
        notifyListeners();
        return false;
      }
    } catch (e) {
      developer.log('Checkout Error: $e');
      _lastCheckoutError = 'Terjadi kesalahan saat checkout';
      notifyListeners();
      return false;
    }
  }
}
