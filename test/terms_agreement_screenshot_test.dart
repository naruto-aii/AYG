import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/legal/terms_agreement_screen.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';

Future<void> _loadFonts() async {
  final zen = FontLoader('ZenMaruGothic');
  for (final path in const [
    'assets/fonts/ZenMaruGothic-Regular.ttf',
    'assets/fonts/ZenMaruGothic-Medium.ttf',
    'assets/fonts/ZenMaruGothic-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    zen.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await zen.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('terms agreement on iPhone and iPad', (tester) async {
    final directory = Directory('/opt/cursor/artifacts/screenshots')
      ..createSync(recursive: true);

    Future<void> shoot(Size logical, double ratio, String name) async {
      await tester.binding.setSurfaceSize(logical);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.physicalSize = Size(logical.width * ratio, logical.height * ratio);
      tester.view.devicePixelRatio = ratio;
      tester.view.padding = FakeViewPadding.zero;
      tester.view.viewPadding = FakeViewPadding.zero;
      tester.view.viewInsets = FakeViewPadding.zero;
      addTearDown(tester.view.reset);

      final controller = AppController();
      addTearDown(controller.dispose);
      final repository = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'new-user', email: 'a@example.com'),
      );
      addTearDown(repository.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: TermsAgreementScreen(
              controller: controller,
              authenticationRepository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.termsConsentAi), findsOneWidget);
      expect(find.text(AppStrings.termsConsentUgc), findsOneWidget);
      expect(find.text(AppStrings.termsConsentAgree), findsOneWidget);

      final bytes = await tester.runAsync(
        () => pngBytesFromBoundary(key, pixelRatio: ratio),
      );
      expect(bytes, isNotNull);
      File('${directory.path}/$name').writeAsBytesSync(bytes!);
      final image = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final shot = frame.image;
        codec.dispose();
        return shot;
      });
      expect(image!.width, (logical.width * ratio).round());
      expect(image.height, (logical.height * ratio).round());
      image.dispose();
    }

    await shoot(const Size(393, 852), 3, 'terms_consent_iphone.png');
    await shoot(const Size(1024, 1366), 2, 'terms_consent_ipad.png');
  });
}
