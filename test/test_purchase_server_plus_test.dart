import 'package:ayg/repositories/storekit_subscription_repository.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 入れ直した直後、テスト用の有料切替は未設定。サーバで有料ならアプリも有料に見せる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<StoreKitSubscriptionRepository> open(
    Map<String, Object> prefs, {
    bool testPurchaseEnabled = true,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final repository = StoreKitSubscriptionRepository(
      preferences: await SharedPreferences.getInstance(),
      purchaseUpdates: const Stream.empty(),
      loadEntitlements: () async =>
          const EntitlementLoad(records: [], authoritative: true),
      clock: () => DateTime.utc(2026, 10, 9),
      testPurchaseEnabled: testPurchaseEnabled,
    );
    await repository.initialize();
    return repository;
  }

  test(
    'after a reinstall, server plus shows as plus without writing the switch',
    () async {
      final repository = await open({});
      final changes = <bool>[];
      final sub = repository.plusChanges.listen(changes.add);
      expect(repository.isPlusActive, isFalse);
      repository.adoptServerPlusForTest(true);
      await Future<void>.delayed(Duration.zero);
      expect(repository.isPlusActive, isTrue);
      expect(changes, [true]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StoreKitSubscriptionRepository.testPlusKey), isNull);
      await sub.cancel();
    },
  );

  test('a switch the tester turned off wins over the server', () async {
    final repository = await open({
      StoreKitSubscriptionRepository.testPlusKey: false,
    });
    repository.adoptServerPlusForTest(true);
    expect(repository.isPlusActive, isFalse);
  });

  test('server free keeps the app free', () async {
    final repository = await open({});
    repository.adoptServerPlusForTest(false);
    expect(repository.isPlusActive, isFalse);
  });

  test('a store build without the test flag ignores it', () async {
    final repository = await open({}, testPurchaseEnabled: false);
    repository.adoptServerPlusForTest(true);
    expect(repository.isPlusActive, isFalse);
  });

  test('logging out or switching account drops the adopted server plus', () async {
    final repository = await open({});
    repository.bindStoreAccountToken('owner');
    repository.adoptServerPlusForTest(true);
    expect(repository.isPlusActive, isTrue);
    // 同じ人の再同期では外さない。
    repository.bindStoreAccountToken('OWNER');
    expect(repository.isPlusActive, isTrue);
    // 別の人に切り替えたら外す。
    repository.bindStoreAccountToken('someone-else');
    expect(repository.isPlusActive, isFalse);
    expect(repository.confirmedEntitlements, isEmpty);

    repository.bindStoreAccountToken('owner');
    repository.adoptServerPlusForTest(true);
    expect(repository.isPlusActive, isTrue);
    repository.forgetServerPlusForTest();
    expect(repository.isPlusActive, isFalse);
  });

  test('a switch the tester turned on survives a logout', () async {
    final repository = await open({
      StoreKitSubscriptionRepository.testPlusKey: true,
    });
    repository.forgetServerPlusForTest();
    repository.bindStoreAccountToken('someone-else');
    expect(repository.isPlusActive, isTrue);
  });
}
