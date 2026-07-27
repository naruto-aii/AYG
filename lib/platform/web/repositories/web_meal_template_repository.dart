import '../../../models/meal_template.dart';
import '../../../repositories/contracts/meal_template_repository_base.dart';
import '../../../utils/food_name_normalizer.dart';

/// Web Preview 向け in-memory 食事テンプレート Repository。
class WebMealTemplateRepository implements MealTemplateRepositoryBase {
  final Map<String, MealTemplate> _templates = {};
  final Map<String, List<MealTemplateItem>> _items = {};

  String _templateKey(String ownerUserId, String templateId) =>
      '$ownerUserId:$templateId';

  @override
  Future<List<MealTemplate>> loadAllOwnIncludingDeleted(
    String ownerUserId,
  ) async {
    return _templates.values
        .where((template) => template.ownerUserId == ownerUserId)
        .toList();
  }

  @override
  Future<void> clearAll() async {
    _templates.clear();
    _items.clear();
  }

  @override
  Future<MealTemplate?> getById({
    required String ownerUserId,
    required String templateId,
  }) async => _templates[_templateKey(ownerUserId, templateId)];

  @override
  Future<List<MealTemplate>> getAll(String ownerUserId) async {
    final templates = _templates.values
        .where(
          (template) =>
              template.ownerUserId == ownerUserId &&
              template.status == TemplateStatus.active,
        )
        .toList();
    templates.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return templates;
  }

  @override
  Future<List<MealTemplateItem>> getItems({
    required String ownerUserId,
    required String templateId,
  }) async {
    final items = List<MealTemplateItem>.from(
      _items[_templateKey(ownerUserId, templateId)] ?? const [],
    );
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  @override
  Future<void> replaceItems({
    required String ownerUserId,
    required String templateId,
    required List<MealTemplateItem> items,
  }) async {
    _items[_templateKey(ownerUserId, templateId)] = List.of(items);
  }

  @override
  Future<void> save(MealTemplate template) async {
    _templates[_templateKey(template.ownerUserId, template.templateId)] =
        template;
  }

  @override
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

  @override
  Future<void> saveAll(List<MealTemplate> templates) async {
    for (final template in templates) {
      await save(template);
    }
  }

  @override
  Future<List<MealTemplate>> search({
    required String ownerUserId,
    required String query,
  }) async {
    final normalizedQuery = FoodNameNormalizer.normalize(query);
    if (normalizedQuery.isEmpty) {
      return getAll(ownerUserId);
    }
    return _templates.values
        .where(
          (template) =>
              template.ownerUserId == ownerUserId &&
              template.status == TemplateStatus.active &&
              template.normalizedName.contains(normalizedQuery),
        )
        .toList();
  }

  @override
  Future<void> softDelete({
    required String ownerUserId,
    required String templateId,
    required DateTime deletedAt,
  }) async {
    final template = await getById(
      ownerUserId: ownerUserId,
      templateId: templateId,
    );
    if (template == null) {
      return;
    }
    await save(
      template.copyWith(
        status: TemplateStatus.deleted,
        deletedAt: deletedAt,
        updatedAt: deletedAt,
      ),
    );
  }

  @override
  Future<void> update(MealTemplate template) => save(template);

  Future<void> replaceAllOwn({
    required String ownerUserId,
    required List<MealTemplate> templates,
    required Map<String, List<MealTemplateItem>> itemsByTemplateId,
  }) async {
    _templates.removeWhere((key, _) => key.startsWith('$ownerUserId:'));
    _items.removeWhere((key, _) => key.startsWith('$ownerUserId:'));
    for (final template in templates) {
      await save(template);
      await replaceItems(
        ownerUserId: ownerUserId,
        templateId: template.templateId,
        items: itemsByTemplateId[template.templateId] ?? const [],
      );
    }
  }
}
