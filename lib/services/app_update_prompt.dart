import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/app_version_policy_repository.dart';
import '../screens/update/app_update_screen.dart';
import 'app_version_policy.dart';

const appUpdatePromptRouteName = 'app_update_prompt';

const appUpdateDismissedRecommendedKey =
    'app_update_dismissed_recommended_version';

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

  /// あとで、または戻るで閉じた推奨版。違う推奨版はもう一度出す。
  String? dismissedRecommendedVersion;

  bool _opening = false;

  Future<void>? dismissalPersisted;

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
    if (decision == AppUpdateDecision.recommended) {
      await _loadDismissedRecommended();
      if (dismissedRecommendedVersion == policy.recommended) {
        return;
      }
    }
    if (_alreadyShowing(host)) {
      return;
    }

    _opening = true;
    final route = _PromptRoute(
      onDismiss: decision == AppUpdateDecision.recommended
          ? () => dismissRecommended(policy.recommended)
          : null,
      builder: (context) {
        return AppUpdateScreen(
          decision: decision,
          storeUrl: policy.storeUrl,
          onLater: decision == AppUpdateDecision.recommended
              ? () {
                  if (host.mounted) {
                    host.pop();
                  }
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

  Future<void> _loadDismissedRecommended() async {
    if (dismissedRecommendedVersion != null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    dismissedRecommendedVersion = prefs.getString(
      appUpdateDismissedRecommendedKey,
    );
  }

  /// 推奨の案内を、この版だけ閉じたことにする。戻るでも「あとで」でも同じ。
  void dismissRecommended(String version) {
    final trimmed = version.trim();
    if (trimmed.isEmpty) {
      return;
    }
    dismissedRecommendedVersion = trimmed;
    dismissalPersisted = SharedPreferences.getInstance().then((prefs) async {
      await prefs.setString(appUpdateDismissedRecommendedKey, trimmed);
    });
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
  _PromptRoute({required super.builder, this.onDismiss})
    : super(settings: const RouteSettings(name: appUpdatePromptRouteName));

  final VoidCallback? onDismiss;

  static final Set<_PromptRoute> _open = <_PromptRoute>{};

  static bool get isOpen => _open.isNotEmpty;

  bool _tracked = false;
  bool _dismissed = false;

  void _noteDismiss() {
    if (_dismissed) {
      return;
    }
    _dismissed = true;
    onDismiss?.call();
  }

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
  bool didPop(void result) {
    final popped = super.didPop(result);
    if (popped) {
      _noteDismiss();
    }
    return popped;
  }

  @override
  void dispose() {
    _open.remove(this);
    _tracked = false;
    super.dispose();
  }
}
