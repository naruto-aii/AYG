import 'package:supabase_flutter/supabase_flutter.dart';

/// localStorage 失敗時にインメモリへフォールバックする Auth 永続化。
class ResilientAuthLocalStorage extends LocalStorage {
  ResilientAuthLocalStorage(this._delegate);

  final LocalStorage _delegate;
  final Map<String, String> _memory = {};
  bool _delegateAvailable = true;

  bool get isPersistent => _delegateAvailable;

  @override
  Future<void> initialize() async {
    try {
      await _delegate.initialize();
    } catch (_) {
      _delegateAvailable = false;
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    if (_delegateAvailable) {
      try {
        return await _delegate.hasAccessToken();
      } catch (_) {
        _delegateAvailable = false;
      }
    }
    return _memory.containsKey(_sessionKey);
  }

  @override
  Future<String?> accessToken() async {
    if (_delegateAvailable) {
      try {
        return await _delegate.accessToken();
      } catch (_) {
        _delegateAvailable = false;
      }
    }
    return _memory[_sessionKey];
  }

  @override
  Future<void> removePersistedSession() async {
    _memory.remove(_sessionKey);
    if (_delegateAvailable) {
      try {
        await _delegate.removePersistedSession();
      } catch (_) {
        _delegateAvailable = false;
      }
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    _memory[_sessionKey] = persistSessionString;
    if (_delegateAvailable) {
      try {
        await _delegate.persistSession(persistSessionString);
      } catch (_) {
        _delegateAvailable = false;
      }
    }
  }

  static const _sessionKey = '__memory_session__';
}
