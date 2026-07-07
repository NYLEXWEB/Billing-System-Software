class StockMovement {
  final int? id;
  final int productId;
  final int quantity;
  final String type; // 'IN', 'OUT', 'SET'
  final String reason;
  final DateTime dateTime;
  final String? productName; // Helper field for joined UI display

  StockMovement({
    this.id,
    required this.productId,
    required this.quantity,
    required this.type,
    required this.reason,
    required this.dateTime,
    this.productName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'quantity': quantity,
      'type': type,
      'reason': reason,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as int?,
      productId: map['productId'] as int? ?? 0,
      quantity: map['quantity'] as int? ?? 0,
      type: map['type'] as String? ?? 'IN',
      reason: map['reason'] as String? ?? '',
      dateTime: DateTime.tryParse(map['dateTime'] as String? ?? '') ?? DateTime.now(),
      productName: map['productName'] as String?,
    );
  }

  StockMovement copyWith({
    int? id,
    int? productId,
    int? quantity,
    String? type,
    String? reason,
    DateTime? dateTime,
    String? productName,
  }) {
    return StockMovement(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      dateTime: dateTime ?? this.dateTime,
      productName: productName ?? this.productName,
    );
  }
}
