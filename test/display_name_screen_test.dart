import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/onboarding/basic_info_screen.dart';
import 'package:ayg/screens/settings/settings_basic_info_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthenticationRepository authRepository;
  late OpenFoodFactsService openFoodFactsService;

  setUp(() {
    authRepository = MockAuthenticationRepository();
    openFoodFactsService = OpenFoodFactsService(userAgent: 'test');
  });

  tearDown(() async {
    await authRepository.dispose();
  });

  Future<void> pumpBasicInfo(
    WidgetTester tester, {
    required AppController controller,
    required HealthProfileData healthPrefill,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BasicInfoScreen(
          controller: controller,
          openFoodFactsService: openFoodFactsService,
          healthPrefill: healthPrefill,
          authenticationRepository: authRepository,
        ),
      ),
    );
  }

  testWidgets('onboarding prefills a sign-in name and still asks for gender', (
    tester,
  ) async {
    authRepository.setCurrentUser(
      const AuthUser(
        id: 'user-1',
        email: 'a@example.com',
        suggestedDisplayName: '山田 太郎',
      ),
    );
    final controller = AppController();
    final birthDate = DateTime(1992, 5, 1);

    await pumpBasicInfo(
      tester,
      controller: controller,
      healthPrefill: HealthProfileData(
        birthDate: birthDate,
        gender: Gender.female,
        heightCm: 162,
        weightKg: 54,
      ),
    );

    expect(find.text('山田 太郎'), findsOneWidget);
    expect(find.text('性別'), findsOneWidget);
    expect(find.text('女性'), findsOneWidget);
    expect(find.text('男性'), findsOneWidget);
    expect(find.text('その他'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('profile_display_name')),
      '花子',
    );
    await tester.tap(find.text('次へ'));
    await tester.pump();

    expect(controller.profile?.displayName, '花子');
    expect(controller.profile?.gender, Gender.female);
    expect(controller.profile?.birthDate, birthDate);
  });

  testWidgets('onboarding leaves the name empty when sign-in has none', (
    tester,
  ) async {
    authRepository.setCurrentUser(
      const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController();

    await pumpBasicInfo(
      tester,
      controller: controller,
      healthPrefill: HealthProfileData(
        birthDate: DateTime(1992, 5, 1),
        gender: Gender.male,
        heightCm: 170,
        weightKg: 70,
      ),
    );

    expect(find.text(AppStrings.displayNameHint), findsOneWidget);
    expect(find.text('性別'), findsOneWidget);

    await tester.tap(find.text('次へ'));
    await tester.pump();

    expect(find.text(AppStrings.displayNameRequired), findsOneWidget);
    expect(controller.profile, isNull);
  });

  testWidgets('settings saves a changed name and keeps gender', (tester) async {
    final controller = AppController();
    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 175,
        weightKg: 75,
        displayName: '最初の名前',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => SettingsBasicInfoScreen(
                        controller: controller,
                        suggestedDisplayName: '連携の名前',
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('最初の名前'), findsOneWidget);
    expect(find.text(AppStrings.gender), findsOneWidget);
    expect(find.text('男性'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('profile_display_name')),
      '変えた名前',
    );
    await tester.ensureVisible(find.text('女性'));
    await tester.tap(find.text('女性'));
    await tester.ensureVisible(find.text(AppStrings.save));
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(controller.profile?.displayName, '変えた名前');
    expect(controller.profile?.gender, Gender.female);
    expect(controller.profile?.heightCm, 175);
  });

  testWidgets('settings prefills a sign-in name only when none is saved', (
    tester,
  ) async {
    final controller = AppController();
    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.other,
        heightCm: 168,
        weightKg: 60,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsBasicInfoScreen(
          controller: controller,
          suggestedDisplayName: '連携の名前',
        ),
      ),
    );

    expect(find.text('連携の名前'), findsOneWidget);
    expect(find.text('その他'), findsOneWidget);
  });
}
