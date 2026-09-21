import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_contact_config.dart';
import '../../constants/app_strings.dart';
import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/settings_list_tile.dart';
import '../../widgets/layout/app_content_constraint.dart';
import '../legal/legal_document.dart';
import '../legal/legal_document_screen.dart';
import 'account_deletion_screen.dart';
import 'calculation_references_screen.dart';
import 'settings_basic_info_screen.dart';
import 'settings_food_master_screen.dart';
import 'settings_goal_screen.dart';
import 'settings_health_activity_screen.dart';
import '../subscription/calonavi_plus_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
    this.healthRepository,
    this.openFoodFactsService,
    this.hideHealthSettings = false,
    this.supportEmail,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;
  final HealthRepository? healthRepository;
  final OpenFoodFactsService? openFoodFactsService;
  final bool hideHealthSettings;
  final String? supportEmail;

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
    final contactEmail = (supportEmail ?? AppContactConfig.contactEmail).trim();

    return Scaffold(
      body: SafeArea(
        child: AppContentConstraint(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              Text(
                AppStrings.settingsTitle,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.settingsLead,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              SettingsListTile(
                asCard: true,
                icon: Icons.person_outline,
                title: AppStrings.settingsLoggedInAs,
                subtitle: email ?? AppStrings.settingsLoggedInSubtitle,
                onTap: null,
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsListTile(
                asCard: true,
                icon: Icons.badge_outlined,
                title: AppStrings.settingsBasicInfo,
                subtitle: AppStrings.settingsBasicInfoSubtitle,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          SettingsBasicInfoScreen(controller: controller),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsListTile(
                asCard: true,
                icon: Icons.flag_outlined,
                title: AppStrings.settingsGoal,
                subtitle: AppStrings.settingsGoalSubtitle,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          SettingsGoalScreen(controller: controller),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsListTile(
                asCard: true,
                icon: Icons.directions_run_outlined,
                title: AppStrings.settingsHealthActivity,
                subtitle: hideHealthSettings
                    ? AppStrings.webHealthUnavailable
                    : AppStrings.settingsHealthActivitySubtitle,
                enabled: !hideHealthSettings && healthRepository != null,
                onTap: hideHealthSettings || healthRepository == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => SettingsHealthActivityScreen(
                              controller: controller,
                              healthRepository: healthRepository!,
                            ),
                          ),
                        );
                      },
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsListTile(
                asCard: true,
                icon: Icons.restaurant_outlined,
                title: AppStrings.settingsFoodMaster,
                subtitle: AppStrings.settingsFoodMasterSubtitle,
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
              const SizedBox(height: AppSpacing.sm),
              SettingsListTile(
                asCard: true,
                icon: Icons.calculate_outlined,
                title: AppStrings.settingsCalculation,
                subtitle: AppStrings.settingsCalculationSubtitle,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          const CalculationReferencesScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsListTile(
                asCard: true,
                icon: Icons.workspace_premium_outlined,
                title: AppStrings.plusTitle,
                subtitle: controller.isCalonaviPlusActive
                    ? AppStrings.plusActive
                    : AppStrings.plusInactive,
                onTap: () => showCalonaviPlus(
                  context,
                  controller.subscriptionRepository,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsListTile(
                asCard: true,
                icon: Icons.description_outlined,
                title: '利用規約',
                subtitle: 'サービスのご利用条件',
                onTap: () => showLegalDocument(context, LegalDocument.terms),
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsListTile(
                asCard: true,
                icon: Icons.privacy_tip_outlined,
                title: 'プライバシーポリシー',
                onTap: () => showLegalDocument(context, LegalDocument.privacy),
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsListTile(
                asCard: true,
                icon: Icons.receipt_long_outlined,
                title: AppStrings.settingsTokushoho,
                onTap: () =>
                    showLegalDocument(context, LegalDocument.tokushoho),
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsListTile(
                asCard: true,
                icon: Icons.help_outline,
                title: AppStrings.settingsSupport,
                onTap: () =>
                    showLegalDocument(context, LegalDocument.support),
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsListTile(
                asCard: true,
                icon: Icons.person_off_outlined,
                title: AppStrings.settingsAccountDeletion,
                subtitle: AppStrings.settingsAccountDeletionSubtitle,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => AccountDeletionScreen(
                        controller: controller,
                        authenticationRepository: authenticationRepository,
                        supportEmail: contactEmail,
                      ),
                    ),
                  );
                },
              ),
              if (contactEmail.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                SettingsListTile(
                  asCard: true,
                  icon: Icons.mail_outline,
                  title: AppStrings.settingsContactOperator,
                  subtitle: contactEmail,
                  onTap: () => _openUrl(context, 'mailto:$contactEmail'),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              SettingsListTile(
                asCard: true,
                icon: Icons.logout,
                title: AppStrings.settingsLogout,
                destructive: true,
                onTap: () => _logout(context),
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
      ),
    );
  }
}
