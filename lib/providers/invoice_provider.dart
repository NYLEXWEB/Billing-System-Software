import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../models/invoice.dart';

class InvoiceProvider extends ChangeNotifier {
  final DbHelper _dbHelper = DbHelper();

  List<Invoice> _invoices = [];
  bool _isLoading = false;

  List<Invoice> get invoices => _invoices;
  bool get isLoading => _isLoading;

  Future<void> loadInvoices() async {
    _isLoading = true;
    notifyListeners();
    try {
      _invoices = await _dbHelper.getInvoices();
    } catch (e) {
      debugPrint("Error loading invoices: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> checkout(Invoice invoice) async {
    _isLoading = true;
    notifyListeners();
    try {
      final invoiceId = await _dbHelper.checkout(invoice);
      await loadInvoices();
      return invoiceId;
    } catch (e) {
      debugPrint("Checkout Error: $e");
      return -1;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteInvoice(int id) async {
    try {
      final count = await _dbHelper.deleteInvoice(id);
      if (count > 0) {
        await loadInvoices();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error deleting invoice: $e");
      return false;
    }
  }

  // ==========================================
  // REPORTS & ANALYTICS DATA BUILDERS
  // ==========================================

  double get salesToday {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    return _invoices
        .where((inv) => DateFormat('yyyy-MM-dd').format(inv.dateTime) == todayStr)
        .fold(0.0, (sum, inv) => sum + inv.grandTotal);
  }

  double get salesThisMonth {
    final now = DateTime.now();
    final monthStr = DateFormat('yyyy-MM').format(now);
    return _invoices
        .where((inv) => DateFormat('yyyy-MM').format(inv.dateTime) == monthStr)
        .fold(0.0, (sum, inv) => sum + inv.grandTotal);
  }

  int get ordersTodayCount {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    return _invoices
        .where((inv) => DateFormat('yyyy-MM-dd').format(inv.dateTime) == todayStr)
        .length;
  }

  Map<String, double> get paymentMethodBreakdown {
    final Map<String, double> breakdown = {};
    for (var inv in _invoices) {
      breakdown[inv.paymentMethod] = (breakdown[inv.paymentMethod] ?? 0.0) + inv.grandTotal;
    }
    return breakdown;
  }

  // Get daily sales aggregates for the last 7 days (including days with 0 sales)
  List<DailySalesPoint> get last7DaysSales {
    final List<DailySalesPoint> points = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      final label = DateFormat('E').format(targetDate); // e.g. "Mon"

      final daySales = _invoices
          .where((inv) => DateFormat('yyyy-MM-dd').format(inv.dateTime) == dateStr)
          .fold(0.0, (sum, inv) => sum + inv.grandTotal);

      points.add(DailySalesPoint(dateStr: dateStr, label: label, amount: daySales));
    }

    return points;
  }
}

class DailySalesPoint {
  final String dateStr;
  final String label;
  final double amount;

  DailySalesPoint({
    required this.dateStr,
    required this.label,
    required this.amount,
  });
}
