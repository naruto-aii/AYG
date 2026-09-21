import 'package:flutter/material.dart';

import '../../models/health_profile_data.dart';
import '../../models/weight_entry.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import '../../utils/local_date.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/home_parts.dart';
import '../../widgets/design/weight_parts.dart';
import 'weight_record_screen.dart';

/// グラフの表示期間。
enum WeightRange {
  week('1週間', 7),
  month('1ヶ月', 31),
  quarter('3ヶ月', 92),
  year('1年', 365);

  const WeightRange(this.label, this.days);

  final String label;
  final int days;
}

/// 体重タブ。
///
/// Figma: SP / 09 体重（30:955）
class WeightTabScreen extends StatefulWidget {
  const WeightTabScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<WeightTabScreen> createState() => _WeightTabScreenState();
}

class _WeightTabScreenState extends State<WeightTabScreen> {
  /// Figma の一覧は 7 行。それ以上は「すべて見る」で広げる。
  static const int _collapsedCount = 7;

  WeightRange _range = WeightRange.month;
  bool _showAll = false;

  List<WeightEntry> get _sorted {
    final entries = [...widget.controller.weightEntries]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return entries;
  }

  List<WeightEntry> _inRange(List<WeightEntry> entries) {
    final from = DateTime.now().subtract(Duration(days: _range.days));
    return entries.where((e) => e.recordedAt.isAfter(from)).toList();
  }

  void _openRecord({WeightEntry? entry}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WeightRecordScreen(
          controller: widget.controller,
          entry: entry,
          initialWeightKg:
              entry?.weightKg ?? widget.controller.profile?.weightKg,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(WeightEntry entry) async {
    await confirmDeleteWithUndo<WeightEntry>(
      context: context,
      title: '削除確認',
      message: '${formatJapaneseDateWithWeekday(entry.recordedAt)} の記録を削除しますか？',
      snapshot: entry,
      onDelete: () => widget.controller.deleteWeightEntry(entry.id),
      onRestore: (restored) => widget.controller.restoreWeightEntry(restored),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final all = _sorted;
        final ranged = _inRange(all);
        final latest = all.isEmpty ? null : all.last;
        final previous = all.length < 2 ? null : all[all.length - 2];
        final newestFirst = all.reversed.toList();
        final visible = _showAll
            ? newestFirst
            : newestFirst.take(_collapsedCount).toList();

        return DesignPage(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('体重', style: AppTypography.headingL),
              const SizedBox(height: 2),
              Text(
                'からだの変化を、\nやさしく見える化',
                style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              _chartCard(latest, previous, ranged),
              const SizedBox(height: 12),
              DesignButton(
                label: '体重を記録',
                showTrailingIcon: false,
                onPressed: () => _openRecord(),
              ),
              const SizedBox(height: 12),
              DesignSectionHeader(
                icon: AppIcons.scale,
                title: '体重の記録',
                actionLabel: newestFirst.length > _collapsedCount
                    ? (_showAll ? '折りたたむ' : 'すべて見る')
                    : null,
                onAction: () => setState(() => _showAll = !_showAll),
              ),
              const SizedBox(height: 4),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'まだ体重の記録がありません',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyS.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              else
                for (final entry in visible)
                  WeightRow(
                    dateLabel: formatJapaneseDateWithWeekday(entry.recordedAt),
                    weight: entry.weightKg.toStringAsFixed(1),
                    fromHealth: entry.source == WeightSource.health,
                    onTap: () => _openRecord(entry: entry),
                    onMore: () => _confirmDelete(entry),
                  ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _chartCard(
    WeightEntry? latest,
    WeightEntry? previous,
    List<WeightEntry> ranged,
  ) {
    final diff = latest == null || previous == null
        ? null
        : latest.weightKg - previous.weightKg;

    return DesignCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '最新の体重',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          latest == null
                              ? '--'
                              : latest.weightKg.toStringAsFixed(1),
                          style: AppTypography.valueXl,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'kg',
                          style: AppTypography.titleM.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      latest == null
                          ? '記録するとここに出ます'
                          : formatJapaneseDateWithWeekday(latest.recordedAt),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (diff != null) _DiffBadge(diff: diff),
            ],
          ),
          const SizedBox(height: 10),
          if (ranged.length < 2)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  '2回以上記録すると、ここに推移が出ます',
                  style: AppTypography.bodyS.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          else
            WeightChart(values: [for (final e in ranged) e.weightKg]),
          const SizedBox(height: 10),
          _axis(ranged),
          const SizedBox(height: 10),
          DesignChipGroup<WeightRange>(
            values: WeightRange.values,
            labelOf: (range) => range.label,
            selected: _range,
            onChanged: (range) => setState(() => _range = range),
          ),
        ],
      ),
    );
  }

  Widget _axis(List<WeightEntry> ranged) {
    if (ranged.length < 2) {
      return const SizedBox(height: 15);
    }
    final first = ranged.first.recordedAt;
    final last = ranged.last.recordedAt;
    String label(DateTime date) => '${date.month}/${date.day}';

    return SizedBox(
      height: 15,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label(first),
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          Text(
            label(last),
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// 「前回から -0.6 kg」のバッジ。
class _DiffBadge extends StatelessWidget {
  const _DiffBadge({required this.diff});

  final double diff;

  @override
  Widget build(BuildContext context) {
    final decreased = diff <= 0;
    final color = decreased ? AppColors.textBrand : AppColors.textAccent;

    return Container(
      width: 91,
      height: 55,
      decoration: BoxDecoration(
        color: decreased
            ? AppColors.bgSurfaceGreen
            : AppColors.bgSurfaceWarning,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '前回から',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              DesignIcon(
                decreased
                    ? Symbols.arrow_downward_rounded
                    : Symbols.arrow_upward_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 2),
              Text(
                diff.abs().toStringAsFixed(1),
                style: AppTypography.valueM.copyWith(color: color),
              ),
              const SizedBox(width: 2),
              Text('kg', style: AppTypography.labelS.copyWith(color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
