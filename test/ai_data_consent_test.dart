import 'dart:io';
import 'dart:typed_data';

import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/screens/auth/login_screen.dart';
import 'package:ayg/services/ai_data_consent.dart';
import 'package:ayg/services/ai_food_lookup_client.dart';
import 'package:ayg/services/cook_coach_client.dart';
import 'package:ayg/services/cook_coach_target.dart';
import 'package:ayg/services/photo_meal_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/theme/app_typography.dart';
import 'package:ayg/utils/meal_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AiDataConsent.override = null;
  });

  test('camera and photo library purposes are already in Japanese', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>NSCameraUsageDescription</key>'));
    expect(plist, contains('食事の写真を撮って栄養を推定し、商品バーコードを読み取るためにカメラを使います。'));
    expect(plist, contains('食事の写真はカロナビに保存しません。'));
    expect(plist, contains('<key>NSPhotoLibraryUsageDescription</key>'));
    expect(plist, contains('カメラロールの食事の写真から栄養を推定するために使います。'));
    expect(plist, contains('選んだ写真はカロナビに保存しません。'));
  });

  test('consent version matches the server and the row is the user only', () {
    final shared = File(
      'supabase/functions/_shared/ai_data_consent.ts',
    ).readAsStringSync();
    expect(shared, contains('"$aiDataConsentVersion"'));
    expect(shared, contains(aiDataConsentRequiredMessage));
    final sql = File(
      'supabase/migrations/20261008210000_ai_data_consent.sql',
    ).readAsStringSync();
    expect(sql, contains('enable row level security'));
    expect(sql, contains('grant select, insert, update'));
    expect(sql, isNot(contains('grant delete')));
    expect(sql, contains('new.consented_at = timezone(\'utc\', now())'));
    expect(sql, contains('delete from public.ai_data_consents where user_id = new.id'));
    expect(
      File(
        'supabase/rollback/20261008210000_ai_data_consent_down.sql',
      ).readAsStringSync(),
      contains('drop table if exists public.ai_data_consents'),
    );
  });

  test('the login agreement is the AI consent and has no extra checkbox', () {
    final screen = File('lib/screens/auth/login_screen.dart').readAsStringSync();
    expect(screen, contains('AppStrings.loginAiDisclosureMultiline'));
    expect(screen, contains('AppTypography.caption'));
    expect(screen, isNot(contains('Checkbox')));
    expect(File('lib/screens/legal/ai_data_consent_dialog.dart').existsSync(), isFalse);
    expect(
      AppStrings.loginAiDisclosure.replaceAll('\n', ''),
      '写真で登録などのAI機能では、入力した内容を推定のためAnthropic, PBC（米国）に送ります。',
    );
    expect(
      AppStrings.loginAiDisclosureMultiline.replaceAll('\n', ''),
      AppStrings.loginAiDisclosure,
    );
    expect(AppStrings.loginLegalAgreement, contains('利用規約とプライバシーポリシー'));
    for (final path in [
      'lib/screens/food/photo_meal_screen.dart',
      'lib/screens/food/ai_food_lookup_screen.dart',
      'lib/screens/coach/cook_coach_screen.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('ensureAiDataConsent')),
        reason: path,
      );
    }
  });

  test('login records the agreement and a failed write stays local', () async {
    final memory = MemoryAiDataConsent(failGrant: true);
    AiDataConsent.override = memory;
    await AiDataConsent.recordLoginAgreement();
    expect(memory.isGranted, isTrue);
    expect(memory.synced, isFalse);
    expect(memory.grantCalls, 1);

    expect(await AiDataConsent.ensureServerCopy(), isFalse);
    expect(memory.grantCalls, 2);
    expect(memory.synced, isFalse);

    memory.failGrant = false;
    expect(await AiDataConsent.ensureServerCopy(), isTrue);
    expect(memory.grantCalls, 3);
    expect(memory.synced, isTrue);
    expect(await AiDataConsent.ensureServerCopy(), isTrue);
    expect(memory.grantCalls, 3);
  });

  test('production clients do not call the network before agreement', () async {
    final memory = MemoryAiDataConsent();
    AiDataConsent.override = memory;
    await expectLater(
      PhotoMealClient.supabase().analyze(
        jpeg: Uint8List(8),
        dishName: 'カレー',
        amount: '1皿',
      ),
      throwsA(
        isA<PhotoMealFailure>().having(
          (error) => error.message,
          'message',
          aiDataConsentRequiredMessage,
        ),
      ),
    );
    await expectLater(
      AiFoodLookupClient.supabase().lookup('牛丼'),
      throwsA(
        isA<PhotoMealFailure>().having(
          (error) => error.message,
          'message',
          aiDataConsentRequiredMessage,
        ),
      ),
    );
    await expectLater(
      CookCoachClient.supabase().generate(
        ingredients: const ['卵'],
        slot: MealSlot.dinner,
        target: const CookCoachMealTarget(
          slot: MealSlot.dinner,
          kcal: 650,
          proteinG: 32,
          fatG: 18,
          carbG: 75,
          remainingKcal: 650,
          remainingProteinG: 32,
          remainingFatG: 18,
          remainingCarbG: 75,
        ),
      ),
      throwsA(
        isA<CookCoachFailure>().having(
          (error) => error.message,
          'message',
          cookCoachFallbackMessage,
        ),
      ),
    );
    expect(memory.grantCalls, 0);
  });

  test('a failed resend does not call the model and shows no consent screen', () async {
    final memory = MemoryAiDataConsent(granted: true, failGrant: true);
    AiDataConsent.override = memory;
    await expectLater(
      PhotoMealClient.supabase().analyze(
        jpeg: Uint8List(8),
        dishName: 'カレー',
        amount: '1皿',
      ),
      throwsA(
        isA<PhotoMealFailure>().having(
          (error) => error.message,
          'message',
          photoMealFallbackMessage,
        ),
      ),
    );
    await expectLater(
      AiFoodLookupClient.supabase().lookup('牛丼'),
      throwsA(
        isA<PhotoMealFailure>().having(
          (error) => error.message,
          'message',
          photoMealFallbackMessage,
        ),
      ),
    );
    await expectLater(
      CookCoachClient.supabase().generate(
        ingredients: const ['卵'],
        slot: MealSlot.dinner,
        target: const CookCoachMealTarget(
          slot: MealSlot.dinner,
          kcal: 650,
          proteinG: 32,
          fatG: 18,
          carbG: 75,
          remainingKcal: 650,
          remainingProteinG: 32,
          remainingFatG: 18,
          remainingCarbG: 75,
        ),
      ),
      throwsA(
        isA<CookCoachFailure>().having(
          (error) => error.message,
          'message',
          cookCoachFallbackMessage,
        ),
      ),
    );
    // 自炊コーチは同意を見ないので、再送は写真とAIで探すの2回だけ。
    expect(memory.grantCalls, 2);
    expect(memory.synced, isFalse);
  });

  testWidgets('the login screen shows the Anthropic sentence in caption size', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    final repository = MockAuthenticationRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(
          controller: controller,
          authenticationRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.loginLegalAgreementMultiline), findsOneWidget);
    expect(find.text(AppStrings.loginAiDisclosureMultiline), findsOneWidget);
    expect(find.text('AI機能を使う前に'), findsNothing);
    expect(find.text('同意して使う'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    final disclosure = tester.widget<Text>(
      find.text(AppStrings.loginAiDisclosureMultiline),
    );
    final agreement = tester.widget<Text>(
      find.text(AppStrings.loginLegalAgreementMultiline),
    );
    expect(disclosure.style?.fontSize, AppTypography.caption.fontSize);
    expect(disclosure.style?.fontSize, agreement.style?.fontSize);
    expect(find.text('利用規約'), findsOneWidget);
    expect(find.text('プライバシーポリシー'), findsOneWidget);
  });
}
