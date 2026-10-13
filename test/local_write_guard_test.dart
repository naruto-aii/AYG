import 'package:ayg/models/food_entry.dart';
import 'package:ayg/repositories/local_write_guard.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isar_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'replaceAll does not clear the table when the generation does not match',
    () async {
      final harness = await setUpIsarHarness();
      final foods = harness.foodRepository;
      final kept = FoodEntry(
        id: 'kept',
        name: 'ご飯',
        kcalPerBase: 200,
        loggedAt: DateTime(2026, 10, 10, 12),
      );
      await foods.save(kept);

      await foods.replaceAll([
        FoodEntry(
          id: 'stale',
          name: '古いスナップショット',
          kcalPerBase: 1,
          loggedAt: DateTime(2026, 10, 9, 12),
        ),
      ], mayWrite: () => false);

      final afterReject = await foods.loadAll();
      expect(afterReject.map((entry) => entry.id), ['kept']);
      expect(afterReject.single.name, 'ご飯');

      await foods.replaceAll([
        FoodEntry(
          id: 'fresh',
          name: '新しい同期',
          kcalPerBase: 300,
          loggedAt: DateTime(2026, 10, 10, 18),
        ),
      ], mayWrite: () => true);

      final afterAllow = await foods.loadAll();
      expect(afterAllow.map((entry) => entry.id), ['fresh']);
      expect(localWriteAllowed(null), isTrue);
    },
  );
}
