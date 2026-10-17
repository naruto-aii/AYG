import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_version_policy.dart';

Future<AppVersionPolicy?> readPolicy(
  Future<AppVersionPolicy?> Function() load,
) async {
  try {
    return await load();
  } catch (_) {
    return null;
  }
}

class AppVersionPolicyRepository {
  AppVersionPolicyRepository({this.client, this.load});

  final SupabaseClient? client;
  final Future<AppVersionPolicy?> Function()? load;

  Future<AppVersionPolicy?> fetch() {
    return readPolicy(() async {
      final load = this.load;
      if (load != null) {
        return load();
      }
      final client = this.client ?? _currentClient();
      if (client == null) {
        return null;
      }
      final row = await client
          .from('app_version_policy')
          .select('minimum_version, recommended_version, ios_store_url')
          .eq('id', 1)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      final minimum = row['minimum_version']?.toString().trim() ?? '';
      final recommended = row['recommended_version']?.toString().trim() ?? '';
      final storeUrl = row['ios_store_url']?.toString().trim() ?? '';
      if (minimum.isEmpty || recommended.isEmpty || storeUrl.isEmpty) {
        return null;
      }
      return AppVersionPolicy(
        minimum: minimum,
        recommended: recommended,
        storeUrl: storeUrl,
      );
    });
  }

  SupabaseClient? _currentClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
