import 'package:ayg/screens/settings/ai_sending_switch.dart';
import 'package:ayg/services/ai_data_consent.dart';
import 'package:ayg/services/photo_meal_client.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AiDataConsent.override = null;
  });

  testWidgets('the settings switch turns AI sending off and blocks a send', (
    tester,
  ) async {
    final memory = MemoryAiDataConsent(granted: true, synced: true);
    AiDataConsent.override = memory;

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const Scaffold(body: AiSendingSwitch())),
    );
    await tester.pumpAndSettle();

    expect(find.text('AIへの送信'), findsOneWidget);
    expect(find.textContaining('手入力の記録はそのまま使えます'), findsOneWidget);
    expect(memory.sendingEnabled, isTrue);
    await ensureAiSendingEnabled();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(memory.sendingEnabled, isFalse);
    expect(
      ensureAiSendingEnabled,
      throwsA(
        isA<PhotoMealFailure>().having(
          (error) => error.message,
          'message',
          aiSendingOffMessage,
        ),
      ),
    );
  });

  testWidgets('a failed save leaves AI sending on', (tester) async {
    final memory = MemoryAiDataConsent(
      granted: true,
      synced: true,
      failGrant: true,
    );
    AiDataConsent.override = memory;

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const Scaffold(body: AiSendingSwitch())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(memory.sendingEnabled, isTrue);
    expect(find.textContaining('保存できませんでした'), findsOneWidget);
  });
}
