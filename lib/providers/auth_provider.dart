import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_constants.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  late final StreamSubscription<AuthState> _authSub;
  bool _visitor = false;
  bool _isLoggingOut = false; // Track logout state

  AuthProvider() {
    _authSub = _client.auth.onAuthStateChange.listen((event) {
      // When auth state changes, reset visitor mode and notify
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.signedOut) {
        _visitor = false;
        _isLoggingOut = false; // Reset logout state
      }
      notifyListeners();
    });
  }

  User? get user => _client.auth.currentUser;
  bool get isAuthenticated => user != null && !_isLoggingOut;
  bool get isVisitor => _visitor && !_isLoggingOut;

  String get userId {
    if (isVisitor) {
      return AppConstants.visitorUserId;
    }
    return user?.id ?? AppConstants.visitorUserId;
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  void continueAsVisitor() {
    _visitor = true;
    _isLoggingOut = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      // Set logout state immediately to trigger navigation
      _isLoggingOut = true;
      _visitor = false;
      notifyListeners(); // This should immediately navigate to login screen
      
      // Then perform the actual sign out
      await _client.auth.signOut();
    } catch (e) {
      // If sign out fails, reset the logout state
      _isLoggingOut = false;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
