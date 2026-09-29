import 'package:ayg/models/food_rating.dart';
import 'package:ayg/models/food_report.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/contracts/blocked_food_creator_repository_base.dart';
import 'package:ayg/repositories/contracts/food_rating_repository_base.dart';
import 'package:ayg/repositories/contracts/food_report_repository_base.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';

class _FakeRatingRepo implements FoodRatingRepositoryBase {
  final summaries = <String, FoodRatingSummary>{};
  final myRatings = <String, MyFoodRating>{};
  int setGoodCalls = 0;

  String key(String owner, String food, String rater) => '$owner:$food:$rater';

  @override
  Future<void> clearRating({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
  }) async {
    myRatings.remove(key(foodOwnerUserId, foodId, raterUserId));
  }

  @override
  Future<FoodRatingSummary?> getSummary({
    required String foodOwnerUserId,
    required String foodId,
  }) async => summaries['$foodOwnerUserId:$foodId'];

  @override
  Future<MyFoodRating?> getMyRating({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
  }) async => myRatings[key(foodOwnerUserId, foodId, raterUserId)];

  @override
  Future<void> setBad({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
    required String ratingId,
  }) async {
    myRatings[key(foodOwnerUserId, foodId, raterUserId)] = MyFoodRating(
      ratingId: ratingId,
      foodOwnerUserId: foodOwnerUserId,
      foodId: foodId,
      ratingType: FoodRatingType.bad,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> setGood({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
    required String ratingId,
  }) async {
    setGoodCalls += 1;
    myRatings[key(foodOwnerUserId, foodId, raterUserId)] = MyFoodRating(
      ratingId: ratingId,
      foodOwnerUserId: foodOwnerUserId,
      foodId: foodId,
      ratingType: FoodRatingType.good,
      updatedAt: DateTime.now(),
    );
  }
}

class _FakeReportRepo implements FoodReportRepositoryBase {
  final reports = <FoodReport>[];

  @override
  Future<List<FoodReport>> getMyReports(String reporterUserId) async => reports
      .where((report) => report.reporterUserId == reporterUserId)
      .toList();

  @override
  Future<FoodReport> submitReport({
    required String reportId,
    required String reporterUserId,
    required String targetFoodOwnerUserId,
    required String targetFoodId,
    required FoodReportReasonCode reasonCode,
    String? detailText,
  }) async {
    final report = FoodReport(
      reportId: reportId,
      reporterUserId: reporterUserId,
      targetFoodOwnerUserId: targetFoodOwnerUserId,
      targetFoodId: targetFoodId,
      reasonCode: reasonCode,
      detailText: detailText,
      createdAt: DateTime.now(),
    );
    reports.add(report);
    return report;
  }
}

class _FakeBlockedRepo implements BlockedFoodCreatorRepositoryBase {
  final blocked = <String>{};

  @override
  Future<void> block({
    required String blockerUserId,
    required String blockedUserId,
  }) async {
    blocked.add(blockedUserId);
  }

  @override
  Future<List<String>> getBlockedUserIds(String blockerUserId) async =>
      blocked.toList();

  @override
  Future<bool> isBlocked({
    required String blockerUserId,
    required String blockedUserId,
  }) async => blocked.contains(blockedUserId);

  @override
  Future<void> unblock({
    required String blockerUserId,
    required String blockedUserId,
  }) async {
    blocked.remove(blockedUserId);
  }
}

SavedFood publicFood({required String ownerUserId, String foodId = 'food-1'}) {
  final now = DateTime(2026, 7, 20);
  return SavedFood(
    foodId: foodId,
    ownerUserId: ownerUserId,
    name: 'Public Food',
    normalizedName: 'public food',
    baseAmount: 100,
    unitType: FoodUnitType.g,
    kcalPerBase: 100,
    visibility: FoodVisibility.public,
    status: FoodStatus.active,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('AppController public food moderation', () {
    late _FakeRatingRepo ratingRepo;
    late _FakeReportRepo reportRepo;
    late _FakeBlockedRepo blockedRepo;
    late MockAuthenticationRepository authRepo;

    setUp(() {
      ratingRepo = _FakeRatingRepo();
      reportRepo = _FakeReportRepo();
      blockedRepo = _FakeBlockedRepo();
      authRepo = MockAuthenticationRepository(
        currentUser: const AuthUser(
          id: 'test-user-id',
          email: 'test@example.com',
        ),
      );
    });

    AppController controller() {
      return AppController(
        authenticationRepository: authRepo,
        foodRatingRepository: ratingRepo,
        foodReportRepository: reportRepo,
        blockedCreatorRepository: blockedRepo,
      );
    }

    test('setPublicFoodGood rejects self rating', () async {
      final food = publicFood(ownerUserId: 'test-user-id');
      final result = await controller().setPublicFoodGood(food);
      expect(result.success, isFalse);
      expect(ratingRepo.setGoodCalls, 0);
    });

    test('setPublicFoodGood and clear rating', () async {
      ratingRepo.summaries['other:food-1'] = FoodRatingSummary(
        foodOwnerUserId: 'other',
        foodId: 'food-1',
        goodCount: 0,
        badCount: 0,
        updatedAt: DateTime.now(),
      );
      final food = publicFood(ownerUserId: 'other');
      final ctrl = controller();
      final good = await ctrl.setPublicFoodGood(food);
      expect(good.success, isTrue);
      expect(good.view?.myRating, FoodRatingType.good);

      final cleared = await ctrl.clearPublicFoodRating(food);
      expect(cleared.success, isTrue);
      expect(cleared.view?.myRating, isNull);
    });

    test('setPublicFoodBad switches from good', () async {
      final food = publicFood(ownerUserId: 'other');
      final ctrl = controller();
      await ctrl.setPublicFoodGood(food);
      final bad = await ctrl.setPublicFoodBad(food);
      expect(bad.success, isTrue);
      expect(bad.view?.myRating, FoodRatingType.bad);
    });

    test('duplicate in-flight rating rejected', () async {
      final food = publicFood(ownerUserId: 'other');
      final ctrl = controller();
      final first = ctrl.setPublicFoodGood(food);
      final second = await ctrl.setPublicFoodGood(food);
      await first;
      expect(second.success, isFalse);
    });

    test('submitPublicFoodReport rejects self report', () async {
      final food = publicFood(ownerUserId: 'test-user-id');
      final result = await controller().submitPublicFoodReport(
        food: food,
        reasonCode: FoodReportReasonCode.spam,
      );
      expect(result.success, isFalse);
    });

    test('submitPublicFoodReport rejects duplicate report', () async {
      final food = publicFood(ownerUserId: 'other');
      final ctrl = controller();
      final first = await ctrl.submitPublicFoodReport(
        food: food,
        reasonCode: FoodReportReasonCode.spam,
      );
      expect(first.success, isTrue);
      final second = await ctrl.submitPublicFoodReport(
        food: food,
        reasonCode: FoodReportReasonCode.duplicate,
      );
      expect(second.success, isFalse);
    });

    test('getMyPublicFoodReports returns only own reports', () async {
      reportRepo.reports.addAll([
        FoodReport(
          reportId: 'r1',
          reporterUserId: 'test-user-id',
          targetFoodOwnerUserId: 'other',
          targetFoodId: 'food-1',
          reasonCode: FoodReportReasonCode.spam,
          createdAt: DateTime.now(),
        ),
        FoodReport(
          reportId: 'r2',
          reporterUserId: 'someone-else',
          targetFoodOwnerUserId: 'other',
          targetFoodId: 'food-2',
          reasonCode: FoodReportReasonCode.spam,
          createdAt: DateTime.now(),
        ),
      ]);

      final reports = await controller().getMyPublicFoodReports();
      expect(reports, hasLength(1));
      expect(reports.first.reportId, 'r1');
    });

    test('block and unblock creator', () async {
      final ctrl = controller();
      await ctrl.blockFoodCreator('creator-1');
      expect(await ctrl.isFoodCreatorBlocked('creator-1'), isTrue);
      await ctrl.unblockFoodCreator('creator-1');
      expect(await ctrl.isFoodCreatorBlocked('creator-1'), isFalse);
    });

    test('block self rejected', () async {
      expect(
        () => controller().blockFoodCreator('test-user-id'),
        throwsStateError,
      );
    });
  });
}
