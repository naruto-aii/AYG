// デザイン確認専用のエントリポイント。製品ビルドには含めない。
//
//   flutter run -d chrome -t lib/main_design_preview.dart
//
// Figma で作った各画面を、ログインやデータ同期を通さずに直接開くための入口。
import 'package:flutter/material.dart';

import 'models/activity_level.dart';
import 'models/goal.dart';
import 'models/health_profile_data.dart';
import 'models/nutrition_settings.dart';
import 'models/user_profile.dart';
import 'repositories/health_repository.dart';
import 'repositories/supabase_authentication_repository.dart';
import 'screens/onboarding/activity_level_screen.dart';
import 'screens/onboarding/basic_info_screen.dart';
import 'screens/onboarding/goal_setup_screen.dart';
import 'screens/onboarding/health_setup_screen.dart';
import 'services/open_food_facts_service.dart';
import 'state/app_controller.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/app_typography.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppController(
    authenticationRepository: UnconfiguredAuthenticationRepository(),
  )
    ..setProfile(
      UserProfile(
        birthDate: DateTime(1990, 5, 12),
        gender: Gender.male,
        heightCm: 172,
        weightKg: 70,
      ),
    )
    ..setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    )
    ..setGoal(
      Goal(
        type: GoalType.lose,
        targetWeightKg: 62,
        targetDate: DateTime.now().add(const Duration(days: 92)),
      ),
    );

  runApp(DesignPreviewApp(controller: controller));
}

class DesignPreviewApp extends StatelessWidget {
  const DesignPreviewApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final openFoodFactsService = OpenFoodFactsService(userAgent: 'ayg-preview');
    final healthRepository = _PreviewHealthRepository();
    final authenticationRepository = UnconfiguredAuthenticationRepository();

    final entries = <_PreviewEntry>[
      _PreviewEntry(
        '02 初回設定 1-3 Health連携',
        () => HealthSetupScreen(
          controller: controller,
          openFoodFactsService: openFoodFactsService,
          healthRepository: healthRepository,
          authenticationRepository: authenticationRepository,
        ),
      ),
      _PreviewEntry(
        '03 初回設定 2-3 基本情報',
        () => BasicInfoScreen(
          controller: controller,
          openFoodFactsService: openFoodFactsService,
          healthPrefill: HealthProfileData.empty,
          authenticationRepository: authenticationRepository,
        ),
      ),
      _PreviewEntry(
        '04 初回設定 3-3 目標を設定',
        () => GoalSetupScreen(
          controller: controller,
          openFoodFactsService: openFoodFactsService,
          authenticationRepository: authenticationRepository,
        ),
      ),
      _PreviewEntry(
        '（参考）活動量',
        () => ActivityLevelScreen(
          controller: controller,
          openFoodFactsService: openFoodFactsService,
          authenticationRepository: authenticationRepository,
        ),
      ),
    ];

    return MaterialApp(
      title: 'カロナビ デザインプレビュー',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: _PreviewMenu(entries: entries),
    );
  }
}

class _PreviewEntry {
  const _PreviewEntry(this.label, this.builder);

  final String label;
  final Widget Function() builder;
}

class _PreviewMenu extends StatelessWidget {
  const _PreviewMenu({required this.entries});

  final List<_PreviewEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('デザインプレビュー', style: AppTypography.headingM),
            const SizedBox(height: 16),
            for (final entry in entries)
              ListTile(
                title: Text(entry.label, style: AppTypography.titleM),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => entry.builder()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewHealthRepository implements HealthRepository {
  @override
  bool get isAvailable => true;

  @override
  Future<HealthProfileData> fetchProfileData() async => HealthProfileData.empty;

  @override
  Future<List<WeightRecord>> loadWeightRecords() async => const [];

  @override
  Future<List<HealthWorkoutRecord>> loadWorkoutRecords() async => const [];

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> saveWeightRecord(WeightRecord record) async {}

  @override
  Future<void> saveWorkoutRecords(List<HealthWorkoutRecord> records) async {}
}
