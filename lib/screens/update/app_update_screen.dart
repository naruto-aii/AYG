import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_version_policy.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_page.dart';

class AppUpdateScreen extends StatelessWidget {
  const AppUpdateScreen({
    super.key,
    required this.decision,
    required this.storeUrl,
    this.onLater,
    this.launch,
  });

  final AppUpdateDecision decision;
  final String storeUrl;
  final VoidCallback? onLater;
  final Future<bool> Function(Uri uri, {LaunchMode mode})? launch;

  bool get _blocking => decision == AppUpdateDecision.required;

  Future<void> _openStore() async {
    final uri = Uri.tryParse(storeUrl);
    if (uri == null || uri.scheme.isEmpty) {
      return;
    }
    try {
      final open = launch ?? launchUrl;
      await open(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocking = _blocking;
    return PopScope(
      canPop: !blocking,
      child: DesignPage(
        bottomBar: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesignButton(
              label: 'アップストアで更新',
              showTrailingIcon: false,
              onPressed: _openStore,
            ),
            if (!blocking) ...[
              const SizedBox(height: AppSpacing.sm),
              DesignButton(
                label: 'あとで',
                style: DesignButtonStyle.secondary,
                showTrailingIcon: false,
                onPressed: () {
                  final later = onLater;
                  if (later != null) {
                    later();
                    return;
                  }
                  Navigator.of(context).maybePop();
                },
              ),
            ],
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesignTitleBlock(
              title: blocking ? 'アップデートが必要です' : '新しいバージョンがあります',
              subtitle: blocking ? 'このバージョンでは続けられません。' : '新しいバージョンが公開されています。',
              showBack: false,
            ),
          ],
        ),
      ),
    );
  }
}
