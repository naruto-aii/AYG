import '../../models/meal_template.dart';

abstract class MealTemplateRepositoryBase {
  Future<void> save(MealTemplate template);

  Future<void> saveAll(List<MealTemplate> templates);

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

  Future<List<MealTemplateItem>> getItems({
    required String ownerUserId,
    required String templateId,
  });

  Future<void> clearAll();
}
