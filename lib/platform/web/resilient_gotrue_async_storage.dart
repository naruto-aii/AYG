import 'package:supabase_flutter/supabase_flutter.dart';

/// PKCE code verifier 用の resilient storage。
class ResilientGotrueAsyncStorage extends GotrueAsyncStorage {
  ResilientGotrueAsyncStorage(this._delegate);

  final GotrueAsyncStorage _delegate;
  final Map<String, String> _memory = {};
  bool _delegateAvailable = true;

  Future<void> _run(Future<void> Function() action) async {
    if (!_delegateAvailable) {
      return;
    }
    try {
      await action();
    } catch (_) {
      _delegateAvailable = false;
    }
  }

  @override
  Future<String?> getItem({required String key}) async {
    if (_delegateAvailable) {
      try {
        return await _delegate.getItem(key: key);
      } catch (_) {
        _delegateAvailable = false;
      }
    }
    return _memory[key];
  }

  @override
  Future<void> removeItem({required String key}) async {
    _memory.remove(key);
    await _run(() => _delegate.removeItem(key: key));
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _memory[key] = value;
    await _run(() => _delegate.setItem(key: key, value: value));
  }
}
