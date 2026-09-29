import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../config/supabase_config.dart';
import '../../../repositories/auth_exceptions.dart';
import '../../../repositories/authentication_repository.dart';

/// Web 向け Supabase OAuth 認証（Google のみ）。
class WebSupabaseAuthenticationRepository extends AuthenticationRepository {
  WebSupabaseAuthenticationRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  AuthUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges {
    return _client.auth.onAuthStateChange.map(
      (event) => _mapUser(event.session?.user),
    );
  }

  @override
  Future<void> restoreSession() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      return;
    }
    await _client.auth.refreshSession();
  }

  @override
  Future<void> loginWithGoogle() async {
    if (!SupabaseConfig.isGoogleConfigured) {
      throw GoogleSignInFailedException('Google Sign-In is not configured.');
    }

    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _redirectUrl,
      );
    } on AuthException catch (error) {
      throw GoogleSignInFailedException(error.message);
    }
  }

  @override
  Future<void> loginWithApple() async {
    throw UnimplementedError('Apple Sign-In is not available on Web preview.');
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  String get _redirectUrl {
    final base = Uri.base;
    final path = base.path.endsWith('/') ? base.path : '${base.path}/';
    return '${base.origin}$path';
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    return AuthUser(id: user.id, email: user.email);
  }
}
