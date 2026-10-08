import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// 同意ダイアログの文面の版。変えたら、もう一度同意を取る。
const aiDataConsentVersion = '2026-10-08';

const aiDataConsentVersionKey = 'ai_data_consent_version';
const aiDataConsentAtKey = 'ai_data_consent_at';

const aiDataConsentTitle = 'AI機能を使う前に';

const aiDataConsentBody =
    '写真で登録、外食・コンビニ、AIで探す、自炊コーチは、入力した内容を Anthropic, PBC（米国）へ送り、カロリーとPFCの推定に使います。';

const aiDataConsentSendsTitle = '送るもの';

const aiDataConsentSends = [
  '食事の写真、料理名、量、補足',
  '店名や食品名',
  '手元の食材と、この食事の条件のメモ',
];

const aiDataConsentStorage = '写真はカロナビに保存しません。';

const aiDataConsentAcceptLabel = '同意して使う';
const aiDataConsentDeclineLabel = 'やめる';
const aiDataConsentPrivacyLabel = 'プライバシーポリシー';

const aiDataConsentRequiredMessage = 'AI機能を使うには、同意が必要です。';
const aiDataConsentSaveFailedMessage = '同意を保存できませんでした。もう一度試してください。';
const aiDataConsentDeclinedMessage = '同意しないと、推定はしません。';

/// 端末とサーバに残す、AI機能の同意。
abstract class AiDataConsent {
  bool get isGranted;

  /// サーバに書いてから、端末に残す。失敗したら false。
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
  MemoryAiDataConsent({this.granted = false, this.failGrant = false});

  bool granted;
  bool failGrant;
  int grantCalls = 0;

  @override
  bool get isGranted => granted;

  @override
  Future<bool> grant() async {
    grantCalls += 1;
    if (failGrant) {
      return false;
    }
    granted = true;
    return true;
  }
}

class PrefsAiDataConsent extends AiDataConsent {
  PrefsAiDataConsent(this._preferences);

  final SharedPreferences _preferences;

  @override
  bool get isGranted =>
      _preferences.getString(aiDataConsentVersionKey) == aiDataConsentVersion;

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
