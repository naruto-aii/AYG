import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:url_launcher/url_launcher.dart';

import '../config/supabase_config.dart';
import '../config/web_auth_config.dart';
import '../models/display_name.dart';
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

  /// このプロセスでサインイン元が返した名前。
  /// user_metadata への保存に失敗しても、同じ起動中の初期値に使う。
  String? _sessionSuggestedName;

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

    await _rememberSuggestedName(DisplayName.normalize(googleUser.displayName));
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

    await _rememberSuggestedName(
      DisplayName.fromPersonName(
        givenName: credential.givenName,
        familyName: credential.familyName,
      ),
    );
  }

  /// 今回のサインインが返した名前を覚える。空なら、この起動中の提案は消す。
  ///
  /// Apple は初回の認可でしか氏名を返さないので、返ってきた名前は
  /// user_metadata.full_name にも残す。すでに名前がある metadata は上書きしない。
  Future<void> _rememberSuggestedName(String? name) async {
    _sessionSuggestedName = name;
    if (name == null) {
      return;
    }
    final existing = DisplayName.fromUserMetadata(
      _client.auth.currentUser?.userMetadata,
    );
    if (existing != null) {
      return;
    }
    try {
      await _client.auth.updateUser(UserAttributes(data: {'full_name': name}));
    } catch (_) {
      // この起動中は _sessionSuggestedName を初期値に使う。
      // 再起動後に metadata も空なら、ユーザー名欄は空のまま手入力になる。
    }
  }

  /// OS 標準のシートが使えるか（iOS / macOS のみ）。
  bool get _supportsNativeApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Future<void> logout() async {
    _sessionSuggestedName = null;
    await _googleSignIn?.signOut();
    await _client.auth.signOut();
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    return AuthUser(
      id: user.id,
      email: user.email,
      suggestedDisplayName:
          _sessionSuggestedName ??
          DisplayName.fromUserMetadata(user.userMetadata),
    );
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
