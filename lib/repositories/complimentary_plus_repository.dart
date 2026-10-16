import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/complimentary_plus.dart';

/// 今のログインに、課金ではないカロナビ+があるか。
abstract class ComplimentaryPlusRepository {
  /// true / false はサーバの答え。null は通信失敗で、直前の答えを残す。
  Future<bool?> current();
}

class NoOpComplimentaryPlusRepository implements ComplimentaryPlusRepository {
  const NoOpComplimentaryPlusRepository();

  @override
  Future<bool?> current() async => false;
}

class SupabaseComplimentaryPlusRepository
    implements ComplimentaryPlusRepository {
  SupabaseComplimentaryPlusRepository({SupabaseClient? client})
    : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<bool?> current() async {
    try {
      final data = await _supabase.rpc('current_complimentary_plus');
      return complimentaryPlusFromRpc(data);
    } catch (_) {
      return null;
    }
  }
}
