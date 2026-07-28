import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/contracts/meal_template_repository_base.dart';
import 'package:ayg/state/app_controller.dart';

import '../test/mocks/mock_authentication_repository.dart';
import '../test/mocks/mock_health_repository.dart';

const prototypeMealTemplateUserId = 'prototype-user';
const prototypeMealTemplateEditId = 'tmpl-morning';

class _PrototypeMealTemplateRepository implements MealTemplateRepositoryBase {
  _PrototypeMealTemplateRepository({
    required List<MealTemplate> templates,
    required Map<String, List<MealTemplateItem>> itemsByTemplateId,
  }) : _templates = templates,
       _itemsByTemplateId = itemsByTemplateId;

  final List<MealTemplate> _templates;
  final Map<String, List<MealTemplateItem>> _itemsByTemplateId;

  @override
  Future<void> clearAll() async {}

  @override
  Future<MealTemplate?> getById({
    required String ownerUserId,
    required String templateId,
  }) async {
    for (final template in _templates) {
      if (template.templateId == templateId &&
          template.ownerUserId == ownerUserId) {
        return template;
      }
    }
    return null;
  }

  @override
  Future<List<MealTemplate>> getAll(String ownerUserId) async {
    return _templates
        .where((template) => template.ownerUserId == ownerUserId)
        .toList(growable: false);
  }

  @override
  Future<List<MealTemplate>> search({
    required String ownerUserId,
    required String query,
  }) async {
    final owned = await getAll(ownerUserId);
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return owned;
    }
    return owned
        .where((template) => template.name.contains(trimmed))
        .toList(growable: false);
  }

  @override
  Future<List<MealTemplateItem>> getItems({
    required String ownerUserId,
    required String templateId,
  }) async {
    final template = await getById(
      ownerUserId: ownerUserId,
      templateId: templateId,
    );
    if (template == null) {
      return const [];
    }
    return List<MealTemplateItem>.from(
      _itemsByTemplateId[templateId] ?? const [],
    );
  }

  @override
  Future<void> replaceItems({
    required String ownerUserId,
    required String templateId,
    required List<MealTemplateItem> items,
  }) async {}

  @override
  Future<void> save(MealTemplate template) async {}

  @override
  Future<void> saveAll(List<MealTemplate> templates) async {}

  @override
  Future<void> softDelete({
    required String ownerUserId,
    required String templateId,
    required DateTime deletedAt,
  }) async {}

  @override
  Future<void> update(MealTemplate template) async {}
}

List<MealTemplate> prototypeMealTemplates(DateTime now) {
  return [
    MealTemplate(
      templateId: 'tmpl-morning',
      ownerUserId: prototypeMealTemplateUserId,
      name: '朝食セット',
      normalizedName: '朝食セット',
      totalKcal: 1164,
      totalProteinG: 67,
      totalFatG: 15,
      totalCarbG: 149,
      useCount: 12,
      lastUsedAt: now,
      createdAt: now,
      updatedAt: now,
    ),
    MealTemplate(
      templateId: 'tmpl-lunch',
      ownerUserId: prototypeMealTemplateUserId,
      name: '昼食コンボ',
      normalizedName: '昼食コンボ',
      totalKcal: 1014,
      totalProteinG: 62,
      totalFatG: 12,
      totalCarbG: 147,
      useCount: 8,
      lastUsedAt: now.subtract(const Duration(days: 2)),
      createdAt: now,
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    MealTemplate(
      templateId: 'tmpl-snack',
      ownerUserId: prototypeMealTemplateUserId,
      name: '夜食軽食',
      normalizedName: '夜食軽食',
      totalKcal: 150,
      totalProteinG: 5,
      totalFatG: 3,
      totalCarbG: 27,
      useCount: 3,
      lastUsedAt: now.subtract(const Duration(days: 5)),
      createdAt: now,
      updatedAt: now.subtract(const Duration(days: 5)),
    ),
  ];
}

Map<String, List<MealTemplateItem>> prototypeMealTemplateItems(DateTime now) {
  return {
    'tmpl-morning': [
      MealTemplateItem(
        itemId: 'item-1',
        name: 'サラダチキン',
        baseAmount: 100,
        unitType: FoodUnitType.g,
        kcalPerBase: 428,
        proteinPerBase: 50,
        fatPerBase: 8,
        carbPerBase: 2,
        consumedAmount: 100,
        sortOrder: 1,
        snapshotSavedAt: now,
      ),
      MealTemplateItem(
        itemId: 'item-2',
        name: '玄米おにぎり',
        baseAmount: 1,
        unitType: FoodUnitType.piece,
        kcalPerBase: 586,
        proteinPerBase: 12,
        fatPerBase: 4,
        carbPerBase: 120,
        consumedAmount: 1,
        sortOrder: 2,
        snapshotSavedAt: now,
      ),
      MealTemplateItem(
        itemId: 'item-3',
        name: 'オートミール',
        baseAmount: 40,
        unitType: FoodUnitType.g,
        kcalPerBase: 150,
        proteinPerBase: 5,
        fatPerBase: 3,
        carbPerBase: 27,
        consumedAmount: 40,
        sortOrder: 3,
        snapshotSavedAt: now,
      ),
    ],
    'tmpl-lunch': [
      MealTemplateItem(
        itemId: 'item-4',
        name: 'サラダチキン',
        baseAmount: 100,
        unitType: FoodUnitType.g,
        kcalPerBase: 428,
        proteinPerBase: 50,
        fatPerBase: 8,
        carbPerBase: 2,
        consumedAmount: 100,
        sortOrder: 1,
        snapshotSavedAt: now,
      ),
      MealTemplateItem(
        itemId: 'item-5',
        name: '玄米おにぎり',
        baseAmount: 1,
        unitType: FoodUnitType.piece,
        kcalPerBase: 586,
        proteinPerBase: 12,
        fatPerBase: 4,
        carbPerBase: 120,
        consumedAmount: 1,
        sortOrder: 2,
        snapshotSavedAt: now,
      ),
    ],
    'tmpl-snack': [
      MealTemplateItem(
        itemId: 'item-6',
        name: 'オートミール',
        baseAmount: 40,
        unitType: FoodUnitType.g,
        kcalPerBase: 150,
        proteinPerBase: 5,
        fatPerBase: 3,
        carbPerBase: 27,
        consumedAmount: 40,
        sortOrder: 1,
        snapshotSavedAt: now,
      ),
    ],
  };
}

AppController createPrototypeMealTemplateController() {
  final now = DateTime(2026, 7, 20);
  return AppController(
    healthRepository: MockHealthRepository(isAvailable: false),
    authenticationRepository: MockAuthenticationRepository(
      currentUser: const AuthUser(
        id: prototypeMealTemplateUserId,
        email: 'prototype@example.com',
      ),
    ),
    mealTemplateRepository: _PrototypeMealTemplateRepository(
      templates: prototypeMealTemplates(now),
      itemsByTemplateId: prototypeMealTemplateItems(now),
    ),
  );
}

/// Screenshot用の編集対象テンプレートID。
const prototypeMealTemplateFormId = prototypeMealTemplateEditId;
