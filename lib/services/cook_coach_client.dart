import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/meal_slot.dart';
import 'ai_data_consent.dart';
import 'cook_coach.dart';
import 'cook_coach_target.dart';

class CookCoachFailure implements Exception {
  const CookCoachFailure(this.message, {this.code});

  final String message;
  final String? code;
}

const cookCoachFallbackMessage = '献立を作れませんでした。しばらくしてからもう一度試してください。';

String cookCoachMessageFromBody(Object? body) {
  if (body is Map && body['message'] is String) {
    final message = (body['message'] as String).trim();
    if (message.isNotEmpty) {
      return message;
    }
  }
  if (body is String && body.trim().isNotEmpty) {
    try {
      return cookCoachMessageFromBody(jsonDecode(body));
    } catch (_) {
      return cookCoachFallbackMessage;
    }
  }
  return cookCoachFallbackMessage;
}

String? cookCoachCodeFromBody(Object? body) {
  if (body is Map && body['code'] is String) {
    return body['code'] as String;
  }
  if (body is String && body.trim().isNotEmpty) {
    try {
      return cookCoachCodeFromBody(jsonDecode(body));
    } catch (_) {
      return null;
    }
  }
  return null;
}

typedef CookCoachInvoke = Future<Object?> Function(Map<String, Object?> body);

/// Edge Function `cook-coach`。API キーはアプリに置かない。
class CookCoachClient {
  const CookCoachClient({required this.invoke});

  final CookCoachInvoke invoke;

  factory CookCoachClient.supabase({SupabaseClient? client}) {
    return CookCoachClient(
      invoke: (body) async {
        if (!await AiDataConsent.grantedNow()) {
          throw const CookCoachFailure(aiDataConsentRequiredMessage);
        }
        final supabase = client ?? Supabase.instance.client;
        try {
          final response = await supabase.functions.invoke(
            'cook-coach',
            body: body,
          );
          return response.data;
        } on FunctionException catch (error) {
          throw CookCoachFailure(
            cookCoachMessageFromBody(error.details),
            code: cookCoachCodeFromBody(error.details),
          );
        }
      },
    );
  }

  Future<CookCoachResult> generate({
    required List<String> ingredients,
    required MealSlot slot,
    required CookCoachMealTarget target,
    String note = '',
    List<String> avoid = const [],
  }) async {
    final Object? data;
    try {
      data = await invoke({
        'ingredients': ingredients,
        'slot': cookSlotWire(slot),
        'target_kcal': target.kcal,
        'target_protein_g': target.proteinG,
        'target_fat_g': target.fatG,
        'target_carb_g': target.carbG,
        'note': note.trim(),
        'avoid': avoid,
      });
    } on CookCoachFailure {
      rethrow;
    } catch (error) {
      debugPrint('[AYG] cook coach invoke failed: $error');
      throw const CookCoachFailure(cookCoachFallbackMessage);
    }
    if (data is Map && data['ok'] == false) {
      throw CookCoachFailure(
        cookCoachMessageFromBody(data),
        code: cookCoachCodeFromBody(data),
      );
    }
    final parsed = parseCookCoachResult(data);
    if (parsed == null || parsed.patterns.isEmpty) {
      throw const CookCoachFailure(
        '献立を確認できませんでした。食材を変えて、もう一度試してください。',
      );
    }
    return parsed;
  }
}
