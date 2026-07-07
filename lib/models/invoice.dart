import 'invoice_item.dart';

class Invoice {
  final int? id;
  final String invoiceNumber;
  final DateTime dateTime;
  final double totalAmount;
  final double taxAmount;
  final double discountAmount;
  final double grandTotal;
  final String paymentMethod; // 'CASH', 'UPI', 'CARD', etc.
  final String paymentStatus; // 'PAID', 'PENDING'
  final String customerPhone;
  final List<InvoiceItem> items; // Joined relation, not database column

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.dateTime,
    required this.totalAmount,
    required this.taxAmount,
    required this.discountAmount,
    required this.grandTotal,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.customerPhone,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'dateTime': dateTime.toIso8601String(),
      'totalAmount': totalAmount,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'grandTotal': grandTotal,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'customerPhone': customerPhone,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map, {List<InvoiceItem> items = const []}) {
    return Invoice(
      id: map['id'] as int?,
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      dateTime: DateTime.tryParse(map['dateTime'] as String? ?? '') ?? DateTime.now(),
      totalAmount: (map['totalAmount'] as num? ?? 0.0).toDouble(),
      taxAmount: (map['taxAmount'] as num? ?? 0.0).toDouble(),
      discountAmount: (map['discountAmount'] as num? ?? 0.0).toDouble(),
      grandTotal: (map['grandTotal'] as num? ?? 0.0).toDouble(),
      paymentMethod: map['paymentMethod'] as String? ?? 'CASH',
      paymentStatus: map['paymentStatus'] as String? ?? 'PAID',
      customerPhone: map['customerPhone'] as String? ?? '',
      items: items,
    );
  }

  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    DateTime? dateTime,
    double? totalAmount,
    double? taxAmount,
    double? discountAmount,
    double? grandTotal,
    String? paymentMethod,
    String? paymentStatus,
    String? customerPhone,
    List<InvoiceItem>? items,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      dateTime: dateTime ?? this.dateTime,
      totalAmount: totalAmount ?? this.totalAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
    );
  }
}
