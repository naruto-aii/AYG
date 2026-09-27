import 'dart:io';

import 'package:ayg/moderation/public_food_banned_words.dart';
import 'package:ayg/moderation/public_food_name_moderation.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/exceptions/food_master_exceptions.dart';
import 'package:ayg/repositories/supabase/supabase_error_mapper.dart';
import 'package:ayg/services/publish_error_messages.dart';
import 'package:ayg/services/saved_food_publish_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('PublicFoodNameModeration', () {
    test('halfwidth katakana maps are the same length', () {
      expect(
        publicFoodHalfwidthKatakanaFrom.runes.length,
        publicFoodHalfwidthKatakanaTo.runes.length,
      );
    });

    test('allows ordinary food names', () {
      const names = [
        'キャベツ',
        '鶏むね肉',
        '味噌汁',
        'バナナ',
        'イエロー',
        'shiitake',
        'sea bass',
        'grape',
        'cocktail',
        'classic',
      ];
      for (final name in names) {
        expect(PublicFoodNameModeration.isBanned(name), isFalse, reason: name);
      }
    });

    test('rejects normalized latin, kana, and spacing', () {
      expect(PublicFoodNameModeration.isBanned('  FUCK '), isTrue);
      expect(PublicFoodNameModeration.isBanned('ｆｕｃｋ'), isTrue);
      expect(PublicFoodNameModeration.isBanned('f u c k'), isTrue);
      expect(PublicFoodNameModeration.isBanned('ﾌｧｯｸ'), isTrue);
      expect(PublicFoodNameModeration.isBanned('ファック'), isTrue);
      expect(PublicFoodNameModeration.isBanned('うんこカレー'), isTrue);
      expect(PublicFoodNameModeration.isBanned('チンコ'), isTrue);
    });

    test('does not treat an unchanged public name as a new rejection', () {
      expect(
        PublicFoodNameModeration.rejectsPublicUpdate(
          previousName: 'fuck',
          nextName: 'fuck',
        ),
        isFalse,
      );
      expect(
        PublicFoodNameModeration.rejectsPublicUpdate(
          previousName: 'キャベツ',
          nextName: 'うんこ',
        ),
        isTrue,
      );
    });
  });

  group('SavedFoodPublishValidator banned names', () {
    const validator = SavedFoodPublishValidator();

    test('adds the Japanese message for a banned public name', () {
      final result = validator.validate(
        food: _food('fuck rice'),
        ownerUserId: 'user-a',
      );
      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains(PublicFoodNameModeration.rejectionMessage),
      );
    });
  });

  group('banned name errors', () {
    test('maps the database exception to the Japanese message', () {
      final mapped = SupabaseErrorMapper.mapPublishFailure(
        const PostgrestException(message: 'public food name is not allowed'),
      );
      expect(mapped.kind, PublishFailureKind.bannedName);
      expect(
        PublishErrorMessages.messageFor(mapped),
        PublicFoodNameModeration.rejectionMessage,
      );
      expect(
        PublishErrorMessages.messageFor(
          const PublicFoodNameRejectedException(),
        ),
        PublicFoodNameModeration.rejectionMessage,
      );
    });
  });

  group('banned word list parity', () {
    late String migration;

    setUpAll(() {
      migration = File(
        'supabase/migrations/20260927120000_reject_banned_public_food_names.sql',
      ).readAsStringSync();
    });

    test('SQL list matches the Dart list', () {
      final start = migration.indexOf('-- PUBLIC_FOOD_BANNED_WORDS');
      final end = migration.indexOf('-- /PUBLIC_FOOD_BANNED_WORDS');
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final block = migration.substring(start, end);
      final sqlWords = RegExp(
        "'([^']*)'",
      ).allMatches(block).map((match) => match.group(1)!).toList();
      expect(sqlWords, publicFoodBannedWords);
    });

    test('SQL uses the same halfwidth katakana map', () {
      expect(migration, contains(publicFoodHalfwidthKatakanaFrom));
      expect(migration, contains(publicFoodHalfwidthKatakanaTo));
    });

    test('publish and public-name updates call the check', () {
      expect(
        migration,
        contains('public.public_food_name_is_banned(v_row.name)'),
      );
      expect(migration, contains('new.name is distinct from old.name'));
      expect(migration, contains('public food name is not allowed'));
      expect('update public.saved_foods'.allMatches(migration).length, 1);
      expect(migration, contains("set visibility = 'public'"));
    });
  });
}

SavedFood _food(String name) {
  return SavedFood(
    foodId: 'food-1',
    ownerUserId: 'user-a',
    name: name,
    normalizedName: name.toLowerCase(),
    baseAmount: 100,
    unitType: FoodUnitType.g,
    servingUnitLabel: 'g',
    visibility: FoodVisibility.private,
    status: FoodStatus.active,
    kcalPerBase: 165,
    proteinPerBase: 10,
    fatPerBase: 5,
    carbPerBase: 20,
    sourceType: FoodSourceType.manual,
    createdAt: DateTime(2026, 7, 20),
    updatedAt: DateTime(2026, 7, 20),
  );
}
