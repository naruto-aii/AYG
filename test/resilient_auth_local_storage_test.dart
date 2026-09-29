import 'package:ayg/platform/web/resilient_auth_local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _ThrowingLocalStorage extends LocalStorage {
  @override
  Future<void> initialize() async {
    throw StateError('storage unavailable');
  }

  @override
  Future<bool> hasAccessToken() async => false;

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<void> removePersistedSession() async {}

  @override
  Future<void> persistSession(String persistSessionString) async {
    throw StateError('storage unavailable');
  }
}

void main() {
  test(
    'ResilientAuthLocalStorage falls back to memory when delegate fails',
    () async {
      final storage = ResilientAuthLocalStorage(_ThrowingLocalStorage());
      await storage.initialize();

      expect(storage.isPersistent, isFalse);
      expect(await storage.hasAccessToken(), isFalse);

      await storage.persistSession('{"access_token":"token"}');
      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), '{"access_token":"token"}');

      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
    },
  );
}
