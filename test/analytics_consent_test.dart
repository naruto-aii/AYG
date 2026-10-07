import 'package:ayg/models/food_entry.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/services/analytics/analytics.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/analytics_test_support.dart';
import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'without consent nothing is queued, and paid features still run',
    () async {
      final isarHarness = await setUpIsarHarness();
      final analytics = await AnalyticsHarness.open(isar: isarHarness.isar);
      await analytics.service.track('food_entry_added', {
        'food_entry_ids': ['x'],
        'method': 'manual',
        'items_count': 1,
      });
      await analytics.service.settled;
      expect(await analytics.queue.count(), 0);

      await analytics.service.declineConsent(surface: 'first_launch');
      await analytics.service.track('app_open', {
        'launch_source': 'icon',
        'previous_session_abnormal_end': false,
      });
      await analytics.service.settled;
      expect(await analytics.queue.count(), 0);
      expect(analytics.bridge.consent, isFalse);

      final controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
        authenticationRepository: MockAuthenticationRepository(
          currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
        ),
        dataSyncRepository: MockDataSyncRepository(),
        foodRepository: isarHarness.foodRepository,
      );
      addTearDown(controller.dispose);
      await controller.addFood(
        FoodEntry(
          id: 'meal-1',
          name: 'ご飯',
          quantity: 1,
          loggedAt: DateTime.utc(2026, 10, 7),
        ),
      );
      expect(controller.foodEntries, hasLength(1));
      expect(await analytics.queue.count(), 0);

      await analytics.service.grantConsent(surface: 'settings');
      await analytics.service.setCurrentUser('user-1');
      await analytics.service.track('contact_tap', {'channel': 'settings'});
      await analytics.service.settled;
      expect(await analytics.queue.count(), greaterThan(0));
      await analytics.service.revokeConsent();
      expect(await analytics.queue.count(), 0);
      expect(analytics.service.consented, isFalse);
      expect(controller.foodEntries, hasLength(1));
      Analytics.service = null;
    },
  );
}
