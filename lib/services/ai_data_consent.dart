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

/// 設定の「AIへの送信」がオフのとき。写真で登録、外食・コンビニ、AIで探すは、この文を出して送らない。
const aiSendingOffMessage = 'AIへの送信はオフです。設定の「AIへの送信」をオンにすると使えます。';

/// そのアカウントのオンオフをサーバから読めなかったとき。オンにはしない。
const aiSendingUnreadableMessage = 'AIへは送れません。通信を確認して、もう一度お試しください。';

/// 端末の「AIへの送信」。[aiSendingEnabledUserKey] と同じアカウントのときだけ使う。
const aiSendingEnabledKey = 'ai_sending_enabled';

/// この控えの持ち主。未ログインや別アカウントでは、値を表示にも判定にも使わない。
const aiSendingEnabledUserKey = 'ai_sending_enabled_user_id';

/// このユーザーの `ai_sending_enabled` を読めなかった印。前の人のオンオフとは別に持つ。
const aiSendingReadFailedUserKey = 'ai_sending_read_failed_user_id';

/// 手元の「AIへの送信」は、今のアカウントの控えだけを使う。
///
/// 未ログイン、または保存したユーザーと違うときはオン（列の初期値と同じ）。
/// 前の人のオフを、次の人へ引き継がない。
bool aiSendingEnabledForUser({
  required String? sessionUserId,
  required String? storedUserId,
  required bool? storedEnabled,
}) {
  if (sessionUserId == null || sessionUserId.isEmpty) {
    return true;
  }
  if (storedUserId == null ||
      storedUserId.toLowerCase() != sessionUserId.toLowerCase()) {
    return true;
  }
  return storedEnabled ?? true;
}

/// 同意の読み取りが止まっても、同意画面か手元の控えへ戻すまでの上限。
///
/// 失敗した読み取りは手元の控えに戻る。応答が無い通信は例外にならないので、
/// この上限が無いと読み込み中のままになり、同意もログイン画面にも戻れない。
const termsLookupBudget = Duration(seconds: 8);

/// サーバの同意の版。読めなかったときは [failed]。
class TermsServerRead {
  const TermsServerRead.ok(this.serverVersion) : failed = false;

  const TermsServerRead.failed() : failed = true, serverVersion = null;

  final bool failed;
  final String? serverVersion;
}

/// [pending] が制限時間を超えても、例外でも、失敗として返す。
Future<TermsServerRead> readTermsServerVersion(
  Future<String?> pending, {
  Duration budget = termsLookupBudget,
}) async {
  try {
    return TermsServerRead.ok(await pending.timeout(budget));
  } catch (_) {
    return const TermsServerRead.failed();
  }
}

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

  /// 設定の「AIへの送信」。未設定はオン。
  bool get sendingEnabled;

  /// サーバの `ai_data_consents.ai_sending_enabled` と端末の控えを同じにする。
  Future<bool> setSendingEnabled(bool enabled);

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

  /// テストがセッションのユーザーIDを渡す。本番は null で、Supabase のセッションを使う。
  static String? Function()? sessionUserIdForTest;

  /// テストが `ai_sending_enabled` を渡す。行が無いときは null。本番は null。
  static Future<bool?> Function(String userId)? readSendingForTest;

  static PrefsAiDataConsent _sendingPrefs(SharedPreferences preferences) {
    return PrefsAiDataConsent(
      preferences,
      sessionUserId: sessionUserIdForTest,
      readServerSending: readSendingForTest,
    );
  }

  /// 今のアカウントのオンオフを、直前の読み取りでサーバから取れなかった。
  static Future<bool> sendingReadFailed() async {
    if (override != null) {
      return false;
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      return _sendingPrefs(preferences).sendingReadFailed;
    } catch (error) {
      debugPrint('[AYG] ai sending read failed: $error');
      return false;
    }
  }

  /// 設定のスイッチ。テストの差し替えがあればそれを見る。
  static Future<bool> isSendingEnabled() async {
    final current = override;
    if (current != null) {
      return current.sendingEnabled;
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      return _sendingPrefs(preferences).sendingEnabled;
    } catch (error) {
      debugPrint('[AYG] ai sending read failed: $error');
      return false;
    }
  }

  /// オンまたはオフをサーバへ書いてから、端末に残す。失敗したら false。
  static Future<bool> saveSendingEnabled(bool enabled) async {
    final current = override;
    if (current != null) {
      return current.setSendingEnabled(enabled);
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      return await _sendingPrefs(preferences).setSendingEnabled(enabled);
    } catch (error) {
      debugPrint('[AYG] ai sending update failed: $error');
      return false;
    }
  }

  /// ログインとアカウント切替で、今のユーザーの `ai_sending_enabled` を読み直す。
  ///
  /// 失敗しても例外は出さない。ログインは止めない。
  static Future<void> refreshSendingForCurrentUser() async {
    if (override != null) {
      return;
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      await _sendingPrefs(preferences).refreshSendingForSession();
    } catch (error) {
      debugPrint('[AYG] ai sending refresh failed: $error');
    }
  }

  /// ログアウトで、端末のオンオフと持ち主を消す。
  static Future<void> clearLocalSending() async {
    if (override != null) {
      return;
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      await _sendingPrefs(preferences).clearLocalSending();
    } catch (error) {
      debugPrint('[AYG] ai sending clear failed: $error');
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
  bool sending = true;

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

  @override
  bool get sendingEnabled => sending;

  @override
  Future<bool> setSendingEnabled(bool enabled) async {
    if (failGrant) {
      return false;
    }
    sending = enabled;
    return true;
  }
}

class PrefsAiDataConsent extends AiDataConsent {
  PrefsAiDataConsent(
    this._preferences, {
    this.sessionUserId,
    this.readServerSending,
  });

  final SharedPreferences _preferences;

  /// 未指定なら Supabase のセッション。テストはここへ渡す。
  final String? Function()? sessionUserId;

  /// 未指定なら `ai_data_consents.ai_sending_enabled` を読む。行が無いときは null。
  final Future<bool?> Function(String userId)? readServerSending;

  @override
  bool get isGranted =>
      _preferences.getString(aiDataConsentVersionKey) == aiDataConsentVersion;

  String? _sessionUserIdNow() {
    final injected = sessionUserId;
    if (injected != null) {
      return injected();
    }
    if (!SupabaseConfig.isConfigured) {
      return null;
    }
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (error) {
      debugPrint('[AYG] ai sending session read failed: $error');
      return null;
    }
  }

  @override
  bool get sendingEnabled {
    if (sendingReadFailed) {
      return false;
    }
    final stored = _preferences.containsKey(aiSendingEnabledKey)
        ? _preferences.getBool(aiSendingEnabledKey)
        : null;
    return aiSendingEnabledForUser(
      sessionUserId: _sessionUserIdNow(),
      storedUserId: _preferences.getString(aiSendingEnabledUserKey),
      storedEnabled: stored,
    );
  }

  /// 今のセッションの `ai_sending_enabled` を読めなかった。オンにはしない。
  bool get sendingReadFailed {
    final sessionUserId = _sessionUserIdNow();
    if (sessionUserId == null || sessionUserId.isEmpty) {
      return false;
    }
    final failedUserId = _preferences.getString(aiSendingReadFailedUserKey);
    return failedUserId != null &&
        failedUserId.toLowerCase() == sessionUserId.toLowerCase();
  }

  /// 今のセッションの人の値をサーバから読み、端末の控えをその人のものにする。
  ///
  /// 行が無いときはオン。通信に失敗したときはオンにせず、前の人の値では上書きしない。
  Future<void> refreshSendingForSession() async {
    final userId = _sessionUserIdNow();
    if (userId == null || userId.isEmpty) {
      return;
    }
    if (readServerSending == null && !SupabaseConfig.isConfigured) {
      return;
    }
    try {
      final enabled = await _fetchSending(userId).timeout(termsLookupBudget);
      final now = _sessionUserIdNow();
      if (now == null || now.toLowerCase() != userId.toLowerCase()) {
        return;
      }
      await _preferences.setBool(aiSendingEnabledKey, enabled);
      await _preferences.setString(aiSendingEnabledUserKey, userId);
      await _preferences.remove(aiSendingReadFailedUserKey);
    } catch (error) {
      debugPrint('[AYG] ai sending refresh failed: $error');
      final now = _sessionUserIdNow();
      if (now == null || now.toLowerCase() != userId.toLowerCase()) {
        return;
      }
      await _preferences.setString(aiSendingReadFailedUserKey, userId);
    }
  }

  Future<bool> _fetchSending(String userId) async {
    final injected = readServerSending;
    if (injected != null) {
      return await injected(userId) ?? true;
    }
    final supabase = Supabase.instance.client;
    final sessionUser = supabase.auth.currentUser?.id;
    if (sessionUser == null ||
        sessionUser.isEmpty ||
        sessionUser.toLowerCase() != userId.toLowerCase()) {
      throw StateError('ai sending session mismatch');
    }
    final row = await supabase
        .from('ai_data_consents')
        .select('ai_sending_enabled')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return true;
    }
    final value = row['ai_sending_enabled'];
    return value is bool ? value : true;
  }

  Future<void> clearLocalSending() async {
    await _preferences.remove(aiSendingEnabledKey);
    await _preferences.remove(aiSendingEnabledUserKey);
    await _preferences.remove(aiSendingReadFailedUserKey);
  }

  @override
  Future<bool> setSendingEnabled(bool enabled) async {
    if (!SupabaseConfig.isConfigured) {
      return false;
    }
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return false;
      }
      final updated = await supabase
          .from('ai_data_consents')
          .update({'ai_sending_enabled': enabled})
          .eq('user_id', userId)
          .select('user_id');
      if (updated.isEmpty) {
        return false;
      }
      await _preferences.setBool(aiSendingEnabledKey, enabled);
      await _preferences.setString(aiSendingEnabledUserKey, userId);
      await _preferences.remove(aiSendingReadFailedUserKey);
      return true;
    } catch (error) {
      debugPrint('[AYG] ai sending update failed: $error');
      return false;
    }
  }

  bool get hasServerCopy {
    final at = _preferences.getString(aiDataConsentAtKey);
    final userId = _preferences.getString(termsAgreementUserKey);
    return isGranted &&
        userId != null &&
        userId.isNotEmpty &&
        at != null &&
        at.isNotEmpty;
  }

  Future<String?> _policyVersion(SupabaseClient supabase, String userId) async {
    final row = await supabase
        .from('ai_data_consents')
        .select('policy_version')
        .eq('user_id', userId)
        .maybeSingle();
    final version = row?['policy_version'];
    return version is String ? version : null;
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
    if (_preferences.getString(aiDataConsentVersionKey) !=
        aiDataConsentVersion) {
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
      final read = await readTermsServerVersion(
        _policyVersion(supabase, userId),
      );
      final agreed = hasCurrentTermsAgreement(
        userId: userId,
        cachedUserId: _preferences.getString(termsAgreementUserKey),
        cachedVersion: _preferences.getString(aiDataConsentVersionKey),
        serverVersion: read.serverVersion,
        serverReadFailed: read.failed,
      );
      if (read.failed) {
        return agreed;
      }
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
      await _preferences.setString(
        aiDataConsentVersionKey,
        aiDataConsentVersion,
      );
      await _preferences.setString(aiDataConsentAtKey, at);
      return true;
    } catch (error) {
      debugPrint('[AYG] ai data consent save failed: $error');
      return false;
    }
  }
}
