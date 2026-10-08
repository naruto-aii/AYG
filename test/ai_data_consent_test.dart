import 'dart:io';
import 'dart:typed_data';

import 'package:ayg/screens/coach/cook_coach_screen.dart';
import 'package:image/image.dart' as img;
import 'package:ayg/screens/food/ai_food_lookup_screen.dart';
import 'package:ayg/screens/food/photo_meal_screen.dart';
import 'package:ayg/screens/legal/ai_data_consent_dialog.dart';
import 'package:ayg/screens/legal/legal_document_screen.dart';
import 'package:ayg/services/ai_data_consent.dart';
import 'package:ayg/services/ai_food_lookup_client.dart';
import 'package:ayg/services/cook_coach_client.dart';
import 'package:ayg/services/cook_coach_target.dart';
import 'package:ayg/services/photo_meal_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/utils/meal_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _jpeg() {
  final photo = img.Image(width: 8, height: 8);
  img.fill(photo, color: img.ColorRgb8(200, 120, 60));
  return Uint8List.fromList(img.encodeJpg(photo));
}

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

  test('production clients do not call the network before consent', () async {
    AiDataConsent.override = MemoryAiDataConsent();
    await expectLater(
      PhotoMealClient.supabase().analyze(
        jpeg: Uint8List.fromList(const [1, 2, 3]),
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
          aiDataConsentRequiredMessage,
        ),
      ),
    );
  });

  testWidgets('declining photo, lookup, and cook sends nothing', (tester) async {
    final memory = MemoryAiDataConsent();
    AiDataConsent.override = memory;
    var photoCalls = 0;
    var lookupCalls = 0;
    var cookCalls = 0;
    final controller = AppController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PhotoMealScreen(
          controller: controller,
          loggedAt: DateTime(2026, 10, 8, 12),
          initialJpeg: _jpeg(),
          client: PhotoMealClient(
            invoke: (_) async {
              photoCalls += 1;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('推定する'));
    await tester.pumpAndSettle();
    expect(find.text(aiDataConsentTitle), findsOneWidget);
    expect(find.textContaining('Anthropic, PBC（米国）'), findsOneWidget);
    expect(find.text(aiDataConsentStorage), findsOneWidget);
    expect(photoCalls, 0);
    await tester.tap(find.byKey(const Key('ai-data-consent-privacy')));
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(photoCalls, 0);
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-data-consent-decline')));
    await tester.pumpAndSettle();
    expect(photoCalls, 0);
    expect(memory.grantCalls, 0);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AiFoodLookupScreen(
                      controller: controller,
                      query: '牛丼',
                      loggedAt: DateTime(2026, 10, 8, 12),
                      client: AiFoodLookupClient(
                        invoke: (_) async {
                          lookupCalls += 1;
                          return null;
                        },
                      ),
                    ),
                  ),
                );
              },
              child: const Text('開く'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    expect(find.text(aiDataConsentAcceptLabel), findsOneWidget);
    expect(lookupCalls, 0);
    await tester.tap(find.byKey(const Key('ai-data-consent-decline')));
    await tester.pumpAndSettle();
    expect(lookupCalls, 0);
    expect(find.text('開く'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CookCoachScreen(
          now: DateTime(2026, 10, 8, 18),
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
          client: CookCoachClient(
            invoke: (_) async {
              cookCalls += 1;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cook_choice_卵')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cook_generate')));
    await tester.tap(find.byKey(const Key('cook_generate')));
    await tester.pumpAndSettle();
    expect(cookCalls, 0);
    await tester.tap(find.byKey(const Key('ai-data-consent-decline')));
    await tester.pumpAndSettle();
    expect(cookCalls, 0);
    expect(memory.grantCalls, 0);
  });

  testWidgets('agreeing saves consent and then calls the model', (tester) async {
    final memory = MemoryAiDataConsent();
    AiDataConsent.override = memory;
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CookCoachScreen(
          now: DateTime(2026, 10, 8, 18),
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
          client: CookCoachClient(
            invoke: (_) async {
              calls += 1;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cook_choice_卵')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cook_generate')));
    await tester.tap(find.byKey(const Key('cook_generate')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.byKey(const Key('ai-data-consent-accept')));
    await tester.pumpAndSettle();
    expect(memory.grantCalls, 1);
    expect(memory.isGranted, isTrue);
    expect(calls, 1);
  });

  testWidgets('a failed save does not call the model', (tester) async {
    final memory = MemoryAiDataConsent(failGrant: true);
    AiDataConsent.override = memory;
    var calls = 0;
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PhotoMealScreen(
          controller: controller,
          loggedAt: DateTime(2026, 10, 8, 12),
          initialJpeg: _jpeg(),
          client: PhotoMealClient(
            invoke: (_) async {
              calls += 1;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('推定する'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-data-consent-accept')));
    await tester.pumpAndSettle();
    expect(memory.grantCalls, 1);
    expect(calls, 0);
    expect(find.text(aiDataConsentSaveFailedMessage), findsOneWidget);
  });

  testWidgets('the dialog is the consent screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showAiDataConsentDialog(context),
              child: const Text('開く'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-data-consent-dialog')), findsOneWidget);
    expect(find.text(aiDataConsentBody), findsOneWidget);
    for (final line in aiDataConsentSends) {
      expect(find.text('・$line'), findsOneWidget);
    }
    expect(find.text(aiDataConsentAcceptLabel), findsOneWidget);
    expect(find.text(aiDataConsentDeclineLabel), findsOneWidget);
  });
}
