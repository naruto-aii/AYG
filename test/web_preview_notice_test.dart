import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/widgets/web/web_preview_notice.dart';

void main() {
  testWidgets('full notice lists web-only gaps', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebPreviewNotice())),
    );

    expect(find.text(AppStrings.webPreviewTitle), findsOneWidget);
    expect(find.textContaining('Health 連携'), findsOneWidget);
    expect(find.textContaining('Sign in with Apple'), findsOneWidget);
    expect(find.textContaining('アプリ内課金'), findsOneWidget);
  });

  testWidgets('compact notice stays on one summary line', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebPreviewNotice(compact: true)),
      ),
    );

    expect(find.text(AppStrings.webPreviewUnavailableSummary), findsOneWidget);
  });
}
