import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:url_launcher/url_launcher.dart';

import '../config/supabase_config.dart';
import '../config/web_auth_config.dart';
import 'auth_exceptions.dart';
import 'authentication_repository.dart';

/// Supabase Auth + Google Sign-In 実装。
class SupabaseAuthenticationRepository extends AuthenticationRepository {
  SupabaseAuthenticationRepository({
    SupabaseClient? client,
    GoogleSignIn? googleSignIn,
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
                 );

  final SupabaseClient _client;
  final GoogleSignIn? _googleSignIn;

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

  /// Apple ID でログインする。
  ///
  /// - iOS / macOS: OS 標準のシートを出し、受け取った ID トークンで Supabase に
  ///   サインインする。Xcode で "Sign in with Apple" の Capability が必要。
  /// - それ以外（Web / Android）: Supabase の OAuth リダイレクトを使う。
  ///   Supabase 側で Apple プロバイダの設定が必要。
  @override
  Future<void> loginWithApple() async {
    if (kIsWeb || !_supportsNativeApple) {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: WebAuthConfig.redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw AppleSignInFailedException(
          'Could not launch Apple sign-in browser.',
        );
      }
      return;
    }

    // リプレイ攻撃を防ぐため、生の nonce を Supabase に、
    // その SHA-256 を Apple に渡す。
    final rawNonce = _client.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw AppleSignInCancelledException();
      }
      throw AppleSignInFailedException(error.message);
    } on SignInWithAppleException catch (error) {
      throw AppleSignInFailedException(error.toString());
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw AppleSignInFailedException('Apple ID token is missing.');
    }

    try {
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
    } on AuthException catch (error) {
      throw AppleSignInFailedException(error.message);
    }
  }

  /// OS 標準のシートが使えるか（iOS / macOS のみ）。
  bool get _supportsNativeApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Future<void> logout() async {
    await _googleSignIn?.signOut();
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
    throw StateError('Supabase is not configured.');
  }

  @override
  Future<void> logout() async {}
}
