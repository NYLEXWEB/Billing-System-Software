import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ConsentProvider extends ChangeNotifier {
  static const String currentVersion = '1.0';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isAccepted = false;
  String? _acceptedVersion;
  String? _acceptedDateTime;
  bool _isInitialized = false;

  bool get isAccepted => _isAccepted;
  String? get acceptedVersion => _acceptedVersion;
  String? get acceptedDateTime => _acceptedDateTime;
  bool get isInitialized => _isInitialized;

  Future<void> loadConsentStatus() async {
    try {
      final acceptedStr = await _storage.read(key: 'consent_accepted');
      final version = await _storage.read(key: 'consent_version');
      final dateTime = await _storage.read(key: 'consent_date');

      _acceptedVersion = version;
      _acceptedDateTime = dateTime;
      
      if (acceptedStr == 'true' && version == currentVersion) {
        _isAccepted = true;
      } else {
        _isAccepted = false;
      }
    } catch (e) {
      debugPrint("Error loading consent status: $e");
      _isAccepted = false;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> acceptConsent() async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      await _storage.write(key: 'consent_accepted', value: 'true');
      await _storage.write(key: 'consent_version', value: currentVersion);
      await _storage.write(key: 'consent_date', value: nowStr);

      _isAccepted = true;
      _acceptedVersion = currentVersion;
      _acceptedDateTime = nowStr;
      notifyListeners();
    } catch (e) {
      debugPrint("Error saving consent: $e");
    }
  }

  Future<void> clearConsent() async {
    try {
      await _storage.delete(key: 'consent_accepted');
      await _storage.delete(key: 'consent_version');
      await _storage.delete(key: 'consent_date');
      _isAccepted = false;
      _acceptedVersion = null;
      _acceptedDateTime = null;
      notifyListeners();
    } catch (e) {
      debugPrint("Error clearing consent: $e");
    }
  }
}
