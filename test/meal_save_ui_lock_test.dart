import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/official_food.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/contracts/food_repository_base.dart';
import 'package:ayg/screens/official_food/official_food_detail_screen.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saving one meal does not reload or upload every meal', () async {
    final foods = _ThrowingLoadAllFoodRepository();
    final sync = MockDataSyncRepository();
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      authenticationRepository: MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'user@example.com'),
      ),
      dataSyncRepository: sync,
      foodRepository: foods,
    );
    addTearDown(controller.dispose);

    await controller.handleAuthenticatedSession();
    expect(foods.loadAllCalls, 0);

    final older = _meal('older', DateTime(2026, 10, 1, 8));
    final newer = _meal('newer', DateTime(2026, 10, 1, 12));
    await controller.addFood(older);
    await controller.addFood(newer);

    expect(foods.loadAllCalls, 0);
    expect(foods.saved.map((entry) => entry.id), ['older', 'newer']);
    expect(controller.foodEntries.map((entry) => entry.id), ['newer', 'older']);
    expect(sync.pushLocalToRemoteCalled, isFalse);
    expect(sync.pushedFoodEntryIds, ['older', 'newer']);
    expect(sync.lastUserId, 'user-1');
  });

  testWidgets('この量で食事に記録 keeps the entered grams without loading every meal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final foods = _ThrowingLoadAllFoodRepository();
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      foodRepository: foods,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => openOfficialFoodDetail(
                context,
                controller,
                const OfficialFoodMatch(
                  foodCode: '01088',
                  name: 'こめ　［水稲めし］　精白米　うるち米',
                  displayName: '精白米',
                  kcal: 156,
                  proteinG: 2.5,
                  fatG: 0.3,
                  carbG: 37.1,
                ),
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('official_food_grams')),
      '250',
    );
    await tester.tap(find.text('この量で食事に記録'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(foods.loadAllCalls, 0);
    expect(find.textContaining('記録に失敗しました'), findsNothing);
    expect(controller.foodEntries, hasLength(1));
    expect(controller.foodEntries.single.consumedAmount, 250);
    expect(controller.foodEntries.single.name, '精白米');
    expect(foods.saved, hasLength(1));
  });
}

FoodEntry _meal(String id, DateTime loggedAt) {
  return FoodEntry(
    id: id,
    name: id,
    kcalPerBase: 100,
    baseAmount: 100,
    consumedAmount: 100,
    loggedAt: loggedAt,
  );
}

class _ThrowingLoadAllFoodRepository implements FoodRepositoryBase {
  int loadAllCalls = 0;
  final List<FoodEntry> saved = [];

  @override
  Future<void> save(FoodEntry entry) async {
    saved.removeWhere((item) => item.id == entry.id);
    saved.add(entry);
  }

  @override
  Future<void> saveAll(List<FoodEntry> entries) async {
    for (final entry in entries) {
      await save(entry);
    }
  }

  @override
  Future<List<FoodEntry>> loadAll() async {
    loadAllCalls++;
    throw StateError('loadAll');
  }

  @override
  Future<void> delete(String entryId) async {
    saved.removeWhere((entry) => entry.id == entryId);
  }

  @override
  Future<void> clearAll() async {
    saved.clear();
  }
}
