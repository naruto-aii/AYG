import 'package:ayg/services/cook_coach_client.dart';
import 'package:ayg/services/photo_meal_client.dart';
import 'package:ayg/services/plus_gate_retry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:functions_client/functions_client.dart';

void main() {
  tearDown(() => PlusGateRetry.bind(null));

  test('not_plus syncs once when a local product is valid, then retries', () async {
    var calls = 0;
    var syncs = 0;
    PlusGateRetry.bind(() async {
      syncs += 1;
      return true;
    });
    final result = await PlusGateRetry.callOnce(() async {
      calls += 1;
      if (calls == 1) {
        throw const FunctionException(
          status: 403,
          details: {'code': 'not_plus', 'message': 'こちらはカロナビ+の機能です。'},
        );
      }
      return {'ok': true};
    });
    expect(syncs, 1);
    expect(calls, 2);
    expect(result, {'ok': true});
  });

  test('not_plus without a local product is not retried', () async {
    var calls = 0;
    PlusGateRetry.bind(() async => false);
    expect(
      () => PlusGateRetry.callOnce(() async {
        calls += 1;
        throw const FunctionException(status: 403, details: {'code': 'not_plus'});
      }),
      throwsA(isA<FunctionException>()),
    );
    expect(calls, 1);
  });

  test('a temporary 503 from the Plus check is shown as try-again, not as not_plus', () async {
    const photoBody = {
      'ok': false,
      'code': 'provider_error',
      'message': '推定できませんでした。しばらくしてからもう一度試すか、手入力で記録できます。',
    };
    const cookBody = {
      'ok': false,
      'code': 'provider_error',
      'message': '献立を作れませんでした。しばらくしてからもう一度試してください。',
    };
    var syncs = 0;
    var calls = 0;
    PlusGateRetry.bind(() async {
      syncs += 1;
      return true;
    });
    for (final body in [photoBody, cookBody]) {
      expect(PlusGateRetry.isNotPlus(body), isFalse);
      await expectLater(
        PlusGateRetry.callOnce(() async {
          calls += 1;
          throw FunctionException(status: 503, details: body);
        }),
        throwsA(isA<FunctionException>()),
      );
    }
    expect(syncs, 0);
    expect(calls, 2);
    // 写真で登録と AIで探すは photoMealMessageFromBody、自炊コーチは cookCoachMessageFromBody で表示する。
    expect(photoMealMessageFromBody(photoBody), contains('しばらくしてから'));
    expect(photoMealMessageFromBody('{"ok":false,"code":"provider_error","message":"推定できませんでした。しばらくしてからもう一度試すか、手入力で記録できます。"}'), contains('しばらくしてから'));
    expect(cookCoachMessageFromBody(cookBody), contains('しばらくしてから'));
    expect(cookCoachCodeFromBody(cookBody), 'provider_error');
  });
}
