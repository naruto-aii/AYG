import '../../models/meal_template.dart';

abstract class MealTemplateRepositoryBase {
  Future<void> save(MealTemplate template);

  Future<void> saveAll(List<MealTemplate> templates);

  Future<void> saveWithItems({
    required MealTemplate template,
    required List<MealTemplateItem> items,
  });

  Future<MealTemplate?> getById({
    required String ownerUserId,
    required String templateId,
  });

  Future<List<MealTemplate>> getAll(String ownerUserId);

  Future<List<MealTemplate>> search({
    required String ownerUserId,
    required String query,
  });

  Future<void> update(MealTemplate template);

  Future<void> softDelete({
    required String ownerUserId,
    required String templateId,
    required DateTime deletedAt,
  });

  Future<void> replaceItems({
    required String ownerUserId,
    required String templateId,
    required List<MealTemplateItem> items,
  });

  Future<void> saveWithItems({
    required MealTemplate template,
    required List<MealTemplateItem> items,
  }) async {
    await save(template);
    await replaceItems(
      ownerUserId: template.ownerUserId,
      templateId: template.templateId,
      items: items,
    );
  }

  Future<List<MealTemplateItem>> getItems({
    required String ownerUserId,
    required String templateId,
  });

  Future<List<MealTemplate>> loadAllOwnIncludingDeleted(String ownerUserId);

  Future<void> clearAll();
}
