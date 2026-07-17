import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Sign In / Out
  static Future<void> logLoginSuccess(String email) async {
    await _analytics.logEvent(
      name: 'google_login_success',
      parameters: {'email': email},
    );
  }

  static Future<void> logLoginFailure(String error) async {
    await _analytics.logEvent(
      name: 'google_login_failure',
      parameters: {'reason': error},
    );
  }

  static Future<void> logLogout(String email) async {
    await _analytics.logEvent(
      name: 'logout',
      parameters: {'email': email},
    );
  }

  // Product actions
  static Future<void> logProductCreated({
    required String productId,
    required String name,
    required String category,
  }) async {
    await _analytics.logEvent(
      name: 'product_created',
      parameters: {
        'product_id': productId,
        'product_name': name,
        'category': category,
      },
    );
  }

  static Future<void> logProductUpdated({
    required String productId,
    required String name,
  }) async {
    await _analytics.logEvent(
      name: 'product_updated',
      parameters: {
        'product_id': productId,
        'product_name': name,
      },
    );
  }

  static Future<void> logProductDeleted({
    required String productId,
    required String name,
  }) async {
    await _analytics.logEvent(
      name: 'product_deleted',
      parameters: {
        'product_id': productId,
        'product_name': name,
      },
    );
  }

  // Barcode actions
  static Future<void> logBarcodeScan(String code) async {
    await _analytics.logEvent(
      name: 'barcode_scan',
      parameters: {'barcode_value': code},
    );
  }

  // Bill/Invoice actions
  static Future<void> logBillCreated({
    required String invoiceNo,
    required double totalAmount,
    required int itemCount,
  }) async {
    await _analytics.logEvent(
      name: 'bill_created',
      parameters: {
        'invoice_no': invoiceNo,
        'total_amount': totalAmount,
        'item_count': itemCount,
      },
    );
  }

  static Future<void> logBillPrinted(String invoiceNo) async {
    await _analytics.logEvent(
      name: 'bill_printed',
      parameters: {'invoice_no': invoiceNo},
    );
  }

  // Settings
  static Future<void> logSettingsOpened() async {
    await _analytics.logEvent(name: 'settings_opened');
  }

  // Backup / Restore
  static Future<void> logBackupStarted() async {
    await _analytics.logEvent(name: 'backup_started');
  }

  static Future<void> logBackupCompleted() async {
    await _analytics.logEvent(name: 'backup_completed');
  }

  static Future<void> logBackupFailed(String reason) async {
    await _analytics.logEvent(
      name: 'backup_failed',
      parameters: {'reason': reason},
    );
  }
}
