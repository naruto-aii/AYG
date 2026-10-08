import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_data_consent.dart';
import 'photo_meal.dart';

class PhotoMealFailure implements Exception {
  const PhotoMealFailure(this.message);

  final String message;
}

const photoMealFallbackMessage =
    '推定できませんでした。しばらくしてからもう一度試すか、手入力で記録できます。';

String _clipNote(String note) {
  final trimmed = note.trim();
  if (trimmed.length <= photoMealNoteMaxLength) {
    return trimmed;
  }
  return trimmed.substring(0, photoMealNoteMaxLength);
}

String photoMealMessageFromBody(Object? body) {
  if (body is Map && body['message'] is String) {
    final message = (body['message'] as String).trim();
    if (message.isNotEmpty) {
      return message;
    }
  }
  if (body is String && body.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(body);
      return photoMealMessageFromBody(decoded);
    } catch (_) {
      return photoMealFallbackMessage;
    }
  }
  return photoMealFallbackMessage;
}

typedef PhotoMealInvoke =
    Future<Object?> Function(Map<String, Object?> body);

/// Edge Function `analyze-meal-photo`。API キーはアプリに置かない。
class PhotoMealClient {
  const PhotoMealClient({required this.invoke});

  final PhotoMealInvoke invoke;

  factory PhotoMealClient.supabase({SupabaseClient? client}) {
    return PhotoMealClient(
      invoke: (body) async {
        if (!await AiDataConsent.ensureServerCopy()) {
          final agreed = await AiDataConsent.grantedNow();
          throw PhotoMealFailure(
            agreed ? photoMealFallbackMessage : aiDataConsentRequiredMessage,
          );
        }
        final supabase = client ?? Supabase.instance.client;
        try {
          final response = await supabase.functions.invoke(
            'analyze-meal-photo',
            body: body,
          );
          return response.data;
        } on FunctionException catch (error) {
          throw PhotoMealFailure(photoMealMessageFromBody(error.details));
        }
      },
    );
  }

  Future<PhotoMealAnalysis> analyze({
    required Uint8List jpeg,
    required String dishName,
    required String amount,
    String note = '',
  }) async {
    final Object? data;
    try {
      data = await invoke({
        'image_base64': base64Encode(jpeg),
        'dish_name': dishName.trim(),
        'amount': amount.trim(),
        'note': _clipNote(note),
      });
    } on PhotoMealFailure {
      rethrow;
    } catch (error) {
      debugPrint('[AYG] photo meal invoke failed: $error');
      throw const PhotoMealFailure(photoMealFallbackMessage);
    }
    if (data is Map && data['ok'] == false) {
      throw PhotoMealFailure(photoMealMessageFromBody(data));
    }
    if (data is! Map || data['estimate'] is! Map) {
      throw const PhotoMealFailure(photoMealFallbackMessage);
    }
    final estimate = parsePhotoMealEstimate(data['estimate']);
    if (estimate == null) {
      throw const PhotoMealFailure(
        '推定を確認できませんでした。料理名と量を入れるか、手入力で記録できます。',
      );
    }
    final usageId = data['usage_id'];
    final collectionId = data['collection_id'];
    return PhotoMealAnalysis(
      usageId: usageId is String && usageId.isNotEmpty ? usageId : null,
      collectionId: collectionId is String && collectionId.isNotEmpty
          ? collectionId
          : null,
      estimate: estimate,
    );
  }
}

/// 保存のあと、直したかどうかを本人の行へ書く。失敗しても食事の保存は戻さない。
Future<void> recordPhotoMealEdit({
  SupabaseClient? client,
  required String usageId,
  required bool edited,
}) async {
  try {
    final supabase = client ?? Supabase.instance.client;
    await supabase
        .from('meal_photo_analyses')
        .update({'user_edited': edited})
        .eq('id', usageId);
  } catch (error) {
    debugPrint('[AYG] photo meal edit flag failed: $error');
  }
}

/// 収集表へ、そのまま保存したか直したかを書く。失敗しても食事の保存は戻さない。
/// 行は読まない。
Future<void> recordAiFoodResultOutcome({
  SupabaseClient? client,
  required String collectionId,
  required bool edited,
  required String name,
  required String amount,
  required double kcal,
  required double proteinG,
  required double fatG,
  required double carbG,
}) async {
  try {
    final supabase = client ?? Supabase.instance.client;
    await supabase.rpc(
      'record_ai_food_result_outcome',
      params: {
        'p_id': collectionId,
        'p_registered_as_is': !edited,
        'p_edited_name': edited ? name : null,
        'p_edited_amount': edited ? amount : null,
        'p_edited_kcal': edited ? kcal : null,
        'p_edited_protein_g': edited ? proteinG : null,
        'p_edited_fat_g': edited ? fatG : null,
        'p_edited_carb_g': edited ? carbG : null,
      },
    );
  } catch (error) {
    debugPrint('[AYG] ai food result outcome failed: $error');
  }
}
