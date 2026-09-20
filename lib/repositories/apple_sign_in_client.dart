import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'auth_exceptions.dart';

/// Native Apple ID token and the raw nonce Supabase must verify.
class AppleIdTokenResult {
  const AppleIdTokenResult({
    required this.identityToken,
    required this.rawNonce,
  });

  final String identityToken;
  final String rawNonce;
}

typedef AppleNonceFactory = String Function();
typedef AppleCredentialFetcher =
    Future<AuthorizationCredentialAppleID> Function(String hashedNonce);

/// SHA-256 hashed nonce + Sign in with Apple identity token.
class AppleSignInClient {
  const AppleSignInClient({
    AppleNonceFactory? nonceFactory,
    AppleCredentialFetcher? credentialFetcher,
  }) : _nonceFactory = nonceFactory,
       _credentialFetcher = credentialFetcher;

  final AppleNonceFactory? _nonceFactory;
  final AppleCredentialFetcher? _credentialFetcher;

  Future<AppleIdTokenResult> fetchIdToken() async {
    final rawNonce = (_nonceFactory ?? generateAppleNonce)();
    final hashedNonce = sha256Hex(rawNonce);

    try {
      final credential = await (_credentialFetcher ?? _defaultCredentialFetcher)(
        hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw AppleSignInFailedException('Apple identity token is missing.');
      }
      return AppleIdTokenResult(identityToken: idToken, rawNonce: rawNonce);
    } on AppleSignInCancelledException {
      rethrow;
    } on AppleSignInFailedException {
      rethrow;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw AppleSignInCancelledException();
      }
      throw AppleSignInFailedException(error.message);
    } on SignInWithAppleException catch (error) {
      throw AppleSignInFailedException(error.toString());
    }
  }

  static Future<AuthorizationCredentialAppleID> _defaultCredentialFetcher(
    String hashedNonce,
  ) {
    return SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
  }
}

String generateAppleNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

String sha256Hex(String input) {
  return sha256.convert(utf8.encode(input)).toString();
}
