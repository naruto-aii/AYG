import 'package:supabase_flutter/supabase_flutter.dart';

/// PostgREST は範囲を指定しない select を 1000 件で切る。
const postgrestPageSize = 1000;

/// 最後のページが [postgrestPageSize] 未満になるまで読む。
Future<List<Map<String, dynamic>>> fetchAllUserRows(
  SupabaseClient client, {
  required String table,
  required String userId,
  required List<String> orderBy,
  String userColumn = 'user_id',
}) async {
  final collected = <Map<String, dynamic>>[];
  var offset = 0;
  while (true) {
    var query = client
        .from(table)
        .select()
        .eq(userColumn, userId)
        .order(orderBy.first);
    for (final column in orderBy.skip(1)) {
      query = query.order(column);
    }
    final page = await query.range(offset, offset + postgrestPageSize - 1);
    final rows = <Map<String, dynamic>>[
      for (final row in page) Map<String, dynamic>.from(row),
    ];
    collected.addAll(rows);
    if (rows.length < postgrestPageSize) {
      return collected;
    }
    offset += postgrestPageSize;
  }
}
