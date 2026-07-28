import 'package:ayg/screens/auth/login_screen.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../test/mocks/mock_authentication_repository.dart';
import '../test/mocks/mock_health_repository.dart';

/// ログイン画面Screenshot用。
/// 実行: flutter run -t tool/prototype_login_main.dart -d <device>
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final healthRepository = MockHealthRepository(isAvailable: false);
  final authRepository = MockAuthenticationRepository();
  final controller = AppController(
    healthRepository: healthRepository,
    authenticationRepository: authRepository,
  );

  runApp(
    MaterialApp(
      theme: AppTheme.light,
      home: LoginScreen(
        controller: controller,
        authenticationRepository: authRepository,
      ),
    ),
  );
}
