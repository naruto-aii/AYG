import 'package:ayg/repositories/supabase_authentication_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  bool decide(Object error) =>
      SupabaseAuthenticationRepository.shouldSignOutAfterRefreshFailure(error);

  test('圏外や 5xx で起動してもログインを保つ', () {
    expect(decide(AuthRetryableFetchException()), isFalse);
    expect(
      decide(AuthRetryableFetchException(message: 'x', statusCode: '0')),
      isFalse,
    );
    expect(decide(const AuthApiException('down', statusCode: '503')), isFalse);
    expect(decide(const AuthApiException('slow', statusCode: '408')), isFalse);
    expect(decide(const AuthApiException('many', statusCode: '429')), isFalse);
    expect(decide(const AuthException('no status')), isFalse);
    expect(decide(Exception('SocketException: Failed host lookup')), isFalse);
  });

  test('サーバーがトークンを拒んだときだけログアウトする', () {
    expect(
      decide(
        const AuthApiException(
          'Invalid Refresh Token: Refresh Token Not Found',
          statusCode: '400',
          code: 'refresh_token_not_found',
        ),
      ),
      isTrue,
    );
    expect(decide(const AuthApiException('expired', statusCode: '401')), isTrue);
    expect(decide(const AuthApiException('gone', statusCode: '403')), isTrue);
    expect(decide(AuthSessionMissingException()), isTrue);
  });
}
