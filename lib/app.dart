import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'constants/app_strings.dart';
import 'repositories/authentication_repository.dart';
import 'repositories/health_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/health_setup_screen.dart';
import 'screens/shell/main_shell_screen.dart';
import 'services/analytics/analytics.dart';
import 'services/analytics/analytics_runtime.dart';
import 'services/analytics/analytics_service.dart';
import 'services/analytics/catalog_actions.dart';
import 'services/open_food_facts_service.dart';
import 'state/app_controller.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/layout/app_frame.dart';
import 'widgets/startup/app_startup_gate.dart';

class AygApp extends StatefulWidget {
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
  State<AygApp> createState() => _AygAppState();
}

class _AygAppState extends State<AygApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _wasAuthenticated = false;

  FlutterExceptionHandler? _previousFlutterError;
  bool Function(Object, StackTrace)? _previousPlatformError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasAuthenticated = widget.controller.isAuthenticated;
    widget.controller.addListener(_popRoutesAfterSignOut);
    _previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      CatalogActions.appError(
        errorType: details.exception.runtimeType.toString(),
        where: 'flutter',
        fatal: false,
      );
      _previousFlutterError?.call(details);
    };
    _previousPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      CatalogActions.appError(
        errorType: error.runtimeType.toString(),
        where: 'platform',
        fatal: true,
      );
      return _previousPlatformError?.call(error, stack) ?? false;
    };
    // 起動直後は Method Channel がまだ無いことがある。画面が出てから
    // 有料フラグとウィジェットの中身を App Group へもう一度書く。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_coldStart());
    });
  }

  @override
  void dispose() {
    FlutterError.onError = _previousFlutterError;
    final previous = _previousPlatformError;
    if (previous != null) {
      PlatformDispatcher.instance.onError = previous;
    }
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_popRoutesAfterSignOut);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onResume());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(AnalyticsRuntime.lifecycle?.onBackground());
    }
  }

  bool _analyticsStarting = false;

  /// 規約とプライバシーポリシーに同意してログインした人は、利用状況の記録を始める。
  ///
  /// 専用の同意画面は出さない。プライバシーポリシー 3-2 に書いた範囲で記録する。
  /// 設定の「規約とポリシー」→「利用状況の記録」で止めた人には何もしない。
  void _startAnalyticsAfterAgreement() {
    final analytics = Analytics.service;
    if (analytics == null || analytics.consentDecided || _analyticsStarting) {
      return;
    }
    _analyticsStarting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await analytics.grantConsent(surface: analyticsAgreementSurface);
        await AnalyticsRuntime.lifecycle?.onColdStart();
        await AnalyticsRuntime.ads?.captureOnce();
      } finally {
        _analyticsStarting = false;
      }
    });
  }

  Future<void> _coldStart() async {
    final service = Analytics.service;
    if (service != null && service.consented) {
      await AnalyticsRuntime.lifecycle?.onColdStart();
      await AnalyticsRuntime.ads?.captureOnce();
    }
    await _resumePaidFeatures();
  }

  Future<void> _onResume() async {
    await AnalyticsRuntime.lifecycle?.onForeground();
    await _resumePaidFeatures();
  }

  Future<void> _resumePaidFeatures() async {
    await Analytics.service?.importNativePending();
    await widget.controller.refreshPaidEntitlement();
    await widget.controller.syncLockScreenMeals();
    await widget.controller.syncSiriVoiceLogs();
    await widget.controller.flushUnsentRecords();
    await Analytics.service?.flush();
  }

  void _popRoutesAfterSignOut() {
    final signedIn = widget.controller.isAuthenticated;
    final signedOut = _wasAuthenticated && !signedIn;
    _wasAuthenticated = signedIn;
    if (!signedOut) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey.currentState;
      if (navigator == null || !navigator.mounted) {
        return;
      }
      navigator.popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppStrings.appTitle,
      theme: AppTheme.light,
      navigatorObservers: [
        if (AnalyticsRuntime.routes != null) AnalyticsRuntime.routes!,
      ],
      builder: buildCalonaviFrame,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    final controller = widget.controller;
    final app = ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        if (controller.isInitializing) {
          return const AppStartupLoadingScreen();
        }

        // 規約・プライバシー（AI送信の一文を含む）に、この端末でまだ同意して
        // いなければ、ログイン済みでも同じログイン画面を出す。押すまで何も送らない。
        if (!controller.isAuthenticated || controller.requiresTermsAgreement) {
          return LoginScreen(
            controller: controller,
            authenticationRepository: widget.authenticationRepository,
            authStorageAvailable: widget.authStorageAvailable,
          );
        }

        if (controller.isSyncInProgress) {
          return const AppStartupLoadingScreen();
        }

        // ログイン（利用規約とプライバシーポリシーへの同意）のあとに記録を始める。
        // 以前に設定で止めた人（denied）はそのまま。
        _startAnalyticsAfterAgreement();

        if (controller.requiresSyncRetry) {
          return AppSyncRetryScreen(
            controller: controller,
            onLogout: () => controller.logout(),
          );
        }

        if (controller.requiresOnboarding) {
          return HealthSetupScreen(
            controller: controller,
            openFoodFactsService: widget.openFoodFactsService,
            healthRepository: widget.healthRepository,
            authenticationRepository: widget.authenticationRepository,
          );
        }

        if (_shouldShowMainShell(controller)) {
          return MainShellScreen(
            controller: controller,
            openFoodFactsService: widget.openFoodFactsService,
            authenticationRepository: widget.authenticationRepository,
            healthRepository: widget.healthRepository,
          );
        }

        return AppSyncRetryScreen(
          controller: controller,
          onLogout: () => controller.logout(),
        );
      },
    );
    if (!widget.showSplash) {
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
