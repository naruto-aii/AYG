import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// ログイン画面の同意文面の版。変えたら、もう一度同意を取る。
const aiDataConsentVersion = '2026-10-08';

const aiDataConsentVersionKey = 'ai_data_consent_version';
const aiDataConsentAtKey = 'ai_data_consent_at';

const aiDataConsentRequiredMessage = 'AI機能を使うには、同意が必要です。';

/// 端末とサーバに残す、AI機能の同意。
///
/// 同意そのものはログイン画面で取る。ここは、その事実を端末に残し、
/// ログイン後に `ai_data_consents` へ書く。
abstract class AiDataConsent {
  bool get isGranted;

  /// ログイン画面で同意した事実を端末に残す。サーバにはまだ書かない。
  Future<void> rememberAgreed();

  /// 端末の同意がサーバに無ければ書く。書けていれば true。
  Future<bool> sync();

  /// サーバに書いてから、時刻を端末に残す。失敗したら false。
  Future<bool> grant();

  /// テストが差し替える。本番は null。
  static AiDataConsent? override;

  static Future<bool> grantedNow() async {
    final current = override;
    if (current != null) {
      return current.isGranted;
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(aiDataConsentVersionKey) ==
          aiDataConsentVersion;
    } catch (error) {
      debugPrint('[AYG] ai data consent read failed: $error');
      return false;
    }
  }

  /// ログインできた時点で呼ぶ。失敗してもログインは止めない。
  static Future<void> recordLoginAgreement() async {
    try {
      final current = override;
      if (current != null) {
        await current.rememberAgreed();
        await current.sync();
        return;
      }
      final preferences = await SharedPreferences.getInstance();
      final store = PrefsAiDataConsent(preferences);
      await store.rememberAgreed();
      await store.sync();
    } catch (error) {
      debugPrint('[AYG] ai data consent record failed: $error');
    }
  }

  /// AI機能を呼ぶ直前。同意がサーバに無ければ静かに再送する。画面は出さない。
  static Future<bool> ensureServerCopy() async {
    try {
      final current = override;
      if (current != null) {
        return current.sync();
      }
      final preferences = await SharedPreferences.getInstance();
      return PrefsAiDataConsent(preferences).sync();
    } catch (error) {
      debugPrint('[AYG] ai data consent sync failed: $error');
      return false;
    }
  }

  static Future<AiDataConsent> load() async {
    final current = override;
    if (current != null) {
      return current;
    }
    final preferences = await SharedPreferences.getInstance();
    final store = PrefsAiDataConsent(preferences);
    await store.restore();
    return store;
  }
}

/// テスト用。サーバには繋がない。
class MemoryAiDataConsent extends AiDataConsent {
  MemoryAiDataConsent({
    this.granted = false,
    this.synced = false,
    this.failGrant = false,
  });

  bool granted;
  bool synced;
  bool failGrant;
  int grantCalls = 0;

  @override
  bool get isGranted => granted;

  @override
  Future<void> rememberAgreed() async {
    granted = true;
  }

  @override
  Future<bool> sync() async {
    if (!granted) {
      return false;
    }
    if (synced) {
      return true;
    }
    return grant();
  }

  @override
  Future<bool> grant() async {
    grantCalls += 1;
    if (failGrant) {
      return false;
    }
    granted = true;
    synced = true;
    return true;
  }
}

class PrefsAiDataConsent extends AiDataConsent {
  PrefsAiDataConsent(this._preferences);

  final SharedPreferences _preferences;

  @override
  bool get isGranted =>
      _preferences.getString(aiDataConsentVersionKey) == aiDataConsentVersion;

  bool get hasServerCopy {
    final at = _preferences.getString(aiDataConsentAtKey);
    return isGranted && at != null && at.isNotEmpty;
  }

  @override
  Future<void> rememberAgreed() async {
    if (_preferences.getString(aiDataConsentVersionKey) != aiDataConsentVersion) {
      await _preferences.remove(aiDataConsentAtKey);
    }
    await _preferences.setString(aiDataConsentVersionKey, aiDataConsentVersion);
  }

  @override
  Future<bool> sync() async {
    if (!isGranted) {
      return false;
    }
    if (hasServerCopy) {
      return true;
    }
    return grant();
  }

  @override
  Future<bool> grant() async {
    if (!SupabaseConfig.isConfigured) {
      return false;
    }
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return false;
      }
      final row = await supabase
          .from('ai_data_consents')
          .upsert({
            'user_id': userId,
            'policy_version': aiDataConsentVersion,
          }, onConflict: 'user_id')
          .select('consented_at')
          .maybeSingle();
      final at = row?['consented_at'];
      if (at is! String || at.isEmpty) {
        return false;
      }
      await _preferences.setString(aiDataConsentVersionKey, aiDataConsentVersion);
      await _preferences.setString(aiDataConsentAtKey, at);
      return true;
    } catch (error) {
      debugPrint('[AYG] ai data consent save failed: $error');
      return false;
    }
  }

  /// 端末に無いときだけ、同じ版の同意をサーバから戻す。
  Future<void> restore() async {
    if (isGranted || !SupabaseConfig.isConfigured) {
      return;
    }
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return;
      }
      final row = await supabase
          .from('ai_data_consents')
          .select('policy_version, consented_at')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) {
        return;
      }
      final version = row['policy_version'];
      final at = row['consented_at'];
      if (version == aiDataConsentVersion && at is String && at.isNotEmpty) {
        await _preferences.setString(aiDataConsentVersionKey, version as String);
        await _preferences.setString(aiDataConsentAtKey, at);
      }
    } catch (error) {
      debugPrint('[AYG] ai data consent restore failed: $error');
    }
  }
}
