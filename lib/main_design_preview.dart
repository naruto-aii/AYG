// デザイン確認専用のエントリポイント。製品ビルドには含めない。
//
//   flutter run -d chrome -t lib/main_design_preview.dart
//
// Figma で作った各画面を、ログインやデータ同期を通さずに直接開くための入口。
import 'package:flutter/material.dart';

import 'models/activity_level.dart';
import 'models/alcohol_entry.dart';
import 'models/exercise_entry.dart';
import 'models/food_entry.dart';
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
import 'screens/shell/main_shell_screen.dart';
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

  _seedToday(controller);

  runApp(DesignPreviewApp(controller: controller));
}

/// 画面の見た目を確認するための当日ぶんのダミー記録。
void _seedToday(AppController controller) {
  DateTime at(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  controller
    ..addFood(
      FoodEntry(
        id: 'preview-food-1',
        name: 'オートミール（バナナ・ナッツ）',
        quantity: 1,
        kcalPerUnit: 320,
        proteinPerUnit: 12,
        fatPerUnit: 9,
        carbPerUnit: 48,
        loggedAt: at(7, 30),
      ),
    )
    ..addFood(
      FoodEntry(
        id: 'preview-food-2',
        name: '鶏むね肉のサラダ',
        quantity: 1,
        kcalPerUnit: 480,
        proteinPerUnit: 42,
        fatPerUnit: 18,
        carbPerUnit: 24,
        loggedAt: at(12, 15),
      ),
    )
    ..addFood(
      FoodEntry(
        id: 'preview-food-3',
        name: '鮭おにぎり',
        quantity: 1,
        kcalPerUnit: 230,
        proteinPerUnit: 7,
        fatPerUnit: 3,
        carbPerUnit: 44,
        loggedAt: at(18, 20),
      ),
    )
    ..addAlcohol(
      AlcoholEntry(
        id: 'preview-alcohol-1',
        beverageName: 'ビール（中ジョッキ）',
        amount: 500,
        unit: 'ml',
        alcoholPercentage: 5,
        pureAlcoholGrams: 20,
        alcoholCalories: 140,
        totalCalories: 200,
        consumedAt: at(19, 0),
      ),
    )
    ..addExercise(
      ExerciseEntry(
        id: 'preview-exercise-1',
        name: 'ウォーキング（30分）',
        durationMin: 30,
        burnedKcal: 120,
        loggedAt: at(8, 0),
      ),
    );
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
        '05 ホーム（タブバー込み）',
        () => MainShellScreen(
          controller: controller,
          openFoodFactsService: openFoodFactsService,
          authenticationRepository: authenticationRepository,
          healthRepository: healthRepository,
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
