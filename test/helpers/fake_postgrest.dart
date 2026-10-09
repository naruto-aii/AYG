import 'dart:convert';

import 'package:http/http.dart';

/// 本番 Supabase（PostgREST + Postgres、セッションのタイムゾーンは UTC）の
/// 振る舞いを、同期テストに必要な範囲で再現する HTTP クライアント。
///
/// - `timestamptz` 列は、オフセット無しの文字列を UTC として受け取り、
///   `2026-10-08T13:21:35.338+00:00` の形（PostgREST と同じ）で返す。
/// - 本番に無い列を送ると PGRST204 で拒否する（本番の列一覧は 2026-10-09 に確認）。
/// - `upsert(onConflict:)` は既存行に送られた列だけを上書きする。
/// - `eq` / `in` の絞り込み、`order`、`offset` / `limit` を扱う。
class FakePostgrest extends BaseClient {
  FakePostgrest();

  /// 表名 → 行。
  final Map<String, List<Map<String, dynamic>>> tables = {};

  /// 受けたリクエスト（`METHOD /table?query`）。
  final List<String> requests = [];

  /// 書き込みを失敗させる表（ネット断の代わり）。
  final Set<String> failWritesTo = {};

  /// この表への POST（upsert）を、[holdUntil] が終わるまでサーバに届けない
  /// （遅い回線で送信が長引く代わり）。届いた時点で [heldPosts] が増える。
  String? holdPostsTo;
  Future<void>? holdUntil;
  int heldPosts = 0;

  static const Map<String, Set<String>> timestampColumns = {
    'food_entries': {'logged_at', 'updated_at'},
    'exercise_entries': {'logged_at', 'updated_at'},
    'alcohol_entries': {'consumed_at', 'updated_at'},
    'weight_entries': {'recorded_at', 'updated_at'},
  };

  /// 本番 vdzzusqisymtejcjnikb の列（information_schema.columns, 2026-10-09）。
  static const Map<String, Set<String>> productionColumns = {
    'food_entries': {
      'user_id', 'entry_id', 'name', 'kcal_per_unit', 'protein_per_unit',
      'fat_per_unit', 'carb_per_unit', 'quantity', 'logged_at', 'updated_at',
      'base_amount', 'unit_type', 'consumed_amount', 'source_type',
      'saved_food_id', 'source_food_owner_user_id', 'meal_group_id',
      'meal_group_name', 'sort_order', 'official_food_code',
      'official_food_name', 'source_saved_food_version', 'memo',
      'record_origin',
    },
    'exercise_entries': {
      'user_id', 'entry_id', 'name', 'duration_min', 'burned_kcal',
      'logged_at', 'updated_at', 'category_key', 'activity_id', 'intensity',
      'sets', 'reps', 'lift_weight_kg', 'met_value', 'gross_kcal', 'net_kcal',
      'weight_kg_snapshot', 'calculation_source', 'calculation_version',
      'source_key', 'notes', 'distance_km', 'record_origin',
    },
    'alcohol_entries': {
      'user_id', 'entry_id', 'beverage_name', 'amount', 'unit',
      'alcohol_percentage', 'total_calories', 'pure_alcohol_grams',
      'alcohol_calories', 'consumed_at', 'updated_at',
    },
    'weight_entries': {
      'user_id', 'entry_id', 'weight_kg', 'recorded_at', 'source',
      'updated_at',
    },
  };

  List<Map<String, dynamic>> rows(String table) =>
      tables.putIfAbsent(table, () => []);

  /// Postgres の timestamptz 入力 → PostgREST の出力文字列。
  static String timestamptz(String sent) {
    final hasOffset = RegExp(r'(Z|[+-]\d\d(:?\d\d)?)$').hasMatch(sent);
    final utc = DateTime.parse(hasOffset ? sent : '${sent}Z').toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final base =
        '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)}'
        'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
    final micros = utc.millisecond * 1000 + utc.microsecond;
    var frac = '';
    if (micros != 0) {
      frac = '.${micros.toString().padLeft(6, '0')}'.replaceFirst(
        RegExp(r'0+$'),
        '',
      );
    }
    return '$base$frac+00:00';
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final url = request.url;
    final segments = url.pathSegments;
    final restIndex = segments.indexOf('v1');
    final table = segments.sublist(restIndex + 1).join('/');
    requests.add('${request.method} /$table?${url.query}');
    final body = request is Request ? request.body : '';
    final accept = request.headers['Accept'] ?? request.headers['accept'] ?? '';
    final wantsObject = accept.contains('vnd.pgrst.object');

    if (table.startsWith('rpc/')) {
      return _json(request, 200, null);
    }

    switch (request.method) {
      case 'GET':
      case 'HEAD':
        final found = _select(table, url.queryParametersAll);
        if (wantsObject) {
          if (found.length != 1) {
            return _json(request, 406, {
              'code': 'PGRST116',
              'message': 'JSON object requested, multiple (or no) rows returned',
              'details': 'The result contains ${found.length} rows',
            });
          }
          return _json(request, 200, found.single);
        }
        return _json(request, 200, found);
      case 'POST':
        final hold = holdUntil;
        if (hold != null && holdPostsTo == table) {
          heldPosts++;
          await hold;
        }
        if (failWritesTo.contains(table)) {
          return _json(request, 503, {'message': 'offline', 'code': '503'});
        }
        final decoded = jsonDecode(body);
        final incoming = <Map<String, dynamic>>[
          if (decoded is List)
            for (final row in decoded) Map<String, dynamic>.from(row as Map)
          else
            Map<String, dynamic>.from(decoded as Map),
        ];
        final allowed = productionColumns[table];
        if (allowed != null) {
          for (final row in incoming) {
            for (final column in row.keys) {
              if (!allowed.contains(column)) {
                return _json(request, 400, {
                  'code': 'PGRST204',
                  'message':
                      "Could not find the '$column' column of '$table' in the schema cache",
                });
              }
            }
          }
        }
        final onConflict = url.queryParameters['on_conflict']
            ?.split(',')
            .map((c) => c.trim())
            .toList();
        final written = <Map<String, dynamic>>[];
        for (final raw in incoming) {
          final row = _normalize(table, raw);
          final target = rows(table);
          final keys = onConflict ?? const <String>[];
          final index = keys.isEmpty
              ? -1
              : target.indexWhere(
                  (existing) => keys.every((k) => '${existing[k]}' == '${row[k]}'),
                );
          if (index >= 0) {
            target[index] = {...target[index], ...row};
            written.add(target[index]);
          } else {
            target.add(row);
            written.add(row);
          }
        }
        if (wantsObject) {
          return _json(request, 201, written.first);
        }
        return _json(request, 201, written);
      case 'PATCH':
        final patch = _normalize(
          table,
          Map<String, dynamic>.from(jsonDecode(body) as Map),
        );
        final matched = _select(table, url.queryParametersAll, raw: true);
        for (final row in matched) {
          row.addAll(patch);
        }
        return _json(request, 200, matched);
      case 'DELETE':
        if (failWritesTo.contains(table)) {
          return _json(request, 503, {'message': 'offline', 'code': '503'});
        }
        final matched = _select(table, url.queryParametersAll, raw: true);
        rows(table).removeWhere(matched.contains);
        return _json(request, 200, matched);
    }
    return _json(request, 405, {'message': 'unsupported'});
  }

  Map<String, dynamic> _normalize(String table, Map<String, dynamic> row) {
    final columns = timestampColumns[table] ?? const <String>{};
    return {
      for (final entry in row.entries)
        entry.key: columns.contains(entry.key) && entry.value is String
            ? timestamptz(entry.value as String)
            : entry.value,
    };
  }

  List<Map<String, dynamic>> _select(
    String table,
    Map<String, List<String>> query, {
    bool raw = false,
  }) {
    var result = rows(table).where((row) {
      for (final entry in query.entries) {
        final key = entry.key;
        if (const {'select', 'order', 'limit', 'offset', 'on_conflict', 'columns'}
            .contains(key)) {
          continue;
        }
        for (final condition in entry.value) {
          if (condition.startsWith('eq.')) {
            if ('${row[key]}' != condition.substring(3)) {
              return false;
            }
          } else if (condition.startsWith('in.(')) {
            final values = condition
                .substring(4, condition.length - 1)
                .split(',')
                .map((v) => v.replaceAll('"', ''))
                .toSet();
            if (!values.contains('${row[key]}')) {
              return false;
            }
          } else if (condition.startsWith('is.null')) {
            if (row[key] != null) {
              return false;
            }
          } else {
            throw UnsupportedError('filter $key=$condition');
          }
        }
      }
      return true;
    }).toList();
    final order = query['order']?.join(',');
    if (order != null && order.isNotEmpty) {
      final keys = order.split(',').map((part) => part.split('.')).toList();
      result.sort((a, b) {
        for (final key in keys) {
          final column = key.first;
          final desc = key.contains('desc');
          final av = a[column];
          final bv = b[column];
          final compared = av is DateTime || bv is DateTime
              ? 0
              : (av is String && timestampColumns[table]?.contains(column) == true)
              ? DateTime.parse(av).compareTo(DateTime.parse(bv as String))
              : '${av ?? ''}'.compareTo('${bv ?? ''}');
          if (compared != 0) {
            return desc ? -compared : compared;
          }
        }
        return 0;
      });
    }
    final offset = int.tryParse(query['offset']?.first ?? '') ?? 0;
    final limit = int.tryParse(query['limit']?.first ?? '');
    if (offset > 0) {
      result = result.skip(offset).toList();
    }
    if (limit != null) {
      result = result.take(limit).toList();
    }
    if (raw) {
      return result;
    }
    return [for (final row in result) Map<String, dynamic>.from(row)];
  }

  StreamedResponse _json(BaseRequest request, int status, Object? body) {
    final bytes = utf8.encode(jsonEncode(body));
    return StreamedResponse(
      Stream<List<int>>.value(bytes),
      status,
      request: request,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'content-range': '0-0/*',
      },
    );
  }

  @override
  void close() {}
}
