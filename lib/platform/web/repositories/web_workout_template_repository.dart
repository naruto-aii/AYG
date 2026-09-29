import '../../../models/workout_template.dart';
import '../../../repositories/contracts/workout_template_repository_base.dart';
import '../../../utils/food_name_normalizer.dart';

/// Web向けインメモリ WorkoutTemplateRepository。
class WorkoutTemplateRepository implements WorkoutTemplateRepositoryBase {
  final List<WorkoutTemplate> _templates = [];
  final Map<String, List<WorkoutTemplateItem>> _itemsByTemplate = {};

  String _itemsKey(String ownerUserId, String templateId) =>
      '$ownerUserId::$templateId';

  @override
  Future<void> saveWithItems({
    required WorkoutTemplate template,
    required List<WorkoutTemplateItem> items,
  }) async {
    _templates.removeWhere(
      (item) =>
          item.templateId == template.templateId &&
          item.ownerUserId == template.ownerUserId,
    );
    _templates.add(template);
    _itemsByTemplate[_itemsKey(template.ownerUserId, template.templateId)] =
        List.of(items);
  }

  @override
  Future<WorkoutTemplate?> getById({
    required String ownerUserId,
    required String templateId,
  }) async {
    for (final template in _templates) {
      if (template.templateId == templateId &&
          template.ownerUserId == ownerUserId &&
          template.status == WorkoutTemplateStatus.active) {
        return template;
      }
    }
    return null;
  }

  @override
  Future<List<WorkoutTemplate>> getAll(String ownerUserId) async {
    return _templates
        .where(
          (template) =>
              template.ownerUserId == ownerUserId &&
              template.status == WorkoutTemplateStatus.active,
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<List<WorkoutTemplate>> search({
    required String ownerUserId,
    required String query,
  }) async {
    final normalizedQuery = FoodNameNormalizer.normalize(query);
    if (normalizedQuery.isEmpty) {
      return getAll(ownerUserId);
    }

    return _templates
        .where(
          (template) =>
              template.ownerUserId == ownerUserId &&
              template.status == WorkoutTemplateStatus.active &&
              template.normalizedName.contains(normalizedQuery),
        )
        .toList()
      ..sort((a, b) => a.normalizedName.compareTo(b.normalizedName));
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
          status: WorkoutTemplateStatus.deleted,
          deletedAt: deletedAt,
          updatedAt: deletedAt,
        );
        return;
      }
    }
  }

  @override
  Future<List<WorkoutTemplateItem>> getItems({
    required String ownerUserId,
    required String templateId,
  }) async {
    final items = List<WorkoutTemplateItem>.from(
      _itemsByTemplate[_itemsKey(ownerUserId, templateId)] ?? const [],
    )..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  @override
  Future<List<WorkoutTemplate>> loadAllOwnIncludingDeleted(
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

  @override
  Future<void> clearForOwner(String ownerUserId) async {
    _templates.removeWhere((template) => template.ownerUserId == ownerUserId);
    _itemsByTemplate.removeWhere((key, _) => key.startsWith('$ownerUserId::'));
  }

  @override
  Future<void> reassignOwnerUserId({
    required String fromOwnerUserId,
    required String toOwnerUserId,
  }) async {
    if (fromOwnerUserId == toOwnerUserId) {
      return;
    }

    for (var i = 0; i < _templates.length; i++) {
      final template = _templates[i];
      if (template.ownerUserId == fromOwnerUserId) {
        _templates[i] = template.copyWith(ownerUserId: toOwnerUserId);
      }
    }

    final migratedItems = <String, List<WorkoutTemplateItem>>{};
    for (final entry in _itemsByTemplate.entries.toList()) {
      if (!entry.key.startsWith('$fromOwnerUserId::')) {
        continue;
      }
      final templateId = entry.key.split('::').last;
      migratedItems['$toOwnerUserId::$templateId'] = entry.value;
      _itemsByTemplate.remove(entry.key);
    }
    _itemsByTemplate.addAll(migratedItems);
  }
}
