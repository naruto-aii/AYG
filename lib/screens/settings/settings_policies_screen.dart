import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_icons.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/settings_row.dart';
import '../legal/legal_document.dart';
import '../legal/legal_document_screen.dart';
import 'analytics_settings_screen.dart';

/// 利用規約、プライバシー、特定商取引法。本文は各書類のまま。
class SettingsPoliciesScreen extends StatelessWidget {
  const SettingsPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: '規約とポリシー',
            subtitle: '利用規約、プライバシーポリシー、販売条件です。',
          ),
          SettingsRow(
            icon: AppIcons.document,
            title: '利用規約',
            subtitle: 'サービスのご利用条件',
            onTap: () => showLegalDocument(context, LegalDocument.terms),
          ),
          const SizedBox(height: 8),
          SettingsRow(
            icon: AppIcons.shield,
            title: 'プライバシー',
            subtitle: '個人情報の取り扱いについて',
            onTap: () => showLegalDocument(context, LegalDocument.privacy),
          ),
          const SizedBox(height: 8),
          SettingsRow(
            icon: AppIcons.document,
            title: AppStrings.settingsTokushoho,
            subtitle: '販売条件・事業者情報',
            onTap: () => showLegalDocument(context, LegalDocument.tokushoho),
          ),
          const SizedBox(height: 8),
          SettingsRow(
            key: const Key('settings-analytics'),
            icon: AppIcons.information,
            title: '利用状況の記録',
            subtitle: 'サービス改善のための分析',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'analytics_settings'),
                builder: (context) => const AnalyticsSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
