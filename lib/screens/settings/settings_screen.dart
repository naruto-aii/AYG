import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import 'settings_basic_info_screen.dart';
import 'settings_goal_screen.dart';
import 'settings_health_activity_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
    this.healthRepository,
    this.hideHealthSettings = false,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;
  final HealthRepository? healthRepository;
  final bool hideHealthSettings;

  Future<void> _logout(BuildContext context) async {
    await controller.logout();
  }

  @override
  Widget build(BuildContext context) {
    final email = authenticationRepository.currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (email != null) ...[
              Text(
                AppStrings.settingsLoggedInAs,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(email),
              const SizedBox(height: AppSpacing.lg),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: const Text(AppStrings.settingsBasicInfo),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        SettingsBasicInfoScreen(controller: controller),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: const Text(AppStrings.settingsGoal),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        SettingsGoalScreen(controller: controller),
                  ),
                );
              },
            ),
            if (!hideHealthSettings)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.favorite_outline),
                title: const Text(AppStrings.settingsHealthActivity),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (healthRepository == null) {
                    return;
                  }
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
            if (hideHealthSettings)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.favorite_outline),
                title: const Text(AppStrings.settingsHealthActivity),
                subtitle: const Text(AppStrings.webHealthUnavailable),
                enabled: false,
              ),
            const Divider(height: AppSpacing.lg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout),
              title: const Text(AppStrings.settingsLogout),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}
