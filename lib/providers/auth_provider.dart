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

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  GoogleSignIn get googleSignIn => _googleSignIn;

  String get displayName => _currentUser?.displayName ?? "Guest";
  String get email => _currentUser?.email ?? "";

  AuthProvider() {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _currentUser = account;
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
      return account != null;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _googleSignIn.disconnect();
      _currentUser = null;
    } catch (e) {
      // fallback in case disconnect fails
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      _currentUser = null;
      debugPrint("Google Sign-Out/Disconnect Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
