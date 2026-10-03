import 'auth_exceptions.dart';

/// 認証 Repository。
abstract class AuthenticationRepository {
  AuthUser? get currentUser;

  bool get isAuthenticated => currentUser != null;

  Stream<AuthUser?> get authStateChanges;

  Future<void> restoreSession();

  Future<void> loginWithGoogle();

  Future<void> loginWithApple();

  Future<void> logout();

  /// 個人の記録を消し、公開食品は残す。削除用 Function が無いときは
  /// [AccountDeletionUnavailableException] を投げ、ログアウトしない。
  Future<AccountDeletionOutcome> deleteOwnAccount();
}

/// 認証済みユーザー情報。
class AuthUser {
  const AuthUser({required this.id, this.email, this.suggestedDisplayName});

  final String id;
  final String? email;

  /// サインインが名前を返したときだけ入る。無ければ null。
  final String? suggestedDisplayName;
}
