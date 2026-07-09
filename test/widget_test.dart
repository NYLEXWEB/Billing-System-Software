import 'package:flutter_test/flutter_test.dart';
import 'package:billing_system_software/models/business.dart';
import 'package:billing_system_software/models/product.dart';
import 'package:billing_system_software/models/category.dart';
import 'package:billing_system_software/models/invoice.dart';
import 'package:billing_system_software/models/invoice_item.dart';

void main() {
  group('Database Schema Model Mapping Tests', () {
    test('Business model serialization and deserialization should be symmetrical', () {
      final business = Business(
        id: 1,
        name: 'Superstore Mart',
        phone: '9876543210',
        email: 'info@superstore.com',
        address: '123 Main St, Bangalore',
        gstOrTin: '29ABCDE1234F1Z5',
        currency: '₹',
        upiId: 'superstore@okaxis',
        themeMode: 'dark',
      );

      final map = business.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Superstore Mart');
      expect(map['phone'], '9876543210');
      expect(map['email'], 'info@superstore.com');
      expect(map['address'], '123 Main St, Bangalore');
      expect(map['gstOrTin'], '29ABCDE1234F1Z5');
      expect(map['currency'], '₹');
      expect(map['upiId'], 'superstore@okaxis');
      expect(map['themeMode'], 'dark');

      final fromMap = Business.fromMap(map);
      expect(fromMap.id, business.id);
      expect(fromMap.name, business.name);
      expect(fromMap.phone, business.phone);
      expect(fromMap.email, business.email);
      expect(fromMap.address, business.address);
      expect(fromMap.gstOrTin, business.gstOrTin);
      expect(fromMap.currency, business.currency);
      expect(fromMap.upiId, business.upiId);
      expect(fromMap.themeMode, business.themeMode);
    });

    test('Product model mapping with tracking flags should be correct', () {
      final product = Product(
        id: 101,
        categoryId: 5,
        name: 'Organic Honey',
        barcode: '8901234567890',
        price: 299.50,
        costPrice: 210.00,
        stockQuantity: 15,
        lowStockThreshold: 5,
        isTracked: true,
      );

      final map = product.toMap();
      expect(map['id'], 101);
      expect(map['categoryId'], 5);
      expect(map['name'], 'Organic Honey');
      expect(map['barcode'], '8901234567890');
      expect(map['price'], 299.50);
      expect(map['costPrice'], 210.00);
      expect(map['stockQuantity'], 15);
      expect(map['lowStockThreshold'], 5);
      expect(map['isTracked'], 1); // Stored as integer (1 = true)

      final fromMap = Product.fromMap(map);
      expect(fromMap.id, product.id);
      expect(fromMap.categoryId, product.categoryId);
      expect(fromMap.name, product.name);
      expect(fromMap.barcode, product.barcode);
      expect(fromMap.price, product.price);
      expect(fromMap.costPrice, product.costPrice);
      expect(fromMap.stockQuantity, product.stockQuantity);
      expect(fromMap.lowStockThreshold, product.lowStockThreshold);
      expect(fromMap.isTracked, product.isTracked);
    });

    test('Category model mapping should be correct', () {
      final category = Category(id: 3, name: 'Beverages', description: 'Cold drinks and juices');
      final map = category.toMap();
      expect(map['id'], 3);
      expect(map['name'], 'Beverages');
      expect(map['description'], 'Cold drinks and juices');

      final fromMap = Category.fromMap(map);
      expect(fromMap.id, category.id);
      expect(fromMap.name, category.name);
      expect(fromMap.description, category.description);
    });

    test('Invoice and InvoiceItem mapping should support full transaction history reconstruction', () {
      final now = DateTime.now();
      final item1 = InvoiceItem(
        id: 1,
        invoiceId: 10,
        productId: 45,
        productName: 'Milk Pack 1L',
        price: 60.0,
        quantity: 2,
        subtotal: 120.0,
      );

      final invoice = Invoice(
        id: 10,
        invoiceNumber: 'INV-2026-0001',
        dateTime: now,
        totalAmount: 120.0,
        taxAmount: 6.0,
        discountAmount: 10.0,
        grandTotal: 116.0,
        paymentMethod: 'UPI',
        paymentStatus: 'PAID',
        customerPhone: '9988776655',
        items: [item1],
      );

      // Verify InvoiceItem mapping
      final itemMap = item1.toMap();
      expect(itemMap['id'], 1);
      expect(itemMap['invoiceId'], 10);
      expect(itemMap['productId'], 45);
      expect(itemMap['productName'], 'Milk Pack 1L');
      expect(itemMap['price'], 60.0);
      expect(itemMap['quantity'], 2);
      expect(itemMap['subtotal'], 120.0);

      final itemFromMap = InvoiceItem.fromMap(itemMap);
      expect(itemFromMap.id, item1.id);
      expect(itemFromMap.invoiceId, item1.invoiceId);
      expect(itemFromMap.productId, item1.productId);
      expect(itemFromMap.productName, item1.productName);
      expect(itemFromMap.price, item1.price);
      expect(itemFromMap.quantity, item1.quantity);
      expect(itemFromMap.subtotal, item1.subtotal);

      // Verify Invoice mapping
      final invoiceMap = invoice.toMap();
      expect(invoiceMap['id'], 10);
      expect(invoiceMap['invoiceNumber'], 'INV-2026-0001');
      expect(invoiceMap['dateTime'], now.toIso8601String());
      expect(invoiceMap['totalAmount'], 120.0);
      expect(invoiceMap['taxAmount'], 6.0);
      expect(invoiceMap['discountAmount'], 10.0);
      expect(invoiceMap['grandTotal'], 116.0);
      expect(invoiceMap['paymentMethod'], 'UPI');
      expect(invoiceMap['paymentStatus'], 'PAID');
      expect(invoiceMap['customerPhone'], '9988776655');

      final invoiceFromMap = Invoice.fromMap(invoiceMap);
      expect(invoiceFromMap.id, invoice.id);
      expect(invoiceFromMap.invoiceNumber, invoice.invoiceNumber);
      expect(invoiceFromMap.dateTime.toIso8601String(), invoice.dateTime.toIso8601String());
      expect(invoiceFromMap.totalAmount, invoice.totalAmount);
      expect(invoiceFromMap.taxAmount, invoice.taxAmount);
      expect(invoiceFromMap.discountAmount, invoice.discountAmount);
      expect(invoiceFromMap.grandTotal, invoice.grandTotal);
      expect(invoiceFromMap.paymentMethod, invoice.paymentMethod);
      expect(invoiceFromMap.paymentStatus, invoice.paymentStatus);
      expect(invoiceFromMap.customerPhone, invoice.customerPhone);
    });
  });
}
