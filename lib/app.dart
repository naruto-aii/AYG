import 'package:flutter/material.dart';

import 'constants/app_strings.dart';
import 'repositories/authentication_repository.dart';
import 'repositories/health_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/health_setup_screen.dart';
import 'screens/shell/main_shell_screen.dart';
import 'services/open_food_facts_service.dart';
import 'state/app_controller.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/startup/app_startup_gate.dart';

class AygApp extends StatelessWidget {
  const AygApp({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.healthRepository,
    required this.authenticationRepository,
    this.authStorageAvailable = true,
    this.showSplash = false,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final HealthRepository healthRepository;
  final AuthenticationRepository authenticationRepository;
  final bool authStorageAvailable;

  /// 起動時のスプラッシュ演出を再生するか。テストでは false のまま使う。
  final bool showSplash;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      theme: AppTheme.light,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    final app = ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          if (controller.isInitializing ||
              (controller.isAuthenticated && controller.isSyncInProgress)) {
            return const AppStartupLoadingScreen();
          }

          if (!controller.isAuthenticated) {
            return LoginScreen(
              controller: controller,
              authenticationRepository: authenticationRepository,
              authStorageAvailable: authStorageAvailable,
            );
          }

          if (controller.requiresSyncRetry) {
            return AppSyncRetryScreen(
              controller: controller,
              onLogout: () => controller.logout(),
            );
          }

          if (controller.requiresOnboarding) {
            return HealthSetupScreen(
              controller: controller,
              openFoodFactsService: openFoodFactsService,
              healthRepository: healthRepository,
              authenticationRepository: authenticationRepository,
            );
          }

          if (_shouldShowMainShell(controller)) {
            return MainShellScreen(
              controller: controller,
              openFoodFactsService: openFoodFactsService,
              authenticationRepository: authenticationRepository,
              healthRepository: healthRepository,
            );
          }

          return AppSyncRetryScreen(
            controller: controller,
            onLogout: () => controller.logout(),
          );
        },
    );
    if (!showSplash) {
      return app;
    }
    return _SplashGate(child: app);
  }

  bool _shouldShowMainShell(AppController controller) {
    return controller.onboardingComplete &&
        controller.profile != null &&
        controller.goal != null &&
        controller.nutritionSettings != null;
  }
}

/// 起動直後にスプラッシュ演出を流し、終わったら本編へディゾルブする。
class _SplashGate extends StatefulWidget {
  const _SplashGate({required this.child});

  final Widget child;

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _finished = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      // Figma: 09 拡大 → 01 ログイン のディゾルブ 350ms
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: _finished
          ? KeyedSubtree(key: const ValueKey('app'), child: widget.child)
          : SplashScreen(
              key: const ValueKey('splash'),
              onCompleted: () {
                if (mounted) {
                  setState(() => _finished = true);
                }
              },
            ),
    );
  }
}
