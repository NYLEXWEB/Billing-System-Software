import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/invoice_item.dart';

class CartProvider extends ChangeNotifier {
  final List<InvoiceItem> _items = [];
  double _taxRate = 0.0; // Tax rate in percentage, e.g. 18.0 for 18% GST
  double _discountAmount = 0.0; // Flat discount amount

  List<InvoiceItem> get items => _items;
  double get taxRate => _taxRate;
  double get discountAmount => _discountAmount;

  // Add Item to cart
  // Returns true if added successfully, false if stock is insufficient and tracked.
  bool addItem(Product product, {int quantity = 1}) {
    // 1. Check if product is already in the cart
    final index = _items.indexWhere((item) => item.productId == product.id);

    if (index >= 0) {
      final currentQty = _items[index].quantity;
      final newQty = currentQty + quantity;

      // Check stock limits if product stock is tracked
      if (product.isTracked && newQty > product.stockQuantity) {
        return false;
      }

      _items[index] = _items[index].copyWith(
        quantity: newQty,
        subtotal: _items[index].price * newQty,
      );
    } else {
      // Check stock limits for new item
      if (product.isTracked && quantity > product.stockQuantity) {
        return false;
      }

      _items.add(InvoiceItem(
        productId: product.id!,
        productName: product.name,
        price: product.price,
        quantity: quantity,
        subtotal: product.price * quantity,
      ));
    }

    notifyListeners();
    return true;
  }

  // Update quantity of an item
  bool updateQuantity(int productId, int quantity, Product product) {
    if (quantity <= 0) {
      removeItem(productId);
      return true;
    }

    final index = _items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      if (product.isTracked && quantity > product.stockQuantity) {
        return false;
      }

      _items[index] = _items[index].copyWith(
        quantity: quantity,
        subtotal: _items[index].price * quantity,
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  // Remove item from cart
  void removeItem(int productId) {
    _items.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  // Clear cart
  void clear() {
    _items.clear();
    _discountAmount = 0.0;
    _taxRate = 0.0;
    notifyListeners();
  }

  // Set tax and discounts
  void setTaxRate(double rate) {
    _taxRate = rate;
    notifyListeners();
  }

  void setDiscountAmount(double amount) {
    _discountAmount = amount;
    notifyListeners();
  }

  // Financial Calculations
  double get totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get calculatedTaxAmount {
    // Tax is applied after discount
    final taxableAmount = totalAmount - _discountAmount;
    if (taxableAmount <= 0) return 0.0;
    return double.parse(((taxableAmount * _taxRate) / 100).toStringAsFixed(2));
  }

  double get grandTotal {
    final sub = totalAmount - _discountAmount;
    if (sub <= 0) return 0.0;
    return double.parse((sub + calculatedTaxAmount).toStringAsFixed(2));
  }

  // UPI QR String Generation
  String generateUpiString({
    required String upiId,
    required String businessName,
    required String invoiceNumber,
  }) {
    if (upiId.isEmpty) return '';
    final nameEncoded = Uri.encodeComponent(businessName);
    final noteEncoded = Uri.encodeComponent("Invoice $invoiceNumber");
    final amountString = grandTotal.toStringAsFixed(2);
    
    return "upi://pay?pa=$upiId&pn=$nameEncoded&am=$amountString&cu=INR&tn=$noteEncoded";
  }
}
