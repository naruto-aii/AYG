import 'package:ayg/repositories/google_sign_in_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not construct GoogleSignIn when the iOS client ID is empty', () {
    expect(
      createGoogleSignIn(
        iosClientId: '',
        webClientId: '123.apps.googleusercontent.com',
      ),
      isNull,
    );
  });

  test('constructs GoogleSignIn when the iOS client ID is present', () {
    expect(
      createGoogleSignIn(
        iosClientId: 'ios.apps.googleusercontent.com',
        webClientId: 'web.apps.googleusercontent.com',
      ),
      isNotNull,
    );
  });
}
