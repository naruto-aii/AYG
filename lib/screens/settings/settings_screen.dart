import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/supabase_config.dart';
import '../../constants/app_strings.dart';
import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/brand/app_logo.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/settings_list_tile.dart';
import 'settings_basic_info_screen.dart';
import 'settings_food_master_screen.dart';
import 'settings_goal_screen.dart';
import 'settings_health_activity_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
    this.healthRepository,
    this.openFoodFactsService,
    this.hideHealthSettings = false,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;
  final HealthRepository? healthRepository;
  final OpenFoodFactsService? openFoodFactsService;
  final bool hideHealthSettings;

  Future<void> _logout(BuildContext context) async {
    await controller.logout();
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('リンクを開けませんでした: $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = authenticationRepository.currentUser?.email;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: AppLogo(height: 28),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('設定', style: Theme.of(context).textTheme.headlineMedium),
            if (email != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${AppStrings.settingsLoggedInAs}: $email',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SettingsListTile(
                    icon: Icons.person_outline,
                    title: AppStrings.settingsBasicInfo,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              SettingsBasicInfoScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  SettingsListTile(
                    icon: Icons.flag_outlined,
                    title: AppStrings.settingsGoal,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              SettingsGoalScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                  if (!hideHealthSettings) ...[
                    const Divider(height: 1),
                    SettingsListTile(
                      icon: Icons.favorite_outline,
                      title: AppStrings.settingsHealthActivity,
                      onTap: healthRepository == null
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) =>
                                      SettingsHealthActivityScreen(
                                        controller: controller,
                                        healthRepository: healthRepository!,
                                      ),
                                ),
                              );
                            },
                    ),
                  ],
                  const Divider(height: 1),
                  SettingsListTile(
                    icon: Icons.restaurant_menu_outlined,
                    title: AppStrings.settingsFoodMaster,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => SettingsFoodMasterScreen(
                            controller: controller,
                            openFoodFactsService: openFoodFactsService,
                          ),
                        ),
                      );
                    },
                  ),
                  if (hideHealthSettings) ...[
                    const Divider(height: 1),
                    SettingsListTile(
                      icon: Icons.favorite_outline,
                      title: AppStrings.settingsHealthActivity,
                      subtitle: AppStrings.webHealthUnavailable,
                      enabled: false,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SettingsListTile(
                    icon: Icons.description_outlined,
                    title: '利用規約',
                    onTap: () => _openUrl(context, SupabaseConfig.termsUrl),
                  ),
                  const Divider(height: 1),
                  SettingsListTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'プライバシーポリシー',
                    onTap: () => _openUrl(context, SupabaseConfig.privacyUrl),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: EdgeInsets.zero,
              child: SettingsListTile(
                icon: Icons.logout,
                title: AppStrings.settingsLogout,
                destructive: true,
                onTap: () => _logout(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text(
                AppStrings.appTitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
