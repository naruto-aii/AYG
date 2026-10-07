import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../repositories/authentication_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_icons.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/settings_row.dart';
import 'account_deletion_screen.dart';

/// ログアウトとアカウント削除。削除画面の説明はそのまま。
class SettingsAccountScreen extends StatelessWidget {
  const SettingsAccountScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
    this.supportEmail,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;
  final String? supportEmail;

  @override
  Widget build(BuildContext context) {
    final email = authenticationRepository.currentUser?.email;
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: 'アカウント',
            subtitle: 'ログアウトと、アカウントの削除です。',
          ),
          SettingsRow(
            icon: AppIcons.user,
            title: AppStrings.settingsLoggedInAs,
            subtitle: email ?? 'アカウント情報の確認・変更',
            showChevron: false,
          ),
          const SizedBox(height: 8),
          SettingsRow(
            icon: AppIcons.logout,
            title: AppStrings.settingsLogout,
            subtitle: '別のアカウントで使うとき',
            danger: true,
            onTap: () => controller.logout(),
          ),
          const SizedBox(height: 8),
          SettingsRow(
            icon: AppIcons.trash,
            title: AppStrings.settingsAccountDeletion,
            subtitle: AppStrings.settingsAccountDeletionSubtitle,
            danger: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'settings_account_screen_MaterialPageRoute_0'),
                  builder: (context) => AccountDeletionScreen(
                    controller: controller,
                    authenticationRepository: authenticationRepository,
                    supportEmail: supportEmail,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
