import 'dart:async';

import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/public_food_publish_match.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/contracts/saved_food_local_store.dart';
import 'package:ayg/repositories/contracts/saved_food_remote_store.dart';
import 'package:ayg/repositories/exceptions/food_master_exceptions.dart';
import 'package:ayg/repositories/synced_saved_food_repository.dart';
import 'package:ayg/screens/saved_food/publish_saved_food_confirmation_screen.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SavedFood _food({String id = 'food-1'}) {
  return SavedFood(
    foodId: id,
    ownerUserId: AppController.localOwnerUserId,
    name: 'テスト食品',
    normalizedName: 'test food',
    baseAmount: 100,
    unitType: FoodUnitType.g,
    servingUnitLabel: 'g',
    kcalPerBase: 165,
    proteinPerBase: 10,
    fatPerBase: 5,
    carbPerBase: 20,
    visibility: FoodVisibility.private,
    status: FoodStatus.active,
    sourceType: FoodSourceType.manual,
    createdAt: DateTime.utc(2026, 7, 20),
    updatedAt: DateTime.utc(2026, 7, 20),
  );
}

class _SlowPublishRemote implements SavedFoodRemoteStore {
  _SlowPublishRemote(this.completer);

  final Completer<void> completer;

  @override
  Future<SavedFood> publish({
    required String userId,
    required String foodId,
  }) async {
    await completer.future;
    return _food(id: foodId).copyWith(visibility: FoodVisibility.public);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocal implements SavedFoodLocalStore {
  SavedFood? stored;

  @override
  Future<SavedFood?> getOwn({
    required String ownerUserId,
    required String foodId,
  }) async => stored;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PublishSavedFoodConfirmationScreen', () {
    late AppController controller;

    setUp(() {
      final local = _FakeLocal()..stored = _food();
      controller = AppController(
        savedFoodRepository: SyncedSavedFoodRepository(
          local: local,
          remote: _SlowPublishRemote(Completer<void>()),
        ),
      );
    });

    tearDown(() => controller.dispose());

    testWidgets('publish button disabled until confirmation checked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PublishSavedFoodConfirmationScreen(
            controller: controller,
            food: _food(),
            validationErrors: const [],
            manualMacroConsistent: true,
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('入力した食品情報と栄養値が正しいことを確認しました'),
        200,
      );
      expect(find.widgetWithText(FilledButton, '公開する'), findsOneWidget);
      final publishButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '公開する'),
      );
      expect(publishButton.onPressed, isNull);

      await tester.tap(find.text('入力した食品情報と栄養値が正しいことを確認しました'));
      await tester.pumpAndSettle();

      final enabledButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '公開する'),
      );
      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets('duplicate blocks publish button', (WidgetTester tester) async {
      final duplicate = PublicFoodPublishMatch(
        food: _food(
          id: 'dup',
        ).copyWith(visibility: FoodVisibility.public, name: '既存'),
        goodCount: 1,
        badCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PublishSavedFoodConfirmationScreen(
            controller: controller,
            food: _food(),
            duplicate: duplicate,
            validationErrors: const [],
            manualMacroConsistent: true,
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, '公開する'),
        200,
      );

      final publishButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '公開する'),
      );
      expect(publishButton.onPressed, isNull);
      expect(find.text('完全重複'), findsOneWidget);
    });

    testWidgets('similar foods still allow publish after confirmation', (
      WidgetTester tester,
    ) async {
      final similar = PublicFoodSimilarMatch(
        food: _food(
          id: 'similar',
        ).copyWith(visibility: FoodVisibility.public, baseAmount: 200),
        goodCount: 0,
        badCount: 1,
        reason: PublicFoodSimilarReason.sameNameDifferentAmount,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PublishSavedFoodConfirmationScreen(
            controller: controller,
            food: _food(),
            similarFoods: [similar],
            validationErrors: const [],
            manualMacroConsistent: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('入力した食品情報と栄養値が正しいことを確認しました'),
        200,
      );
      await tester.tap(find.text('入力した食品情報と栄養値が正しいことを確認しました'));
      await tester.pumpAndSettle();

      final publishButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '公開する'),
      );
      expect(publishButton.onPressed, isNotNull);
      expect(find.textContaining('名称一致'), findsOneWidget);
    });

    testWidgets('RPC failure shows user message and keeps retry enabled', (
      WidgetTester tester,
    ) async {
      final local = _FakeLocal()..stored = _food();
      final failingController = AppController(
        savedFoodRepository: SyncedSavedFoodRepository(
          local: local,
          remote: _FailingPublishRemote(),
        ),
      );
      addTearDown(failingController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: PublishSavedFoodConfirmationScreen(
            controller: failingController,
            food: _food(),
            validationErrors: const [],
            manualMacroConsistent: true,
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('入力した食品情報と栄養値が正しいことを確認しました'),
        200,
      );
      await tester.tap(find.text('入力した食品情報と栄養値が正しいことを確認しました'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '公開する'));
      await tester.pumpAndSettle();

      expect(find.text('同じ食品名・基準量・単位の公開食品がすでにあります'), findsOneWidget);
      final retryButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '公開する'),
      );
      expect(retryButton.onPressed, isNotNull);
    });
  });
}

class _FailingPublishRemote implements SavedFoodRemoteStore {
  @override
  Future<SavedFood> publish({required String userId, required String foodId}) {
    throw const PublishSavedFoodException(
      kind: PublishFailureKind.duplicate,
      message: 'duplicate public food exists',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
