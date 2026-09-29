import 'package:flutter/material.dart';

import '../../models/health_profile_data.dart';
import '../../models/nutrition_settings.dart';
import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/brand/app_brand_mark.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/select_card.dart';
import '../../widgets/design/step_indicator.dart';
import 'basic_info_screen.dart';

/// 初回オンボーディング: Health 連携の選択。
///
/// Figma: SP / 02 初回設定 1-3 Health連携（23:115）
class HealthSetupScreen extends StatefulWidget {
  const HealthSetupScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.healthRepository,
    required this.authenticationRepository,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final HealthRepository healthRepository;
  final AuthenticationRepository authenticationRepository;

  @override
  State<HealthSetupScreen> createState() => _HealthSetupScreenState();
}

class _HealthSetupScreenState extends State<HealthSetupScreen> {
  /// Figma のハートは Apple ヘルスケアの赤。トークン外の一点色。
  static const Color _healthRed = Color(0xFFF05C6B);

  bool? _useHealthIntegration;
  bool _isLoading = false;

  Future<void> _continueWithHealth() async {
    setState(() => _isLoading = true);

    final granted = await widget.healthRepository.requestPermissions();
    final profileData = granted
        ? await widget.healthRepository.fetchProfileData()
        : HealthProfileData.empty;

    widget.controller.setNutritionSettings(
      const NutritionSettings(useHealthIntegration: true),
    );
    await widget.controller.applyHealthProfileData(profileData);

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Healthデータを取得できませんでした。取得できない項目は手入力してください。'),
        ),
      );
    }

    _openBasicInfo(profileData);
  }

  void _continueWithoutHealth() {
    _openBasicInfo(HealthProfileData.empty);
  }

  void _openBasicInfo(HealthProfileData prefill) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BasicInfoScreen(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
          healthPrefill: prefill,
          authenticationRepository: widget.authenticationRepository,
        ),
      ),
    );
  }

  void _continueNext() {
    if (_useHealthIntegration == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Health連携の利用有無を選択してください')));
      return;
    }

    if (_useHealthIntegration!) {
      _continueWithHealth();
    } else {
      _continueWithoutHealth();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      bodyPadding: const EdgeInsets.symmetric(horizontal: 24),
      header: const SizedBox(
        height: 56,
        child: Padding(
          padding: EdgeInsets.only(top: 12),
          child: Center(child: StepIndicator(current: 1)),
        ),
      ),
      bottomBar: DesignButton(
        label: '次へ',
        loading: _isLoading,
        onPressed: _isLoading ? null : _continueNext,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          const Center(child: _HealthIllustration(accent: _healthRed)),
          const SizedBox(height: 22),
          Text(
            'Healthと連携しますか？',
            textAlign: TextAlign.center,
            style: AppTypography.headingM,
          ),
          const SizedBox(height: 10),
          Text(
            'Appleのヘルスケアと連携すると、\n歩数や運動のデータが自動で取り込まれ、\n入力の手間を減らすことができます。',
            textAlign: TextAlign.center,
            style: AppTypography.bodyM,
          ),
          const SizedBox(height: 22),
          SelectCard(
            title: '連携する（推奨）',
            description: '歩数や運動のデータを自動で取り込み、\nよりカンタンに記録できます。',
            selected: _useHealthIntegration == true,
            onTap: _isLoading
                ? null
                : () => setState(() => _useHealthIntegration = true),
          ),
          const SizedBox(height: 14),
          SelectCard(
            title: '連携しない',
            description: 'あとから設定することもできます。\nすべて手動で入力します。',
            selected: _useHealthIntegration == false,
            onTap: _isLoading
                ? null
                : () => setState(() => _useHealthIntegration = false),
          ),
          const SizedBox(height: 14),
          _Note(
            text: widget.healthRepository.isAvailable
                ? 'お使いの端末がHealthに対応していない場合は、\n手動での入力方法をご案内します。'
                : 'この端末はHealthに対応していません。\n手動での入力方法をご案内します。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// ハートのカード → 3 点 → ブランドマーク、の並び（196×76）。
class _HealthIllustration extends StatelessWidget {
  const _HealthIllustration({required this.accent});

  final Color accent;

  /// Figma の BrandMark は 96 の箱に 66 のマークが入っている。
  static const double _markBoxToTight = 66 / 96;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      height: 76,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 6,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: AppIcon(AppIcons.heart, size: 34, color: accent),
            ),
          ),
          const Positioned(left: 84, top: 35, child: _Dots()),
          Positioned(
            left: 120,
            top: 0,
            child: SizedBox(
              width: 76,
              height: 76,
              child: Center(
                child: AppBrandMark(size: 76 * _markBoxToTight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      height: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_Dot(), _Dot(), _Dot()],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.borderDefault,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DesignIcon(
          Symbols.info_rounded,
          size: 18,
          color: AppColors.iconMuted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}
