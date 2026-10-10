import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// 同意画面の文面の版。変えたら、もう一度同意を取る。
///
/// `2026-10-08` はログインボタンを同意とみなしていた版。
/// 不適切な内容を認めない一文を足したので、その版では通さない。
const aiDataConsentVersion = '2026-10-10';

/// 端末に残す、このアカウントが同意した版。ユーザーIDと組でだけ有効。
///
/// 以前の `ai_data_consent_version` は、画面を出さずに保存済みのログイン状態が
/// 戻っただけでも書いていた。その値は同意の証拠にならないので読まない。
/// `terms_agreement_version` も、ユーザーIDが無い端末全体の値は証拠にしない。
const aiDataConsentVersionKey = 'terms_agreement_version';
const termsAgreementUserKey = 'terms_agreement_user_id';
const aiDataConsentAtKey = 'terms_agreement_server_at';

const aiDataConsentRequiredMessage = 'AI機能を使うには、同意が必要です。';

/// 今の版に同意済みか。
///
/// サーバを読めたときは、そのアカウントの `ai_data_consents.policy_version`
/// だけを見る。端末に残った別アカウントの値では通さない。
/// サーバを読めないときだけ、同じユーザーIDの手元の控えで通す。
bool hasCurrentTermsAgreement({
  required String userId,
  required String? cachedUserId,
  required String? cachedVersion,
  required String? serverVersion,
  required bool serverReadFailed,
}) {
  if (userId.isEmpty) {
    return false;
  }
  if (!serverReadFailed) {
    return serverVersion == aiDataConsentVersion;
  }
  return cachedUserId != null &&
      cachedUserId.toLowerCase() == userId.toLowerCase() &&
      cachedVersion == aiDataConsentVersion;
}

/// アカウントごとの利用規約・プライバシー（AI送信の一文を含む）の同意。
///
/// 同意はサインインのあと、同意画面のボタンで取る。ログインボタンでは取らない。
/// 正本は `ai_data_consents`（ユーザーID、版、サーバが付けた時刻）。
/// 手元の控えは、同じアカウントがオフラインで開き直したときに画面を繰り返さないためだけ。
abstract class AiDataConsent {
  bool get isGranted;

  /// ログイン画面で同意した事実を端末に残す。サーバにはまだ書かない。
  Future<void> rememberAgreed();

  /// このアカウントが、今の版に同意済みか。
  Future<bool> currentAgreementFor(String userId);

  /// 同意画面で同意したことを、このアカウントの行として残す。
  Future<bool> agree(String userId);

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

  /// このアカウントが今の版に同意済みか。同意画面を出すかの判定。
  static Future<bool> currentAgreementForUser(String userId) async {
    final current = override;
    if (current != null) {
      return current.currentAgreementFor(userId);
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      return PrefsAiDataConsent(preferences).currentAgreementFor(userId);
    } catch (error) {
      debugPrint('[AYG] terms agreement read failed: $error');
      return false;
    }
  }

  /// 同意画面のボタン。失敗したら false。画面は閉じない。
  static Future<bool> agreeForUser(String userId) async {
    final current = override;
    if (current != null) {
      return current.agree(userId);
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      return PrefsAiDataConsent(preferences).agree(userId);
    } catch (error) {
      debugPrint('[AYG] terms agreement save failed: $error');
      return false;
    }
  }

  /// 以前のログインボタン用。同意画面は [agreeForUser] を使う。
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
}

/// テスト用。サーバには繋がない。
class MemoryAiDataConsent extends AiDataConsent {
  MemoryAiDataConsent({
    this.granted = false,
    this.synced = false,
    this.failGrant = false,
    this.serverByUser,
  });

  bool granted;
  bool synced;
  bool failGrant;

  /// null のときは [granted] を全アカウントの同意として扱う（既存テスト）。
  /// 空でもマップがあるときは、そのアカウントの版だけを見る。
  Map<String, String>? serverByUser;
  int grantCalls = 0;

  @override
  bool get isGranted => granted;

  @override
  Future<void> rememberAgreed() async {
    granted = true;
  }

  @override
  Future<bool> currentAgreementFor(String userId) async {
    final server = serverByUser;
    if (server == null) {
      return granted;
    }
    return server[userId] == aiDataConsentVersion;
  }

  @override
  Future<bool> agree(String userId) async {
    grantCalls += 1;
    if (failGrant) {
      return false;
    }
    final server = serverByUser ?? <String, String>{};
    server[userId] = aiDataConsentVersion;
    serverByUser = server;
    granted = true;
    synced = true;
    return true;
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
    final userId = _preferences.getString(termsAgreementUserKey);
    return isGranted &&
        userId != null &&
        userId.isNotEmpty &&
        at != null &&
        at.isNotEmpty;
  }

  bool _cachedFor(String userId) {
    return hasCurrentTermsAgreement(
      userId: userId,
      cachedUserId: _preferences.getString(termsAgreementUserKey),
      cachedVersion: _preferences.getString(aiDataConsentVersionKey),
      serverVersion: null,
      serverReadFailed: true,
    );
  }

  @override
  Future<void> rememberAgreed() async {
    if (_preferences.getString(aiDataConsentVersionKey) != aiDataConsentVersion) {
      await _preferences.remove(aiDataConsentAtKey);
    }
    await _preferences.setString(aiDataConsentVersionKey, aiDataConsentVersion);
  }

  @override
  Future<bool> currentAgreementFor(String userId) async {
    if (!SupabaseConfig.isConfigured) {
      return _cachedFor(userId);
    }
    try {
      final supabase = Supabase.instance.client;
      final sessionUser = supabase.auth.currentUser?.id;
      if (sessionUser == null ||
          sessionUser.isEmpty ||
          sessionUser.toLowerCase() != userId.toLowerCase()) {
        return _cachedFor(userId);
      }
      final row = await supabase
          .from('ai_data_consents')
          .select('policy_version')
          .eq('user_id', userId)
          .maybeSingle();
      final version = row?['policy_version'];
      final serverVersion = version is String ? version : null;
      final agreed = hasCurrentTermsAgreement(
        userId: userId,
        cachedUserId: _preferences.getString(termsAgreementUserKey),
        cachedVersion: _preferences.getString(aiDataConsentVersionKey),
        serverVersion: serverVersion,
        serverReadFailed: false,
      );
      if (agreed) {
        await _preferences.setString(termsAgreementUserKey, userId);
        await _preferences.setString(
          aiDataConsentVersionKey,
          aiDataConsentVersion,
        );
      } else if (_preferences.getString(termsAgreementUserKey)?.toLowerCase() ==
          userId.toLowerCase()) {
        await _preferences.remove(termsAgreementUserKey);
        await _preferences.remove(aiDataConsentVersionKey);
        await _preferences.remove(aiDataConsentAtKey);
      }
      return agreed;
    } catch (error) {
      debugPrint('[AYG] terms agreement read failed: $error');
      return _cachedFor(userId);
    }
  }

  @override
  Future<bool> agree(String userId) async {
    return _writeServer(userId);
  }

  @override
  Future<bool> sync() async {
    if (!isGranted) {
      return false;
    }
    if (!SupabaseConfig.isConfigured) {
      return false;
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || !_cachedFor(userId)) {
      return false;
    }
    if (hasServerCopy) {
      return true;
    }
    return _writeServer(userId);
  }

  @override
  Future<bool> grant() async {
    if (!SupabaseConfig.isConfigured) {
      return false;
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return false;
    }
    return _writeServer(userId);
  }

  Future<bool> _writeServer(String userId) async {
    if (!SupabaseConfig.isConfigured) {
      return false;
    }
    try {
      final supabase = Supabase.instance.client;
      final sessionUser = supabase.auth.currentUser?.id;
      if (sessionUser == null ||
          sessionUser.isEmpty ||
          sessionUser.toLowerCase() != userId.toLowerCase()) {
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
      await _preferences.setString(termsAgreementUserKey, userId);
      await _preferences.setString(aiDataConsentVersionKey, aiDataConsentVersion);
      await _preferences.setString(aiDataConsentAtKey, at);
      return true;
    } catch (error) {
      debugPrint('[AYG] ai data consent save failed: $error');
      return false;
    }
  }
}
