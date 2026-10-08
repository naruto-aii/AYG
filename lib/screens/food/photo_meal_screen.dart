import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart' show Symbols;

import '../../services/photo_meal.dart';
import '../../services/photo_meal_client.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/app_chip.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import 'photo_meal_confirm_screen.dart';

/// カメラかカメラロールから JPEG を渡す。テストは差し替える。
abstract class MealPhotoSource {
  Future<Uint8List?> takePhoto();
  Future<Uint8List?> pickFromLibrary();
}

class ImagePickerMealPhotoSource implements MealPhotoSource {
  ImagePickerMealPhotoSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<Uint8List?> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: photoMealLongEdge.toDouble(),
      maxHeight: photoMealLongEdge.toDouble(),
      imageQuality: 80,
      requestFullMetadata: false,
    );
    if (file == null) {
      return null;
    }
    return file.readAsBytes();
  }

  @override
  Future<Uint8List?> takePhoto() => _pick(ImageSource.camera);

  @override
  Future<Uint8List?> pickFromLibrary() => _pick(ImageSource.gallery);
}

/// 写真で登録 (β)。写真は必須。料理名と量は任意。
class PhotoMealScreen extends StatefulWidget {
  const PhotoMealScreen({
    super.key,
    required this.controller,
    required this.loggedAt,
    required this.client,
    this.source,
    this.recordEdit,
  });

  final AppController controller;
  final DateTime loggedAt;
  final PhotoMealClient client;
  final MealPhotoSource? source;

  /// 保存後に、直したかどうかを書く。未指定なら Supabase の本人の行を更新する。
  final Future<void> Function(String usageId, bool edited)? recordEdit;

  @override
  State<PhotoMealScreen> createState() => _PhotoMealScreenState();
}

class _PhotoMealScreenState extends State<PhotoMealScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Uint8List? _jpeg;
  bool _busy = false;

  MealPhotoSource get _source => widget.source ?? ImagePickerMealPhotoSource();

  @override
  void initState() {
    super.initState();
    _noteController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _appendChip(String chip) {
    final next = appendPhotoMealNote(_noteController.text, chip);
    if (next == _noteController.text) {
      return;
    }
    _noteController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _capture(Future<Uint8List?> Function() pick) async {
    try {
      final bytes = await pick();
      if (!mounted || bytes == null) {
        return;
      }
      final jpeg = compressMealPhoto(bytes);
      setState(() => _jpeg = jpeg);
    } on FormatException {
      _message('写真を読み取れませんでした。別の写真を選ぶか、手入力で記録できます。');
    } catch (error) {
      debugPrint('[AYG] photo meal pick failed: $error');
      _message('写真を読み取れませんでした。別の写真を選ぶか、手入力で記録できます。');
    }
  }

  Future<void> _submit() async {
    final jpeg = _jpeg;
    if (jpeg == null || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final analysis = await widget.client.analyze(
        jpeg: jpeg,
        dishName: _nameController.text,
        amount: _amountController.text,
        note: _noteController.text,
      );
      if (!mounted) {
        return;
      }
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          settings: const RouteSettings(name: 'photo_meal_confirm'),
          builder: (context) => PhotoMealConfirmScreen(
            controller: widget.controller,
            loggedAt: widget.loggedAt,
            analysis: analysis,
            hadUserDishName: _nameController.text.trim().isNotEmpty,
            recordEdit: widget.recordEdit,
          ),
        ),
      );
      if (saved == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } on PhotoMealFailure catch (error) {
      _message(error.message);
    } catch (error) {
      debugPrint('[AYG] photo meal analyze failed: $error');
      _message(photoMealFallbackMessage);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final jpeg = _jpeg;
    return DesignPage(
      bottomBar: DesignButton(
        label: '推定する',
        showTrailingIcon: false,
        loading: _busy,
        onPressed: jpeg == null || _busy ? null : _submit,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: '写真で登録 (β)',
            subtitle:
                '食事の写真から、カロリーとPFCを推定します。これはAIの推定です。登録の前に確認して、数値を直せます。\n写真は栄養の推定に使い、カロナビには保存しません。',
          ),
          if (jpeg != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                jpeg,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            DesignCard(
              child: Text(
                '写真を1枚選んでください。',
                style: AppTypography.bodyM,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          DesignButton(
            label: '写真を撮る',
            style: DesignButtonStyle.outline,
            showTrailingIcon: false,
            leading: const DesignIcon(Symbols.photo_camera_rounded, size: 22),
            onPressed: _busy ? null : () => _capture(_source.takePhoto),
          ),
          const SizedBox(height: AppSpacing.sm),
          DesignButton(
            label: 'カメラロールから選ぶ',
            style: DesignButtonStyle.outline,
            showTrailingIcon: false,
            leading: const DesignIcon(Symbols.photo_library_rounded, size: 22),
            onPressed: _busy ? null : () => _capture(_source.pickFromLibrary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('料理名', style: AppTypography.titleS),
          const SizedBox(height: 4),
          Text(
            '任意です。入れると精度が上がります。',
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          DesignInputBox(
            child: DesignTextInput(
              key: const ValueKey('photo_meal_name'),
              controller: _nameController,
              hintText: '例）親子丼',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('量', style: AppTypography.titleS),
          const SizedBox(height: 4),
          Text(
            '任意です。グラム・個数・杯数など、できるだけ正確に入れると精度が上がります。',
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          DesignInputBox(
            child: DesignTextInput(
              key: const ValueKey('photo_meal_amount'),
              controller: _amountController,
              hintText: '例）200g、2個、丼1杯',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('補足', style: AppTypography.titleS),
          const SizedBox(height: 4),
          Text(
            '任意です。油を多めに使った、脂身が多い、ソース少なめなど、写真で分かりにくい特徴を書くと精度が上がります。',
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in photoMealNoteChips)
                AppChip(
                  label: chip,
                  selected: _noteController.text.contains(chip),
                  onTap: _busy ? null : () => _appendChip(chip),
                ),
            ],
          ),
          const SizedBox(height: 6),
          DesignInputBox(
            child: DesignTextInput(
              key: const ValueKey('photo_meal_note'),
              controller: _noteController,
              hintText: '例）油多めで炒めた、脂身多め',
              inputFormatters: [
                LengthLimitingTextInputFormatter(photoMealNoteMaxLength),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
