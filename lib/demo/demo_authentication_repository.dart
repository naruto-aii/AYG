import 'dart:async';

import '../repositories/auth_exceptions.dart';
import '../repositories/authentication_repository.dart';

/// ネットワークを使わないデモ利用者。カロナビ+ の画面を通すための固定アカウント。
class DemoAuthenticationRepository implements AuthenticationRepository {
  DemoAuthenticationRepository({this.beforeLogin});

  static const userId = '00000000-0000-4000-8000-0000000000d1';

  /// ログイン通知の前に、保存済み食品などを用意する。
  final Future<void> Function()? beforeLogin;

  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> loginWithGoogle() => loginAsDemo();

  @override
  Future<void> loginWithApple() => loginAsDemo();

  Future<void> loginAsDemo() async {
    if (beforeLogin != null) {
      await beforeLogin!();
    }
    _user = const AuthUser(
      id: userId,
      email: 'demo@calonavi.invalid',
      suggestedDisplayName: 'デモ',
    );
    _controller.add(_user);
  }

  @override
  Future<void> logout() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<AccountDeletionOutcome> deleteOwnAccount() {
    throw AccountDeletionUnavailableException();
  }
}
