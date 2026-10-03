import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Apple の認可コードをリフレッシュトークンへ交換して保存する Edge Function。
const storeAppleRefreshTokenFunction = 'store-apple-refresh-token';

typedef EdgeFunctionInvoke =
    Future<FunctionResponse> Function(String functionName, {Object? body});

/// [authorizationCode] を Edge Function へ送る。失敗しても、済んだサインインは
/// 取り消さない。レスポンス本文は出さない。
Future<void> storeAppleAuthorizationCode({
  required EdgeFunctionInvoke invoke,
  required String authorizationCode,
}) async {
  final code = authorizationCode.trim();
  if (code.isEmpty) {
    return;
  }
  try {
    await invoke(
      storeAppleRefreshTokenFunction,
      body: {'authorization_code': code},
    );
  } catch (_) {
    debugPrint('Sign in with Apple refresh token was not stored.');
  }
}

/// ネイティブの Apple サインインを先に完了し、そのあと認可コードを保存する。
/// 保存の失敗はサインイン成功を取り消さない。
Future<void> finishNativeAppleSignIn({
  required Future<void> Function() signIn,
  required String authorizationCode,
  required Future<void> Function(String authorizationCode) storeCode,
}) async {
  await signIn();
  try {
    await storeCode(authorizationCode);
  } catch (_) {
    debugPrint('Sign in with Apple refresh token was not stored.');
  }
}
