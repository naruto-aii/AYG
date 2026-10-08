import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/screens/auth/login_screen.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  );
  final packages = config['packages'] as List<dynamic>;
  final entry = packages.cast<Map<String, dynamic>>().firstWhere(
    (package) => package['name'] == 'material_symbols_icons',
  );
  final root = Uri.parse(entry['rootUri'] as String);
  final configUri = Directory.current.uri.resolve(
    '.dart_tool/package_config.json',
  );
  final file = File(
    '${configUri.resolveUri(root).toFilePath()}/lib/fonts/MaterialSymbolsRounded.ttf',
  );
  final symbols = FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  );
  symbols.addFont(
    Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
  );
  await symbols.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('the login agreement is a 6.7-inch screen at 3x', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = FakeViewPadding.zero;
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.systemGestureInsets = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    final controller = AppController();
    addTearDown(controller.dispose);
    final repository = MockAuthenticationRepository();
    addTearDown(repository.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: LoginScreen(
            controller: controller,
            authenticationRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.loginLegalAgreementMultiline), findsOneWidget);
    expect(find.text(AppStrings.loginAiDisclosureMultiline), findsOneWidget);
    expect(find.text('利用規約'), findsOneWidget);
    expect(find.text('プライバシーポリシー'), findsOneWidget);

    final directory = Directory('/opt/cursor/artifacts/screenshots')
      ..createSync(recursive: true);
    final bytes = await tester.runAsync(
      () => pngBytesFromBoundary(key, pixelRatio: 3),
    );
    expect(bytes, isNotNull);
    final file = File('${directory.path}/login_agreement.png');
    file.writeAsBytesSync(bytes!);
    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final shot = frame.image;
      codec.dispose();
      return shot;
    });
    expect(image!.width, 1290);
    expect(image.height, 2796);
    image.dispose();
  });
}
