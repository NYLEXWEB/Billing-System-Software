class InvoiceItem {
  final int? id;
  final int? invoiceId;
  final int productId;
  final String productName;
  final double price;
  final int quantity;
  final double subtotal;

  InvoiceItem({
    this.id,
    this.invoiceId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'] as int?,
      invoiceId: map['invoiceId'] as int?,
      productId: map['productId'] as int? ?? 0,
      productName: map['productName'] as String? ?? '',
      price: (map['price'] as num? ?? 0.0).toDouble(),
      quantity: map['quantity'] as int? ?? 0,
      subtotal: (map['subtotal'] as num? ?? 0.0).toDouble(),
    );
  }

  InvoiceItem copyWith({
    int? id,
    int? invoiceId,
    int? productId,
    String? productName,
    double? price,
    int? quantity,
    double? subtotal,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}
