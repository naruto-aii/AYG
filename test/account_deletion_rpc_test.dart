import 'package:ayg/repositories/account_deletion_rpc.dart';
import 'package:ayg/repositories/auth_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('success without a revoke flag leaves the apple flag false', () {
    final outcome = accountDeletionOutcomeFromResponse(200, {'ok': true});
    expect(outcome.appleRevokeFailed, isFalse);
  });

  test('a stored apple token that could not be revoked is reported', () {
    final outcome = accountDeletionOutcomeFromResponse(200, {
      'ok': true,
      'apple_revoke_failed': true,
    });
    expect(outcome.appleRevokeFailed, isTrue);
  });

  test('missing function and other failures do not look like success', () {
    expect(
      () => accountDeletionOutcomeFromResponse(404, null),
      throwsA(isA<AccountDeletionUnavailableException>()),
    );
    expect(
      () => accountDeletionOutcomeFromResponse(500, {'ok': false}),
      throwsA(isA<AccountDeletionFailedException>()),
    );
    expect(
      () => accountDeletionOutcomeFromResponse(200, {'ok': false}),
      throwsA(isA<AccountDeletionFailedException>()),
    );
  });
}
