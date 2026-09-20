import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Native Google Sign-In. Empty iOS client ID must not construct the SDK.
/// The iOS plugin crashes with: You must specify |clientID| in |GIDConfiguration|.
GoogleSignIn? createGoogleSignIn({
  required String iosClientId,
  required String webClientId,
}) {
  if (kIsWeb || iosClientId.isEmpty) {
    return null;
  }
  return GoogleSignIn(
    clientId: iosClientId,
    serverClientId: webClientId.isEmpty ? null : webClientId,
  );
}
