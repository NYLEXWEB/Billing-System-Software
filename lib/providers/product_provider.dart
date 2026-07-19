import 'package:flutter/material.dart';
import '../data/db_helper.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/analytics_service.dart';

class ProductProvider extends ChangeNotifier {
  final DbHelper _dbHelper = DbHelper();

  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = false;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;

  // Filter states
  String _searchQuery = '';
  int? _selectedCategoryId;

  String get searchQuery => _searchQuery;
  int? get selectedCategoryId => _selectedCategoryId;

  // Setters for filters
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategoryId(int? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategoryId = null;
    notifyListeners();
  }

  // Filtered lists
  List<Product> get filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    return _products.where((product) {
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.barcode.contains(query);
      final matchesCategory = _selectedCategoryId == null || product.categoryId == _selectedCategoryId;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<Product> get lowStockProducts {
    return _products.where((product) => product.isTracked && product.stockQuantity <= product.lowStockThreshold).toList();
  }

  // ==========================================
  // PRODUCT CRUD METHODS
  // ==========================================

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _products = await _dbHelper.getProducts();
    } catch (e) {
      debugPrint("Error loading products: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addProduct(Product product) async {
    try {
      final id = await _dbHelper.insertProduct(product);
      if (id > 0) {
        await loadProducts();
        final catName = _categories.firstWhere(
          (c) => c.id == product.categoryId,
          orElse: () => Category(id: -1, name: 'Uncategorized', description: ''),
        ).name;
        AnalyticsService.logProductCreated(
          productId: id.toString(),
          name: product.name,
          category: catName,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error adding product: $e");
      return false;
    }
  }

  Future<bool> updateProduct(Product product, {String? movementReason}) async {
    try {
      final count = await _dbHelper.updateProduct(product, movementReason: movementReason);
      if (count > 0) {
        await loadProducts();
        AnalyticsService.logProductUpdated(
          productId: product.id?.toString() ?? '',
          name: product.name,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error updating product: $e");
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      final deletedProduct = _products.firstWhere((p) => p.id == id, orElse: () => Product(name: 'Unknown', barcode: '', price: 0));
      final count = await _dbHelper.deleteProduct(id);
      if (count > 0) {
        await loadProducts();
        AnalyticsService.logProductDeleted(
          productId: id.toString(),
          name: deletedProduct.name,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error deleting product: $e");
      return false;
    }
  }

  Future<bool> adjustStock(int productId, int quantity, String type, String reason) async {
    try {
      final id = await _dbHelper.insertStockMovement(productId, quantity, type, reason);
      if (id > 0) {
        await loadProducts();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error adjusting stock: $e");
      return false;
    }
  }

  // ==========================================
  // CATEGORY CRUD METHODS
  // ==========================================

  Future<void> loadCategories() async {
    try {
      _categories = await _dbHelper.getCategories();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading categories: $e");
    }
  }

  Future<bool> addCategory(Category category) async {
    try {
      final id = await _dbHelper.insertCategory(category);
      if (id > 0) {
        await loadCategories();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error adding category: $e");
      return false;
    }
  }

  Future<bool> updateCategory(Category category) async {
    try {
      final count = await _dbHelper.updateCategory(category);
      if (count > 0) {
        await loadCategories();
        await loadProducts(); // Reload products to get updated category names in joins
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error updating category: $e");
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    try {
      final count = await _dbHelper.deleteCategory(id);
      if (count > 0) {
        await loadCategories();
        await loadProducts(); // Reload products since deleted category ID becomes null
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error deleting category: $e");
      return false;
    }
  }
}
