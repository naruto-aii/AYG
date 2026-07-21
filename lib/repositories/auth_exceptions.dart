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
