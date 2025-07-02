import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  late final StreamSubscription<AuthState> _authSub;
  bool _visitor = false;

  AuthProvider() {
    _authSub = _client.auth.onAuthStateChange.listen((event) {
      // When auth state changes, reset visitor mode and notify
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.signedOut) {
        _visitor = false;
      }
      notifyListeners();
    });
  }

  User? get user => _client.auth.currentUser;
  bool get isAuthenticated => user != null;
  bool get isVisitor => _visitor;

  int get userId => isVisitor ? -1 : -1; // Placeholder until real user IDs

  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  void continueAsVisitor() {
    _visitor = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    _visitor = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
