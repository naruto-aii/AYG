import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/screens/shell/main_shell_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'prototype_ui5_fixtures.dart';

/// 中間幅（1024px）での Sidebar 切替・overflow 確認用。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main shell at 1024px uses sidebar without overflow', (
    tester,
  ) async {
    const size = Size(1024, 900);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = await createPrototypeUi5Controller();
    final authRepository = createPrototypeUi5AuthRepository();
    final openFoodFactsService = OpenFoodFactsService(
      userAgent: OpenFoodFactsConfig.userAgent,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(size: size),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: MainShellScreen(
              controller: controller,
              openFoodFactsService: openFoodFactsService,
              authenticationRepository: authRepository,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('ホーム'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
