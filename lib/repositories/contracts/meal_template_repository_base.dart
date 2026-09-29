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

  Future<List<MealTemplateItem>> getItems({
    required String ownerUserId,
    required String templateId,
  });

  Future<List<MealTemplate>> loadAllOwnIncludingDeleted(String ownerUserId);

  Future<void> clearAll();

  /// 指定 owner のテンプレートと items のみ削除。
  Future<void> clearForOwner(String ownerUserId);

  /// ログイン時に local-user 所有データを認証ユーザーへ移行。
  Future<void> reassignOwnerUserId({
    required String fromOwnerUserId,
    required String toOwnerUserId,
  });
}
