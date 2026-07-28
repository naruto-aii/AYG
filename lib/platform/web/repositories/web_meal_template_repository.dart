import '../../../models/meal_template.dart';
import '../../../repositories/contracts/meal_template_repository_base.dart';
import '../../../utils/food_name_normalizer.dart';

/// Web向けインメモリ MealTemplateRepository。
class MealTemplateRepository implements MealTemplateRepositoryBase {
  final List<MealTemplate> _templates = [];
  final Map<String, List<MealTemplateItem>> _itemsByTemplate = {};

  String _itemsKey(String ownerUserId, String templateId) =>
      '$ownerUserId::$templateId';

  @override
  Future<void> save(MealTemplate template) async {
    _templates.removeWhere(
      (item) =>
          item.templateId == template.templateId &&
          item.ownerUserId == template.ownerUserId,
    );
    _templates.add(template);
  }

  @override
  Future<void> saveAll(List<MealTemplate> templates) async {
    for (final template in templates) {
      await save(template);
    }
  }

  @override
  Future<MealTemplate?> getById({
    required String ownerUserId,
    required String templateId,
  }) async {
    for (final template in _templates) {
      if (template.templateId == templateId &&
          template.ownerUserId == ownerUserId &&
          template.status == TemplateStatus.active) {
        return template;
      }
    }
    return null;
  }

  @override
  Future<List<MealTemplate>> getAll(String ownerUserId) async {
    final templates =
        _templates
            .where(
              (template) =>
                  template.ownerUserId == ownerUserId &&
                  template.status == TemplateStatus.active,
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return templates;
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

    final templates =
        _templates
            .where(
              (template) =>
                  template.ownerUserId == ownerUserId &&
                  template.status == TemplateStatus.active &&
                  template.normalizedName.contains(normalizedQuery),
            )
            .toList()
          ..sort((a, b) => a.normalizedName.compareTo(b.normalizedName));
    return templates;
  }

  @override
  Future<void> update(MealTemplate template) async {
    await save(template);
  }

  @override
  Future<void> softDelete({
    required String ownerUserId,
    required String templateId,
    required DateTime deletedAt,
  }) async {
    for (var i = 0; i < _templates.length; i++) {
      final template = _templates[i];
      if (template.templateId == templateId &&
          template.ownerUserId == ownerUserId) {
        _templates[i] = template.copyWith(
          status: TemplateStatus.deleted,
          deletedAt: deletedAt,
          updatedAt: deletedAt,
        );
        return;
      }
    }
  }

  @override
  Future<void> replaceItems({
    required String ownerUserId,
    required String templateId,
    required List<MealTemplateItem> items,
  }) async {
    _itemsByTemplate[_itemsKey(ownerUserId, templateId)] = List.of(items);
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
  Future<List<MealTemplateItem>> getItems({
    required String ownerUserId,
    required String templateId,
  }) async {
    final items = List<MealTemplateItem>.from(
      _itemsByTemplate[_itemsKey(ownerUserId, templateId)] ?? const [],
    )..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  @override
  Future<List<MealTemplate>> loadAllOwnIncludingDeleted(
    String ownerUserId,
  ) async {
    return _templates
        .where((template) => template.ownerUserId == ownerUserId)
        .toList();
  }

  @override
  Future<void> clearAll() async {
    _templates.clear();
    _itemsByTemplate.clear();
  }
}
