import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../repositories/authentication_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_icons.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/settings_row.dart';
import 'settings_basic_info_screen.dart';
import 'settings_goal_screen.dart';

/// 基本情報と目標設定。中身はそれぞれの画面のまま。
class SettingsProfileScreen extends StatelessWidget {
  const SettingsProfileScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;

  void _push(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'settings_profile_screen_MaterialPageRoute_0'),builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: 'プロフィールと目標',
            subtitle: '名前や体格と、目標の体重・カロリーです。',
          ),
          SettingsRow(
            icon: AppIcons.user,
            title: AppStrings.settingsBasicInfo,
            subtitle: '名前・年齢・性別・身長・体重',
            onTap: () => _push(
              context,
              SettingsBasicInfoScreen(
                controller: controller,
                suggestedDisplayName:
                    authenticationRepository.currentUser?.suggestedDisplayName,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SettingsRow(
            icon: AppIcons.goal,
            title: AppStrings.settingsGoal,
            subtitle: '目標体重・目標カロリーなど',
            onTap: () =>
                _push(context, SettingsGoalScreen(controller: controller)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
