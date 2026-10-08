import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/meal_slot.dart';

/// パーソナルコーチの1日の案で、その日に登録した枠（朝食・昼食・間食・夕食）。
///
/// 登録したあとに開き直したとき、登録済みの枠は案から外し、
/// 新しい残りカロリーで、まだの枠だけを組み直すために使う。
class CoachRegisteredSlot {
  const CoachRegisteredSlot({
    required this.slot,
    required this.kcal,
    required this.entryIds,
  });

  final MealSlot slot;
  final int kcal;

  /// 登録した食事記録の id。記録を消したら、登録済みとして扱わない。
  final List<String> entryIds;
}

abstract class CoachSlotStore {
  /// [day] のカレンダー日に登録した枠。
  Future<List<CoachRegisteredSlot>> registeredOn(DateTime day);

  Future<void> markRegistered({
    required DateTime day,
    required MealSlot slot,
    required int kcal,
    required List<String> entryIds,
  });
}

/// 端末に、その日の分だけを残す。日付が変わると前の日の分は読まない。
class PreferencesCoachSlotStore implements CoachSlotStore {
  PreferencesCoachSlotStore({this.preferences});

  static const storageKey = 'coach_registered_slots_v1';

  final SharedPreferences? preferences;

  static String dayKey(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }

  @override
  Future<List<CoachRegisteredSlot>> registeredOn(DateTime day) async {
    try {
      final raw = (await _prefs()).getString(storageKey);
      if (raw == null) {
        return const [];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['date'] != dayKey(day)) {
        return const [];
      }
      final slots = decoded['slots'];
      if (slots is! Map) {
        return const [];
      }
      final found = <CoachRegisteredSlot>[];
      for (final slot in MealSlot.values) {
        final item = slots[slot.name];
        if (item is! Map) {
          continue;
        }
        final kcal = item['kcal'];
        final ids = item['ids'];
        found.add(
          CoachRegisteredSlot(
            slot: slot,
            kcal: kcal is num ? kcal.round() : 0,
            entryIds: ids is List
                ? [for (final id in ids) id.toString()]
                : const [],
          ),
        );
      }
      return found;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> markRegistered({
    required DateTime day,
    required MealSlot slot,
    required int kcal,
    required List<String> entryIds,
  }) async {
    try {
      final prefs = await _prefs();
      final key = dayKey(day);
      var slots = <String, dynamic>{};
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map &&
            decoded['date'] == key &&
            decoded['slots'] is Map) {
          slots = Map<String, dynamic>.from(decoded['slots'] as Map);
        }
      }
      final previous = slots[slot.name];
      final previousIds = previous is Map && previous['ids'] is List
          ? [for (final id in previous['ids'] as List) id.toString()]
          : const <String>[];
      final previousKcal = previous is Map && previous['kcal'] is num
          ? (previous['kcal'] as num).round()
          : 0;
      slots[slot.name] = {
        'kcal': previousKcal + kcal,
        'ids': [...previousIds, ...entryIds],
      };
      await prefs.setString(
        storageKey,
        jsonEncode({'date': key, 'slots': slots}),
      );
    } catch (_) {
      return;
    }
  }

  Future<SharedPreferences> _prefs() async {
    return preferences ?? await SharedPreferences.getInstance();
  }
}

/// テストや、保存先が無いとき。
class MemoryCoachSlotStore implements CoachSlotStore {
  final Map<String, List<CoachRegisteredSlot>> _days = {};

  @override
  Future<List<CoachRegisteredSlot>> registeredOn(DateTime day) async {
    return List.unmodifiable(
      _days[PreferencesCoachSlotStore.dayKey(day)] ?? const [],
    );
  }

  @override
  Future<void> markRegistered({
    required DateTime day,
    required MealSlot slot,
    required int kcal,
    required List<String> entryIds,
  }) async {
    final key = PreferencesCoachSlotStore.dayKey(day);
    final list = [...?_days[key]];
    final index = list.indexWhere((item) => item.slot == slot);
    if (index >= 0) {
      final old = list[index];
      list[index] = CoachRegisteredSlot(
        slot: slot,
        kcal: old.kcal + kcal,
        entryIds: [...old.entryIds, ...entryIds],
      );
    } else {
      list.add(CoachRegisteredSlot(slot: slot, kcal: kcal, entryIds: entryIds));
    }
    _days[key] = list;
  }
}
