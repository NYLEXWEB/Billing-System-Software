import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/analytics_service.dart';

class AuthProvider extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  GoogleSignInAccount? _currentUser;
  User? _firebaseUser;
  bool _isLoading = false;

  GoogleSignInAccount? get currentUser => _currentUser;
  User? get firebaseUser => _firebaseUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null && _firebaseUser != null;
  GoogleSignIn get googleSignIn => _googleSignIn;

  String get displayName => _firebaseUser?.displayName ?? _currentUser?.displayName ?? "Guest";
  String get email => _firebaseUser?.email ?? _currentUser?.email ?? "";

  AuthProvider() {
    // Sync Firebase Auth state changes
    _firebaseAuth.authStateChanges().listen((User? user) {
      _firebaseUser = user;
      if (user != null) {
        // Record user identifier to Crashlytics
        FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
      }
      notifyListeners();
    });

    // Listen to Google Sign-In state changes
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      _currentUser = account;
      if (account != null) {
        try {
          final GoogleSignInAuthentication googleAuth = await account.authentication;
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await _firebaseAuth.signInWithCredential(credential);
        } catch (e) {
          debugPrint("Failed to sync Google user with Firebase Auth: $e");
        }
      } else {
        if (_firebaseAuth.currentUser != null) {
          await _firebaseAuth.signOut();
        }
      }
      notifyListeners();
    });

    // Restore sign-in state silently on startup
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        final GoogleSignInAuthentication googleAuth = await account.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _firebaseAuth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint("Silent Google Sign-In / Firebase Sync failed: $e");
    }
  }

  Future<bool> signIn() async {
    _isLoading = true;
    notifyListeners();
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        AnalyticsService.logLoginFailure("User cancelled Google Sign-in flow");
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await account.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        _currentUser = account;
        _firebaseUser = user;
        
        // Log custom analytics event and Crashlytics User ID
        AnalyticsService.logLoginSuccess(user.email ?? "");
        FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
        
        notifyListeners();
        return true;
      } else {
        AnalyticsService.logLoginFailure("Firebase user was null after credential login");
        return false;
      }
    } catch (e) {
      debugPrint("Google Sign-In / Firebase Auth Error: $e");
      AnalyticsService.logLoginFailure(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    final userEmail = email;
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint("Google Sign-Out Disconnect Error (falling back to simple signOut): $e");
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint("Firebase Sign-Out Error: $e");
    }

    _currentUser = null;
    _firebaseUser = null;
    AnalyticsService.logLogout(userEmail);
    _isLoading = false;
    notifyListeners();
  }
}
