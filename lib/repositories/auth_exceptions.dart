/// Google Sign-In がユーザー操作でキャンセルされた。
class GoogleSignInCancelledException implements Exception {
  @override
  String toString() => 'Google sign-in was cancelled.';
}

/// Google Sign-In / Supabase Auth が失敗した。
class GoogleSignInFailedException implements Exception {
  GoogleSignInFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 本番に delete_own_account がまだ無い。
class AccountDeletionUnavailableException implements Exception {
  @override
  String toString() => 'Account deletion is not available.';
}

/// アカウント削除に失敗した。
class AccountDeletionFailedException implements Exception {
  AccountDeletionFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}
