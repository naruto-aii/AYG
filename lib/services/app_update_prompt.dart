import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../repositories/app_version_policy_repository.dart';
import '../screens/update/app_update_screen.dart';
import 'app_version_policy.dart';

const appUpdatePromptRouteName = 'app_update_prompt';

/// 端末の版が読めないときは null。0.0.0 として案内は出さない。
Future<String?> readCurrentAppVersion() {
  return PackageInfo.fromPlatform()
      .then<String?>((info) {
        final version = info.version.trim();
        if (version.isEmpty) {
          return null;
        }
        final build = info.buildNumber.trim();
        if (build.isEmpty) {
          return version;
        }
        return '$version+$build';
      })
      .catchError((Object _) => null);
}

class AppUpdatePrompt {
  AppUpdatePrompt({this.repository});

  final AppVersionPolicyRepository? repository;

  bool recommendedDismissed = false;

  bool _opening = false;

  Future<void> present({
    required NavigatorState? navigator,
    required String? currentVersion,
    AppVersionPolicyRepository? repository,
  }) async {
    final version = currentVersion?.trim();
    if (version == null || version.isEmpty) {
      return;
    }
    final host = navigator;
    if (host == null || !host.mounted) {
      return;
    }
    final resolved =
        repository ?? this.repository ?? AppVersionPolicyRepository();
    final policy = await resolved.fetch();
    if (policy == null || !host.mounted || _alreadyShowing(host)) {
      return;
    }
    final decision = decideAppUpdate(
      current: version,
      minimum: policy.minimum,
      recommended: policy.recommended,
    );
    if (decision == AppUpdateDecision.none) {
      return;
    }
    if (decision == AppUpdateDecision.recommended && recommendedDismissed) {
      return;
    }
    if (_alreadyShowing(host)) {
      return;
    }

    _opening = true;
    final route = _PromptRoute(
      builder: (context) {
        return AppUpdateScreen(
          decision: decision,
          storeUrl: policy.storeUrl,
          onLater: decision == AppUpdateDecision.recommended
              ? () {
                  recommendedDismissed = true;
                  host.pop();
                }
              : null,
        );
      },
    );
    try {
      host.push(route);
    } finally {
      _opening = false;
    }
  }

  bool _alreadyShowing(NavigatorState navigator) {
    if (_opening || _PromptRoute.isOpen) {
      return true;
    }
    var found = false;
    try {
      navigator.popUntil((route) {
        if (route.settings.name == appUpdatePromptRouteName) {
          found = true;
        }
        return true;
      });
    } catch (_) {
      return false;
    }
    return found;
  }
}

class _PromptRoute extends MaterialPageRoute<void> {
  _PromptRoute({required super.builder})
    : super(settings: const RouteSettings(name: appUpdatePromptRouteName));

  static final Set<_PromptRoute> _open = <_PromptRoute>{};

  static bool get isOpen => _open.isNotEmpty;

  bool _tracked = false;

  @override
  void install() {
    super.install();
    if (_tracked) {
      return;
    }
    _tracked = true;
    _open.add(this);
  }

  @override
  void dispose() {
    _open.remove(this);
    _tracked = false;
    super.dispose();
  }
}
