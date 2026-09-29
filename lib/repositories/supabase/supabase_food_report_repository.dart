import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/food_report.dart';
import '../contracts/food_report_repository_base.dart';
import 'food_master_row_mapper.dart';
import 'supabase_error_mapper.dart';

class SupabaseFoodReportRepository implements FoodReportRepositoryBase {
  SupabaseFoodReportRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<FoodReport> submitReport({
    required String reportId,
    required String reporterUserId,
    required String targetFoodOwnerUserId,
    required String targetFoodId,
    required FoodReportReasonCode reasonCode,
    String? detailText,
  }) async {
    try {
      final row = await _client
          .from('food_reports')
          .insert({
            'report_id': reportId,
            'reporter_user_id': reporterUserId,
            'target_food_owner_user_id': targetFoodOwnerUserId,
            'target_food_id': targetFoodId,
            'reason_code': reasonCode.storageValue,
            'detail_text': detailText,
          })
          .select()
          .single();
      return FoodMasterRowMapper.foodReportFromRow(row);
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'food_reports insert');
    }
  }

  @override
  Future<List<FoodReport>> getMyReports(String reporterUserId) async {
    try {
      final rows = await _client
          .from('food_reports')
          .select()
          .eq('reporter_user_id', reporterUserId)
          .order('created_at', ascending: false);
      return rows.map(FoodMasterRowMapper.foodReportFromRow).toList();
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'food_reports list mine');
    }
  }
}
