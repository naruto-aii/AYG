import 'package:flutter/material.dart';

import '../../widgets/common/app_keyboard_dismiss.dart';
import '../../models/food_unit_type.dart';
import '../../repositories/subscription_exceptions.dart';
import '../../models/macro_field.dart';
import '../../models/meal_template_draft.dart';
import '../../state/app_controller.dart';
import '../meal_template/meal_template_form_screen.dart';
import '../subscription/calonavi_plus_screen.dart';
import 'food_meal_registration_screen.dart';

/// 食事フォームからテンプレート関連の導線を開く。
Future<void> openFoodTemplateCreate(
  BuildContext context,
  AppController controller,
) async {
  final allowed = await guardPlusFeature(
    context: context,
    controller: controller,
    ensure: controller.ensureCanCreateMealTemplate,
  );
  if (!allowed || !context.mounted) {
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => MealTemplateFormScreen(controller: controller),
    ),
  );
}

Future<void> openFoodTemplatePicker({
  required BuildContext context,
  required AppController controller,
  DateTime? initialLoggedAt,
  VoidCallback? onMealRegistered,
}) async {
  final registered = await openFoodMealRegistrationFromTemplatePicker(
    context: context,
    controller: controller,
    initialLoggedAt: initialLoggedAt,
  );
  if (registered == true) {
    onMealRegistered?.call();
  }
}

Future<void> saveCurrentFoodAsTemplate({
  required BuildContext context,
  required AppController controller,
  required MealTemplateItemDraft itemDraft,
}) async {
  final nameController = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('テンプレートとして保存'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(
          labelText: 'テンプレート名',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => dismissAppKeyboard(),
        onTapOutside: (_) => dismissAppKeyboard(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('保存'),
        ),
      ],
    ),
  );

  if (saved != true || !context.mounted) {
    nameController.dispose();
    return;
  }

  final name = nameController.text.trim();
  nameController.dispose();
  if (name.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('テンプレート名を入力してください')));
    return;
  }

  try {
    await controller.ensureCanCreateMealTemplate();
    await controller.saveMealTemplate(
      draft: MealTemplateDraft(name: name, items: [itemDraft]),
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('「$name」をテンプレートとして保存しました')));
  } on SubscriptionLimitExceededException {
    if (context.mounted) {
      await showCalonaviPlus(context, controller.subscriptionRepository);
    }
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('テンプレートの保存に失敗しました: $error')));
  }
}

MealTemplateItemDraft? buildMealTemplateItemDraftFromFoodForm({
  required String name,
  required double consumedAmount,
  required double baseAmount,
  required FoodUnitType unitType,
  required double? kcalPerBase,
  required double? proteinPerBase,
  required double? fatPerBase,
  required double? carbPerBase,
  String? savedFoodId,
  String? sourceOwnerUserId,
}) {
  if (name.trim().isEmpty || consumedAmount <= 0) {
    return null;
  }

  return MealTemplateItemDraft(
    name: name.trim(),
    baseAmount: baseAmount,
    unitType: unitType,
    kcalPerBase: kcalPerBase,
    proteinPerBase: proteinPerBase,
    fatPerBase: fatPerBase,
    carbPerBase: carbPerBase,
    consumedAmount: consumedAmount,
    sortOrder: 1,
    savedFoodId: savedFoodId,
    sourceOwnerUserId: sourceOwnerUserId,
  );
}
