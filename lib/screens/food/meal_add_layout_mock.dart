import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart' show Symbols;

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/food/ai_food_lookup_row.dart';

/// 食事を追加のレイアウト案。本番の導線には繋がない。
///
/// 見える選択は3つまで。写真、まとめた検索、折りたたんだその他。
class MealAddLayoutMock extends StatefulWidget {
  const MealAddLayoutMock({super.key});

  @override
  State<MealAddLayoutMock> createState() => _MealAddLayoutMockState();
}

class _MealAddLayoutMockState extends State<MealAddLayoutMock> {
  final _query = TextEditingController(text: '鶏むね');

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: DesignBackButton(),
          ),
          const SizedBox(height: 2),
          Text('食事を追加', style: AppTypography.headingL),
          const SizedBox(height: AppSpacing.md),
          DesignButton(
            label: '写真で登録 (β)',
            showTrailingIcon: false,
            leading: const DesignIcon(
              Symbols.photo_camera_rounded,
              size: 22,
              color: AppColors.textOnPrimary,
            ),
            onPressed: () {},
          ),
          const SizedBox(height: AppSpacing.md),
          DesignSearchField(
            controller: _query,
            hintText: '食品名・テンプレートで検索',
          ),
          const SizedBox(height: 6),
          Text(
            '保存済み、テンプレート、公開食品、成分表をまとめて探します。',
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _ResultRow(
            name: '鶏むね肉（皮なし）',
            detail: '100g · 108kcal',
            badge: '保存済み',
          ),
          const _ResultRow(
            name: '鶏むね肉のソテー',
            detail: '2品 · 420kcal',
            badge: 'テンプレート',
          ),
          const _ResultRow(
            name: '鶏むね肉 ハーブ焼き',
            detail: '1人前 · 260kcal',
            badge: '公開食品',
          ),
          const _ResultRow(
            name: 'にわとり むね 皮なし 生',
            detail: '100gあたり · 108kcal',
            badge: '成分表',
          ),
          const SizedBox(height: 8),
          AiFoodLookupRow(onTap: () {}),
          const SizedBox(height: AppSpacing.md),
          const _OtherMethods(),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.name,
    required this.detail,
    required this.badge,
  });

  final String name;
  final String detail;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.titleS),
                    Text(
                      detail,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TypeBadge(label: badge),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.green50,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: AppTypography.labelS.copyWith(color: AppColors.textBrand),
        ),
      ),
    );
  }
}

class _OtherMethods extends StatelessWidget {
  const _OtherMethods();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('その他の方法', style: AppTypography.titleS),
                  Text(
                    '手入力、バーコード',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const DesignIcon(
              Symbols.expand_more_rounded,
              size: 22,
              color: AppColors.iconMuted,
            ),
          ],
        ),
      ),
    );
  }
}
