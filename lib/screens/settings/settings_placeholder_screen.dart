import 'package:flutter/material.dart';

import '../../repositories/authentication_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';

class SettingsPlaceholderScreen extends StatelessWidget {
  const SettingsPlaceholderScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;

  Future<void> _logout(BuildContext context) async {
    await controller.logout();
  }

  @override
  Widget build(BuildContext context) {
    final email = authenticationRepository.currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (email != null) ...[
              Text('ログイン中', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(email),
              const SizedBox(height: AppSpacing.lg),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout),
              title: const Text('ログアウト'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}
