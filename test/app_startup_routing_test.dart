import 'package:ayg/app.dart';
import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OpenFoodFactsService createOpenFoodFactsService() {
    return OpenFoodFactsService(userAgent: OpenFoodFactsConfig.userAgent);
  }

  testWidgets('sync failure shows retry screen not onboarding', (tester) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(
        id: 'test-user-id',
        email: 'test@example.com',
      ),
    );
    final dataSyncRepository = MockDataSyncRepository()..failPull = true;
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      authenticationRepository: authRepository,
      dataSyncRepository: dataSyncRepository,
    );

    await controller.initialize();
    await tester.pumpWidget(
      AygApp(
        controller: controller,
        openFoodFactsService: createOpenFoodFactsService(),
        healthRepository: MockHealthRepository(isAvailable: false),
        authenticationRepository: authRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('データの取得に失敗しました'), findsOneWidget);
    expect(find.text('Health連携'), findsNothing);

    await authRepository.dispose();
  });

  testWidgets('authenticated user with incomplete sync does not show login',
      (tester) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(
        id: 'test-user-id',
        email: 'test@example.com',
      ),
    );
    final dataSyncRepository = MockDataSyncRepository()..failPull = true;
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      authenticationRepository: authRepository,
      dataSyncRepository: dataSyncRepository,
    );

    await controller.initialize();
    await tester.pumpWidget(
      AygApp(
        controller: controller,
        openFoodFactsService: createOpenFoodFactsService(),
        healthRepository: MockHealthRepository(isAvailable: false),
        authenticationRepository: authRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Googleでログイン'), findsNothing);

    await authRepository.dispose();
  });
}
