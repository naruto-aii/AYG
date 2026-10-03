import 'package:supabase_flutter/supabase_flutter.dart';

import 'apple_refresh_token.dart';
import 'auth_exceptions.dart';

/// Apple トークンを失効してからアカウントを消す Edge Function。
const deleteAccountFunction = 'delete-account';

/// 画面は固定の文言を出す。この文字列はレスポンス本文の代わり。
const accountDeletionGenericFailure = 'account deletion failed';

/// `delete-account` が Apple トークンを失効し、アカウントを消す。
/// アプリはデータベース関数を直接呼ばない。Function が無いときは
/// [AccountDeletionUnavailableException] で、アカウントもセッションもそのまま。
/// [AccountDeletionOutcome.appleRevokeFailed] は、保存済みトークンの失効だけが
/// 失敗したときに true。その時点でアカウント削除は終わっている。
Future<AccountDeletionOutcome> deleteOwnAccountWithClient(
  SupabaseClient client,
) {
  return deleteOwnAccountWithInvoker(
    (functionName, {body}) => client.functions.invoke(functionName, body: body),
  );
}

Future<AccountDeletionOutcome> deleteOwnAccountWithInvoker(
  EdgeFunctionInvoke invoke,
) async {
  try {
    final response = await invoke(deleteAccountFunction);
    return accountDeletionOutcomeFromResponse(response.status, response.data);
  } on FunctionException catch (error) {
    if (error.status == 404) {
      throw AccountDeletionUnavailableException();
    }
    throw const AccountDeletionFailedException(accountDeletionGenericFailure);
  } on AccountDeletionUnavailableException {
    rethrow;
  } on AccountDeletionFailedException {
    rethrow;
  } catch (_) {
    throw const AccountDeletionFailedException(accountDeletionGenericFailure);
  }
}

AccountDeletionOutcome accountDeletionOutcomeFromResponse(
  int status,
  Object? data,
) {
  if (status == 404) {
    throw AccountDeletionUnavailableException();
  }
  if (status < 200 || status >= 300) {
    throw const AccountDeletionFailedException(accountDeletionGenericFailure);
  }
  if (data is Map && data['ok'] == false) {
    throw const AccountDeletionFailedException(accountDeletionGenericFailure);
  }
  final revokeFailed = data is Map && data['apple_revoke_failed'] == true;
  return AccountDeletionOutcome(appleRevokeFailed: revokeFailed);
}
