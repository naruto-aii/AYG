import 'package:ayg/models/saved_food_persistence_error.dart';
import 'package:ayg/utils/user_facing_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user-facing errors do not include exception text', () {
    final raw = Exception('PostgrestException(message: permission denied)');
    final message = userFacingErrorMessage(
      raw,
      fallback: '処理に失敗しました。時間をおいて再度お試しください。',
    );
    expect(message, '処理に失敗しました。時間をおいて再度お試しください。');
    expect(message.contains('Postgrest'), isFalse);
    expect(message.contains('Exception'), isFalse);

    final saved = SavedFoodPersistenceException(
      errorCode: SavedFoodErrorCode.networkFailed,
      message: 'SocketException: Failed host lookup',
    );
    expect(
      userFacingErrorMessage(saved, fallback: 'unused'),
      '通信に失敗しました。ネットワークを確認して再度お試しください。',
    );
  });
}
