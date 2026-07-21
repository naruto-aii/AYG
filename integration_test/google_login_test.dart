import 'package:ayg/config/supabase_config.dart';
import 'package:ayg/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Google login flow starts on device', (tester) async {
    expect(SupabaseConfig.isConfigured, isTrue);
    expect(SupabaseConfig.isGoogleConfigured, isTrue);
    expect(SupabaseConfig.googleIosClientId.isNotEmpty, isTrue);

    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.text('Googleでログイン'), findsOneWidget);

    await tester.tap(find.text('Googleでログイン'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(find.textContaining('Googleログインに失敗しました'), findsNothing);
  });
}
