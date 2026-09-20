import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:url_launcher/url_launcher.dart';

import '../config/supabase_config.dart';
import '../config/web_auth_config.dart';
import 'account_deletion_rpc.dart';
import 'apple_sign_in_client.dart';
import 'auth_exceptions.dart';
import 'authentication_repository.dart';

/// Supabase Auth + Google / Apple Sign-In 実装。
class SupabaseAuthenticationRepository extends AuthenticationRepository {
  SupabaseAuthenticationRepository({
    SupabaseClient? client,
    GoogleSignIn? googleSignIn,
    AppleSignInClient? appleSignInClient,
  }) : _client = client ?? Supabase.instance.client,
       _googleSignIn = kIsWeb
           ? null
           : googleSignIn ??
                 GoogleSignIn(
                   clientId: SupabaseConfig.googleIosClientId.isEmpty
                       ? null
                       : SupabaseConfig.googleIosClientId,
                   serverClientId: SupabaseConfig.googleWebClientId.isEmpty
                       ? null
                       : SupabaseConfig.googleWebClientId,
                 ),
       _appleSignInClient = appleSignInClient ?? const AppleSignInClient();

  final SupabaseClient _client;
  final GoogleSignIn? _googleSignIn;
  final AppleSignInClient _appleSignInClient;

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

    try {
      await _client.auth.refreshSession();
    } catch (_) {
      try {
        await _client.auth.signOut();
      } catch (_) {}
    }
  }

  @override
  Future<void> loginWithGoogle() async {
    if (!SupabaseConfig.isGoogleConfigured) {
      throw GoogleSignInFailedException('Google Sign-In is not configured.');
    }

    if (kIsWeb) {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: WebAuthConfig.redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw GoogleSignInFailedException(
          'Could not launch Google sign-in browser.',
        );
      }
      return;
    }

    final googleSignIn = _googleSignIn;
    if (googleSignIn == null) {
      throw GoogleSignInFailedException('Google Sign-In is not available.');
    }

    final googleUser = await googleSignIn.signIn();
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
    if (kIsWeb) {
      throw AppleSignInUnavailableException();
    }

    try {
      final result = await _appleSignInClient.fetchIdToken();
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: result.identityToken,
        nonce: result.rawNonce,
      );
    } on AppleSignInCancelledException {
      rethrow;
    } on AppleSignInUnavailableException {
      rethrow;
    } on AppleSignInFailedException {
      rethrow;
    } on AuthException catch (error) {
      throw AppleSignInFailedException(error.message);
    }
  }

  @override
  Future<void> logout() async {
    await _googleSignIn?.signOut();
    await _client.auth.signOut();
  }

  @override
  Future<void> deleteOwnAccount() {
    return deleteOwnAccountWithClient(_client);
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
    throw AppleSignInFailedException('Supabase is not configured.');
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteOwnAccount() async {
    throw AccountDeletionUnavailableException();
  }
}
