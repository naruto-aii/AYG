import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../config/supabase_config.dart';
import 'auth_exceptions.dart';
import 'authentication_repository.dart';

/// Supabase Auth + Google Sign-In 実装。
class SupabaseAuthenticationRepository extends AuthenticationRepository {
  SupabaseAuthenticationRepository({
    SupabaseClient? client,
    GoogleSignIn? googleSignIn,
  }) : _client = client ?? Supabase.instance.client,
       _googleSignIn =
           googleSignIn ??
           GoogleSignIn(
             clientId: SupabaseConfig.googleIosClientId.isEmpty
                 ? null
                 : SupabaseConfig.googleIosClientId,
             serverClientId: SupabaseConfig.googleWebClientId.isEmpty
                 ? null
                 : SupabaseConfig.googleWebClientId,
           );

  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;

  @override
  AuthUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges {
    return _client.auth.onAuthStateChange.map(
      (event) => _mapUser(event.session?.user),
    );
  }

  @override
  Future<void> restoreSession() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      return;
    }
    await _client.auth.refreshSession();
  }

  @override
  Future<void> loginWithGoogle() async {
    if (!SupabaseConfig.isGoogleConfigured) {
      throw GoogleSignInFailedException('Google Sign-In is not configured.');
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw GoogleSignInCancelledException();
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw GoogleSignInFailedException('Google ID token is missing.');
    }

    try {
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
    } on AuthException catch (error) {
      throw GoogleSignInFailedException(error.message);
    }
  }

  @override
  Future<void> loginWithApple() async {
    throw UnimplementedError(
      'Apple Sign-In will be implemented in a later phase.',
    );
  }

  @override
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _client.auth.signOut();
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    return AuthUser(id: user.id, email: user.email);
  }
}

/// Supabase 未設定時のスタブ（常に未ログイン）。
class UnconfiguredAuthenticationRepository extends AuthenticationRepository {
  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> loginWithGoogle() async {
    throw StateError('Supabase is not configured.');
  }

  @override
  Future<void> loginWithApple() async {
    throw UnimplementedError(
      'Apple Sign-In will be implemented in a later phase.',
    );
  }

  @override
  Future<void> logout() async {}
}
