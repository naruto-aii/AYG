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

/// Apple Sign-In がユーザー操作でキャンセルされた。
class AppleSignInCancelledException implements Exception {
  @override
  String toString() => 'Apple sign-in was cancelled.';
}

/// Apple Sign-In / Supabase Auth が失敗した。
class AppleSignInFailedException implements Exception {
  AppleSignInFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Web プレビューなど、この画面では Apple ログインが使えない。
class AppleSignInUnavailableException implements Exception {
  @override
  String toString() => 'Apple sign-in is not available.';
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
