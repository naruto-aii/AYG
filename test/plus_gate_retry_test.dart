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
}
