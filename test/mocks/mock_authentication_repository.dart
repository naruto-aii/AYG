import 'dart:async';

import 'package:ayg/repositories/auth_exceptions.dart';
import 'package:ayg/repositories/authentication_repository.dart';

class MockAuthenticationRepository extends AuthenticationRepository {
  MockAuthenticationRepository({AuthUser? currentUser})
    : _currentUser = currentUser;

  AuthUser? _currentUser;
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  bool restoreSessionCalled = false;
  bool loginWithGoogleCalled = false;
  bool logoutCalled = false;
  bool simulateGoogleSignInCancelled = false;
  bool simulateGoogleSignInFailure = false;
  String googleSignInFailureMessage = 'Google sign-in failed.';

  void setCurrentUser(AuthUser? user) {
    _currentUser = user;
    _controller.add(_currentUser);
  }

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  Future<void> restoreSession() async {
    restoreSessionCalled = true;
  }

  @override
  Future<void> loginWithGoogle() async {
    loginWithGoogleCalled = true;
    if (simulateGoogleSignInCancelled) {
      throw GoogleSignInCancelledException();
    }
    if (simulateGoogleSignInFailure) {
      throw GoogleSignInFailedException(googleSignInFailureMessage);
    }
    _currentUser = const AuthUser(
      id: 'test-user-id',
      email: 'test@example.com',
    );
    _controller.add(_currentUser);
  }

  @override
  Future<void> loginWithApple() async {
    throw UnimplementedError('Apple Sign-In is not implemented yet.');
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    _currentUser = null;
    _controller.add(null);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
