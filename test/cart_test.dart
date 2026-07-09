import 'package:flutter_test/flutter_test.dart';
import 'package:billing_system_software/providers/cart_provider.dart';
import 'package:billing_system_software/models/product.dart';

void main() {
  group('CartProvider Financial Calculations Tests', () {
    late CartProvider cart;

    setUp(() {
      cart = CartProvider();
    });

    test('Initial cart state should be empty and totals should be zero', () {
      expect(cart.items.isEmpty, true);
      expect(cart.totalAmount, 0.0);
      expect(cart.calculatedTaxAmount, 0.0);
      expect(cart.grandTotal, 0.0);
    });

    test('Adding untracked items should update subtotal, tax, and grand total', () {
      final p1 = Product(id: 1, name: 'Soap', barcode: '111', price: 25.0, isTracked: false);
      final p2 = Product(id: 2, name: 'Toothpaste', barcode: '222', price: 45.0, isTracked: false);

      final ok1 = cart.addItem(p1, quantity: 2); // 50.0
      final ok2 = cart.addItem(p2, quantity: 1); // 45.0

      expect(ok1, true);
      expect(ok2, true);
      expect(cart.items.length, 2);
      expect(cart.totalAmount, 95.0);

      // Default tax and discount is 0.0
      expect(cart.calculatedTaxAmount, 0.0);
      expect(cart.grandTotal, 95.0);
    });

    test('Applying discount and tax rate should compute correct totals', () {
      final p1 = Product(id: 1, name: 'Soap', barcode: '111', price: 50.0, isTracked: false);
      cart.addItem(p1, quantity: 2); // 100.0 total

      cart.setDiscountAmount(10.0); // 100 - 10 = 90 taxable
      cart.setTaxRate(18.0); // 18% of 90 = 16.2

      expect(cart.totalAmount, 100.0);
      expect(cart.discountAmount, 10.0);
      expect(cart.taxRate, 18.0);
      expect(cart.calculatedTaxAmount, 16.20);
      expect(cart.grandTotal, 106.20);
    });

    test('Updating quantities should modify totals and respect stock limits', () {
      final p1 = Product(id: 1, name: 'Soap', barcode: '111', price: 20.0, isTracked: true, stockQuantity: 5);

      // Add 2 soaps
      var success = cart.addItem(p1, quantity: 2);
      expect(success, true);
      expect(cart.totalAmount, 40.0);

      // Try updating to 6 (exceeds stock of 5)
      success = cart.updateQuantity(1, 6, p1);
      expect(success, false);
      expect(cart.totalAmount, 40.0); // unchanged

      // Update to 4 (valid)
      success = cart.updateQuantity(1, 4, p1);
      expect(success, true);
      expect(cart.totalAmount, 80.0);
    });

    test('UPI QR string generation formatting should be correct', () {
      final p1 = Product(id: 1, name: 'Soap', barcode: '111', price: 100.0, isTracked: false);
      cart.addItem(p1, quantity: 1); // 100.0

      cart.setTaxRate(10.0); // 10% tax = 10.0 => 110.0 grand total

      final upiStr = cart.generateUpiString(
        upiId: 'test@upi',
        businessName: 'My shop & Co',
        invoiceNumber: 'INV-1234',
      );

      expect(upiStr, 'upi://pay?pa=test@upi&pn=My%20shop%20%26%20Co&am=110.00&cu=INR&tn=Invoice%20INV-1234');
    });
  });
}
