import 'package:ayg/repositories/apple_sign_in_client.dart';
import 'package:ayg/repositories/auth_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  test('sha256Hex is stable', () {
    expect(
      sha256Hex('nonce-value'),
      'efb4e26c3deb3dd5e04408769d1b6b371ae1e7acbe1e32332550b06f784780f2',
    );
  });

  test('generateAppleNonce is 32 url-safe characters', () {
    final nonce = generateAppleNonce();
    expect(nonce.length, 32);
    expect(RegExp(r'^[0-9A-Za-z\-._]+$').hasMatch(nonce), isTrue);
  });

  test('fetchIdToken returns identity token and raw nonce', () async {
    const rawNonce = 'raw-nonce-value';
    var seenHashedNonce = '';
    final client = AppleSignInClient(
      nonceFactory: () => rawNonce,
      credentialFetcher: (hashedNonce) async {
        seenHashedNonce = hashedNonce;
        return const AuthorizationCredentialAppleID(
          userIdentifier: 'user-1',
          givenName: null,
          familyName: null,
          email: 'a@example.com',
          identityToken: 'apple-id-token',
          authorizationCode: 'code',
          state: null,
        );
      },
    );

    final result = await client.fetchIdToken();

    expect(result.identityToken, 'apple-id-token');
    expect(result.rawNonce, rawNonce);
    expect(seenHashedNonce, sha256Hex(rawNonce));
  });

  test('missing identity token fails', () async {
    final client = AppleSignInClient(
      nonceFactory: () => 'raw',
      credentialFetcher: (_) async {
        return const AuthorizationCredentialAppleID(
          userIdentifier: 'user-1',
          givenName: null,
          familyName: null,
          email: null,
          identityToken: null,
          authorizationCode: 'code',
          state: null,
        );
      },
    );

    expect(
      client.fetchIdToken(),
      throwsA(isA<AppleSignInFailedException>()),
    );
  });

  test('canceled Apple sheet is not a failure', () async {
    final client = AppleSignInClient(
      nonceFactory: () => 'raw',
      credentialFetcher: (_) async {
        throw const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'canceled',
        );
      },
    );

    expect(
      client.fetchIdToken(),
      throwsA(isA<AppleSignInCancelledException>()),
    );
  });
}
