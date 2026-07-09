import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  GoogleSignInAccount? _currentUser;
  bool _isLoading = false;
  bool _isTestUser = false;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isTestUser => _isTestUser;
  bool get isAuthenticated => _currentUser != null || _isTestUser;
  GoogleSignIn get googleSignIn => _googleSignIn;

  String get displayName => _currentUser?.displayName ?? (_isTestUser ? "Demo Test User" : "Guest");
  String get email => _currentUser?.email ?? (_isTestUser ? "testuser@easytobill.com" : "");

  AuthProvider() {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _currentUser = account;
      if (account != null) {
        _isTestUser = false;
      }
      notifyListeners();
    });
    // Check silent sign-in on launch
    _googleSignIn.signInSilently().catchError((e) {
      debugPrint("Silent Sign-In failed: $e");
      return null;
    });
  }

  Future<bool> signIn() async {
    _isLoading = true;
    notifyListeners();
    try {
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      if (account != null) {
        _isTestUser = false;
      }
      return account != null;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInAsTestUser() async {
    _isLoading = true;
    notifyListeners();
    _isTestUser = true;
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_isTestUser) {
        _isTestUser = false;
      } else {
        await _googleSignIn.disconnect();
      }
      _currentUser = null;
    } catch (e) {
      // fallback in case disconnect fails
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      _currentUser = null;
      _isTestUser = false;
      debugPrint("Google Sign-Out/Disconnect Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
