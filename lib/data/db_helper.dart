import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/business.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/stock_movement.dart';
import '../models/printer_settings.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'shop_billing.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Business Table
    await db.execute('''
      CREATE TABLE businesses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL,
        address TEXT NOT NULL,
        gstOrTin TEXT NOT NULL,
        upiId TEXT NOT NULL,
        logoPath TEXT,
        currency TEXT NOT NULL DEFAULT '₹',
        recoveryPasswordHash TEXT,
        backupEmail TEXT,
        lastBackupTime TEXT,
        themeMode TEXT NOT NULL DEFAULT 'system'
      )
    ''');

    // 2. Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        description TEXT NOT NULL
      )
    ''');

    // 3. Products Table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryId INTEGER,
        name TEXT NOT NULL,
        barcode TEXT UNIQUE NOT NULL,
        price REAL NOT NULL,
        costPrice REAL NOT NULL DEFAULT 0.0,
        stockQuantity INTEGER NOT NULL DEFAULT 0,
        lowStockThreshold INTEGER NOT NULL DEFAULT 5,
        isTracked INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // 4. Invoices Table
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceNumber TEXT UNIQUE NOT NULL,
        dateTime TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        taxAmount REAL NOT NULL,
        discountAmount REAL NOT NULL,
        grandTotal REAL NOT NULL,
        paymentMethod TEXT NOT NULL,
        paymentStatus TEXT NOT NULL,
        customerPhone TEXT NOT NULL
      )
    ''');

    // 5. Invoice Items Table
    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceId INTEGER NOT NULL,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (invoiceId) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');

    // 6. Stock Movements Table
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        type TEXT NOT NULL, -- 'IN', 'OUT', 'SET'
        reason TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    // 7. Printer Settings Table
    await db.execute('''
      CREATE TABLE printer_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL, -- 'bluetooth', 'network'
        address TEXT NOT NULL,
        paperWidth INTEGER NOT NULL DEFAULT 58
      )
    ''');
  }

  // ==========================================
  // BUSINESS OPERATIONS
  // ==========================================

  Future<Business?> getBusiness() async {
    final db = await database;
    final maps = await db.query('businesses', limit: 1);
    if (maps.isEmpty) return null;
    return Business.fromMap(maps.first);
  }

  Future<int> insertBusiness(Business business) async {
    final db = await database;
    return await db.insert('businesses', business.toMap());
  }

  Future<int> updateBusiness(Business business) async {
    final db = await database;
    return await db.update(
      'businesses',
      business.toMap(),
      where: 'id = ?',
      whereArgs: [business.id],
    );
  }

  // ==========================================
  // CATEGORY OPERATIONS
  // ==========================================

  Future<List<Category>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    // Category deletion will set categoryId to null on associated products due to SET NULL rule.
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // PRODUCT OPERATIONS
  // ==========================================

  Future<List<Product>> getProducts() async {
    final db = await database;
    // Perform a LEFT JOIN to fetch the category name along with the product
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT p.*, c.name as categoryName 
      FROM products p 
      LEFT JOIN categories c ON p.categoryId = c.id
      ORDER BY p.name ASC
    ''');
    return results.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT p.*, c.name as categoryName 
      FROM products p 
      LEFT JOIN categories c ON p.categoryId = c.id
      WHERE p.id = ? LIMIT 1
    ''', [id]);
    if (results.isEmpty) return null;
    return Product.fromMap(results.first);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT p.*, c.name as categoryName 
      FROM products p 
      LEFT JOIN categories c ON p.categoryId = c.id
      WHERE p.barcode = ? LIMIT 1
    ''', [barcode]);
    if (results.isEmpty) return null;
    return Product.fromMap(results.first);
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.transaction((txn) async {
      final id = await txn.insert('products', product.toMap());
      // Log initial stock creation if stock > 0
      if (product.stockQuantity > 0 && product.isTracked) {
        await txn.insert('stock_movements', {
          'productId': id,
          'quantity': product.stockQuantity,
          'type': 'SET',
          'reason': 'Initial stock registration',
          'dateTime': DateTime.now().toIso8601String(),
        });
      }
      return id;
    });
  }

  Future<int> updateProduct(Product product, {String? movementReason}) async {
    final db = await database;
    return await db.transaction((txn) async {
      // Get the old product to check if stock has been updated manually
      final oldProductList = await txn.query('products', where: 'id = ?', whereArgs: [product.id], limit: 1);
      if (oldProductList.isNotEmpty) {
        final oldProduct = Product.fromMap(oldProductList.first);
        if (oldProduct.stockQuantity != product.stockQuantity && product.isTracked) {
          final diff = product.stockQuantity - oldProduct.stockQuantity;
          await txn.insert('stock_movements', {
            'productId': product.id!,
            'quantity': diff,
            'type': diff > 0 ? 'IN' : 'OUT',
            'reason': movementReason ?? 'Manual inventory correction',
            'dateTime': DateTime.now().toIso8601String(),
          });
        }
      }
      return await txn.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
    });
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // INVENTORY / STOCK MOVEMENTS OPERATIONS
  // ==========================================

  Future<List<StockMovement>> getStockMovements(int productId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT sm.*, p.name as productName 
      FROM stock_movements sm
      JOIN products p ON sm.productId = p.id
      WHERE sm.productId = ?
      ORDER BY sm.dateTime DESC
    ''', [productId]);
    return results.map((map) => StockMovement.fromMap(map)).toList();
  }

  Future<List<StockMovement>> getAllStockMovements() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT sm.*, p.name as productName 
      FROM stock_movements sm
      JOIN products p ON sm.productId = p.id
      ORDER BY sm.dateTime DESC
    ''');
    return results.map((map) => StockMovement.fromMap(map)).toList();
  }

  Future<int> insertStockMovement(int productId, int quantity, String type, String reason) async {
    final db = await database;
    return await db.transaction((txn) async {
      // 1. Insert movement log
      final id = await txn.insert('stock_movements', {
        'productId': productId,
        'quantity': quantity,
        'type': type,
        'reason': reason,
        'dateTime': DateTime.now().toIso8601String(),
      });

      // 2. Adjust product stock
      if (type == 'SET') {
        await txn.rawUpdate(
          'UPDATE products SET stockQuantity = ? WHERE id = ? AND isTracked = 1',
          [quantity, productId],
        );
      } else {
        await txn.rawUpdate(
          'UPDATE products SET stockQuantity = stockQuantity + ? WHERE id = ? AND isTracked = 1',
          [quantity, productId],
        );
      }

      return id;
    });
  }

  // ==========================================
  // TRANSACTIONAL CHECKOUT & INVOICES
  // ==========================================

  Future<int> checkout(Invoice invoice) async {
    final db = await database;
    return await db.transaction((txn) async {
      // 1. Insert invoice master record
      final invoiceId = await txn.insert('invoices', invoice.toMap());

      // 2. Process each item in the cart
      for (var item in invoice.items) {
        // Associate item with newly created invoice ID
        final itemMap = item.copyWith(invoiceId: invoiceId).toMap();
        await txn.insert('invoice_items', itemMap);

        // Fetch current product to check if we track stock
        final products = await txn.query('products', where: 'id = ?', whereArgs: [item.productId], limit: 1);
        if (products.isNotEmpty) {
          final product = Product.fromMap(products.first);
          if (product.isTracked) {
            // Deduct stock quantity
            await txn.rawUpdate('''
              UPDATE products 
              SET stockQuantity = stockQuantity - ? 
              WHERE id = ?
            ''', [item.quantity, item.productId]);

            // Log stock movement
            await txn.insert('stock_movements', {
              'productId': item.productId,
              'quantity': -item.quantity,
              'type': 'OUT',
              'reason': 'POS Checkout ${invoice.invoiceNumber}',
              'dateTime': invoice.dateTime.toIso8601String(),
            });
          }
        }
      }

      return invoiceId;
    });
  }

  Future<List<Invoice>> getInvoices() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query('invoices', orderBy: 'dateTime DESC');
    
    List<Invoice> invoices = [];
    for (var map in results) {
      final invoiceId = map['id'] as int;
      final List<Map<String, dynamic>> itemResults = await db.query(
        'invoice_items',
        where: 'invoiceId = ?',
        whereArgs: [invoiceId],
      );
      final items = itemResults.map((itemMap) => InvoiceItem.fromMap(itemMap)).toList();
      invoices.add(Invoice.fromMap(map, items: items));
    }
    return invoices;
  }

  Future<Invoice?> getInvoiceById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query('invoices', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    
    final List<Map<String, dynamic>> itemResults = await db.query(
      'invoice_items',
      where: 'invoiceId = ?',
      whereArgs: [id],
    );
    final items = itemResults.map((itemMap) => InvoiceItem.fromMap(itemMap)).toList();
    return Invoice.fromMap(results.first, items: items);
  }

  Future<int> deleteInvoice(int id) async {
    final db = await database;
    // This will cascadingly delete invoice_items as well.
    // NOTE: Does not automatically replenish inventory, which is correct as the user requested POS billing
    // and returns/refunds/voids are excluded from master scope.
    return await db.delete(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // PRINTER SETTINGS OPERATIONS
  // ==========================================

  Future<List<PrinterSettings>> getPrinters() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('printer_settings');
    return maps.map((map) => PrinterSettings.fromMap(map)).toList();
  }

  Future<int> insertPrinter(PrinterSettings printer) async {
    final db = await database;
    return await db.insert('printer_settings', printer.toMap());
  }

  Future<int> updatePrinter(PrinterSettings printer) async {
    final db = await database;
    return await db.update(
      'printer_settings',
      printer.toMap(),
      where: 'id = ?',
      whereArgs: [printer.id],
    );
  }

  Future<int> deletePrinter(int id) async {
    final db = await database;
    return await db.delete(
      'printer_settings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
