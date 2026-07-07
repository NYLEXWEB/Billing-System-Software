class Product {
  final int? id;
  final int? categoryId;
  final String name;
  final String barcode;
  final double price;
  final double costPrice;
  final int stockQuantity;
  final int lowStockThreshold;
  final bool isTracked; // true if we track inventory stock levels
  final String? categoryName; // Helper field for joined UI display

  Product({
    this.id,
    this.categoryId,
    required this.name,
    required this.barcode,
    required this.price,
    this.costPrice = 0.0,
    this.stockQuantity = 0,
    this.lowStockThreshold = 5,
    this.isTracked = true,
    this.categoryName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'name': name,
      'barcode': barcode,
      'price': price,
      'costPrice': costPrice,
      'stockQuantity': stockQuantity,
      'lowStockThreshold': lowStockThreshold,
      'isTracked': isTracked ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      categoryId: map['categoryId'] as int?,
      name: map['name'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      price: (map['price'] as num? ?? 0.0).toDouble(),
      costPrice: (map['costPrice'] as num? ?? 0.0).toDouble(),
      stockQuantity: map['stockQuantity'] as int? ?? 0,
      lowStockThreshold: map['lowStockThreshold'] as int? ?? 5,
      isTracked: (map['isTracked'] as int? ?? 1) == 1,
      categoryName: map['categoryName'] as String?,
    );
  }

  Product copyWith({
    int? id,
    int? categoryId,
    String? name,
    String? barcode,
    double? price,
    double? costPrice,
    int? stockQuantity,
    int? lowStockThreshold,
    bool? isTracked,
    String? categoryName,
  }) {
    return Product(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isTracked: isTracked ?? this.isTracked,
      categoryName: categoryName ?? this.categoryName,
    );
  }
}
