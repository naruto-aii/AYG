import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/photo_meal.dart';
import '../../services/photo_meal_client.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';

/// 量の下に出す説明。数値が量に合わせて変わることを伝える。
const photoMealAmountScaleHint = '量に合わせて、カロリーとPFCも自動で変わります。';

/// 料理名が未入力のとき、記録の前に名前の確認を出す。
Future<String?> askPhotoMealDishName(BuildContext context, String prefilled) {
  return showDialog<String>(
    context: context,
    routeSettings: const RouteSettings(name: 'photo_meal_name_dialog'),
    builder: (context) => _DishNameDialog(prefilled: prefilled),
  );
}

class _DishNameDialog extends StatefulWidget {
  const _DishNameDialog({required this.prefilled});

  final String prefilled;

  @override
  State<_DishNameDialog> createState() => _DishNameDialogState();
}

class _DishNameDialogState extends State<_DishNameDialog> {
  late final TextEditingController _field;
  String? _error;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController(text: widget.prefilled);
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('料理名を確認してください'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('料理名の入力がなかったので、記録する名前を確認してください。'),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('photo_meal_name_confirm'),
            controller: _field,
            autofocus: true,
            decoration: InputDecoration(labelText: '料理名', errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            final name = _field.text.trim();
            if (name.isEmpty) {
              setState(() => _error = '料理名を入力してください');
              return;
            }
            Navigator.of(context).pop(name);
          },
          child: const Text('この名前で登録'),
        ),
      ],
    );
  }
}

/// 推定を直してから、手入力と同じ経路で 1 件保存する。
class PhotoMealConfirmScreen extends StatefulWidget {
  const PhotoMealConfirmScreen({
    super.key,
    required this.controller,
    required this.loggedAt,
    required this.analysis,
    required this.hadUserDishName,
    this.title = '推定の確認',
    this.subtitle = 'これはAIの推定です。登録の前に確認して、数値を直せます。',
    this.recordEdit,
  });

  final AppController controller;
  final DateTime loggedAt;
  final PhotoMealAnalysis analysis;

  /// 写真の画面で料理名を入れていたか。無いときは保存時に確認する。
  final bool hadUserDishName;
  final String title;
  final String subtitle;
  final Future<void> Function(String usageId, bool edited)? recordEdit;

  @override
  State<PhotoMealConfirmScreen> createState() => _PhotoMealConfirmScreenState();
}

class _PhotoMealConfirmScreenState extends State<PhotoMealConfirmScreen> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _kcal;
  late final TextEditingController _protein;
  late final TextEditingController _fat;
  late final TextEditingController _carb;
  bool _saving = false;

  /// 最後に掛け直した量の数。数が同じなら（単位だけ変えても）掛け直さない。
  double? _lastAmountNumber;

  PhotoMealEstimate get _estimate => widget.analysis.estimate;

  bool get _amountScales => leadingPhotoAmountNumber(_estimate.amount) != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _estimate.dishName);
    _amount = TextEditingController(text: _estimate.amount);
    _kcal = TextEditingController(text: formatPhotoNumber(_estimate.kcal));
    _protein = TextEditingController(
      text: formatPhotoNumber(_estimate.proteinG),
    );
    _fat = TextEditingController(text: formatPhotoNumber(_estimate.fatG));
    _carb = TextEditingController(text: formatPhotoNumber(_estimate.carbG));
    _lastAmountNumber = leadingPhotoAmountNumber(_estimate.amount);
  }

  /// 量を変えたら、元の推定から 4 つとも計算し直す。表示した値をそのまま保存する。
  void _onAmountChanged(String text) {
    final number = leadingPhotoAmountNumber(text);
    if (number == null || number == _lastAmountNumber) {
      return;
    }
    final scaled = scalePhotoMealEstimate(_estimate, text);
    if (scaled == null) {
      return;
    }
    _lastAmountNumber = number;
    setState(() {
      _kcal.text = formatPhotoNumber(scaled.kcal);
      _protein.text = formatPhotoNumber(scaled.proteinG);
      _fat.text = formatPhotoNumber(scaled.fatG);
      _carb.text = formatPhotoNumber(scaled.carbG);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _kcal.dispose();
    _protein.dispose();
    _fat.dispose();
    _carb.dispose();
    super.dispose();
  }

  double? _number(String raw, double max) {
    final value = double.tryParse(raw.trim());
    if (value == null || !value.isFinite || value < 0 || value > max) {
      return null;
    }
    return value;
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    var name = _name.text.trim();
    if (!widget.hadUserDishName) {
      final confirmed = await askPhotoMealDishName(context, name);
      if (!mounted || confirmed == null) {
        return;
      }
      name = confirmed;
      _name.text = confirmed;
    }
    if (name.isEmpty) {
      _message('料理名を入力してください');
      return;
    }
    final kcal = _number(_kcal.text, photoMealMaxKcal);
    final protein = _number(_protein.text, photoMealMaxMacroG);
    final fat = _number(_fat.text, photoMealMaxMacroG);
    final carb = _number(_carb.text, photoMealMaxMacroG);
    if (kcal == null || protein == null || fat == null || carb == null) {
      _message('カロリーとPFCは、0以上の範囲で入れてください');
      return;
    }
    setState(() => _saving = true);
    try {
      await saveConfirmedPhotoMeal(
        controller: widget.controller,
        loggedAt: widget.loggedAt,
        name: name,
        amountText: _amount.text,
        kcal: kcal,
        proteinG: protein,
        fatG: fat,
        carbG: carb,
      );
      final edited = photoMealWasEdited(
        original: _estimate,
        name: name,
        amount: _amount.text,
        kcal: kcal,
        proteinG: protein,
        fatG: fat,
        carbG: carb,
      );
      final usageId = widget.analysis.usageId;
      if (usageId != null) {
        final record = widget.recordEdit ?? _recordEdit;
        await record(usageId, edited);
      }
      final collectionId = widget.analysis.collectionId;
      if (collectionId != null) {
        await recordAiFoodResultOutcome(
          collectionId: collectionId,
          edited: edited,
          name: name,
          amount: _amount.text,
          kcal: kcal,
          proteinG: protein,
          fatG: fat,
          carbG: carb,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('[AYG] photo meal save failed: $error');
      _message('食事の保存に失敗しました');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _recordEdit(String usageId, bool edited) {
    return recordPhotoMealEdit(usageId: usageId, edited: edited);
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final items = _estimate.items;
    return DesignPage(
      bottomBar: DesignButton(
        label: 'この内容で登録',
        showTrailingIcon: false,
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitleBlock(title: widget.title, subtitle: widget.subtitle),
          const SizedBox(height: AppSpacing.md),
          _field('料理名', _name, hint: '例）親子丼'),
          const SizedBox(height: AppSpacing.md),
          _field(
            '量',
            _amount,
            hint: '例）200g',
            inputKey: const Key('photo-meal-amount'),
            onChanged: _onAmountChanged,
          ),
          if (_amountScales) ...[
            const SizedBox(height: 6),
            Text(
              photoMealAmountScaleHint,
              key: const Key('photo-meal-amount-hint'),
              style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _numberField('カロリー', _kcal, 'kcal', const Key('photo-meal-kcal')),
          const SizedBox(height: AppSpacing.sm),
          _numberField('たんぱく質', _protein, 'g', const Key('photo-meal-protein')),
          const SizedBox(height: AppSpacing.sm),
          _numberField('脂質', _fat, 'g', const Key('photo-meal-fat')),
          const SizedBox(height: AppSpacing.sm),
          _numberField('炭水化物', _carb, 'g', const Key('photo-meal-carb')),
          if (items.length > 1) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('品ごとの推定', style: AppTypography.titleS),
            const SizedBox(height: AppSpacing.sm),
            DesignCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${item.name} ${item.amount}  ${formatPhotoNumber(item.kcal)}kcal',
                        style: AppTypography.bodyS,
                      ),
                    ),
                  Text(
                    '合計を1件として記録します。',
                    style: AppTypography.bodyS.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    Key? inputKey,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTypography.titleS),
        const SizedBox(height: 6),
        DesignInputBox(
          child: DesignTextInput(
            controller: controller,
            hintText: hint,
            inputKey: inputKey,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _numberField(
    String label,
    TextEditingController controller,
    String unit,
    Key inputKey,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTypography.titleS),
        const SizedBox(height: 6),
        DesignInputBox(
          suffix: unit,
          child: DesignTextInput(
            controller: controller,
            inputKey: inputKey,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
          ),
        ),
      ],
    );
  }
}
