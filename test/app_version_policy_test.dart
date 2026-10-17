import 'dart:io';

import 'package:ayg/repositories/app_version_policy_repository.dart';
import 'package:ayg/screens/update/app_update_screen.dart';
import 'package:ayg/services/app_update_prompt.dart';
import 'package:ayg/services/app_version_policy.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test('the version policy is one readable row seeded at 0.0.0', () {
    final sql = File(
      'supabase/migrations/20261017030000_app_version_policy.sql',
    ).readAsStringSync();

    expect(sql, contains('public.app_version_policy'));
    expect(sql, contains('id int primary key default 1 check (id = 1)'));
    expect(sql, contains('minimum_version text not null'));
    expect(sql, contains('recommended_version text not null'));
    expect(sql, contains('ios_store_url text not null'));
    expect(
      sql,
      contains(
        "updated_at timestamptz not null default timezone('utc', now())",
      ),
    );
    expect(sql, contains('enable row level security'));
    expect(sql, contains('for select'));
    expect(sql, contains('to anon, authenticated'));
    expect(
      sql,
      contains('revoke all on table public.app_version_policy from public'),
    );
    expect(
      sql,
      contains('grant select on table public.app_version_policy to anon'),
    );
    expect(
      sql,
      contains(
        'grant select on table public.app_version_policy to authenticated',
      ),
    );
    expect(sql, contains('grant select, insert, update, delete'));
    expect(sql, contains('to service_role'));
    expect(sql, contains("'0.0.0'"));
    expect(sql, contains('https://apps.apple.com/jp/app/id6814054275'));
    expect(
      sql,
      isNot(
        contains(
          'grant insert, update, delete on table public.app_version_policy to anon',
        ),
      ),
    );
    expect(
      sql,
      isNot(
        contains(
          'grant insert, update, delete on table public.app_version_policy to authenticated',
        ),
      ),
    );
  });

  test('versions compare major.minor.patch and an optional policy build', () {
    expect(
      decideAppUpdate(current: '1.0.0', minimum: '1.0.1', recommended: '1.0.1'),
      AppUpdateDecision.required,
    );
    expect(
      decideAppUpdate(
        current: '1.2.0+9',
        minimum: '1.2.0',
        recommended: '1.2.0',
      ),
      AppUpdateDecision.none,
    );
    expect(
      decideAppUpdate(
        current: '1.2.0+3',
        minimum: '1.2.0+4',
        recommended: '1.2.0+4',
      ),
      AppUpdateDecision.required,
    );
    expect(
      decideAppUpdate(
        current: '1.2.0+3',
        minimum: '1.2.0',
        recommended: '1.2.0+4',
      ),
      AppUpdateDecision.recommended,
    );
    expect(
      decideAppUpdate(current: '1.2', minimum: '1.2.0', recommended: '1.2.0'),
      AppUpdateDecision.none,
    );
    expect(
      decideAppUpdate(current: '1', minimum: '1.0.1', recommended: '1.0.1'),
      AppUpdateDecision.required,
    );
    expect(
      decideAppUpdate(
        current: '1.2.0',
        minimum: '0.0.0',
        recommended: '1.2.0+4',
      ),
      AppUpdateDecision.recommended,
    );
    expect(
      decideAppUpdate(
        current: '1.10.0',
        minimum: '1.9.0',
        recommended: '1.9.0',
      ),
      AppUpdateDecision.none,
    );
    expect(
      decideAppUpdate(
        current: '1.0.0+1',
        minimum: '1.0.0+2',
        recommended: '1.0.0+2',
      ),
      AppUpdateDecision.required,
    );
  });

  test('the seeded 0.0.0 policy does not block 1.0.0+13', () {
    expect(
      decideAppUpdate(
        current: '1.0.0+13',
        minimum: '0.0.0',
        recommended: '0.0.0',
      ),
      AppUpdateDecision.none,
    );
  });

  test('below the minimum is required', () {
    expect(
      decideAppUpdate(
        current: '1.0.0+2',
        minimum: '1.0.1',
        recommended: '2.0.0',
      ),
      AppUpdateDecision.required,
    );
  });

  test(
    'below the recommended version and at least the minimum is recommended',
    () {
      expect(
        decideAppUpdate(
          current: '1.0.0+2',
          minimum: '1.0.0',
          recommended: '1.1.0',
        ),
        AppUpdateDecision.recommended,
      );
    },
  );

  test('a thrown lookup yields null and does not decide', () async {
    var decided = false;
    AppUpdateDecision spy({
      required String current,
      required String minimum,
      required String recommended,
    }) {
      decided = true;
      return decideAppUpdate(
        current: current,
        minimum: minimum,
        recommended: recommended,
      );
    }

    expect(await readPolicy(() async => throw StateError('down')), isNull);
    expect(
      await AppVersionPolicyRepository(
        load: () async => throw StateError('down'),
      ).fetch(),
      isNull,
    );
    expect(await AppVersionPolicyRepository().fetch(), isNull);

    final policy = await readPolicy(() async => throw StateError('down'));
    if (policy != null) {
      spy(
        current: '1.0.0+2',
        minimum: policy.minimum,
        recommended: policy.recommended,
      );
    }
    expect(decided, isFalse);
  });

  testWidgets('the recommended screen has あとで', (tester) async {
    await _pumpScreen(
      tester,
      const AppUpdateScreen(
        decision: AppUpdateDecision.recommended,
        storeUrl: 'https://apps.apple.com/jp/app/id6814054275',
      ),
    );

    expect(find.text('新しいバージョンがあります'), findsOneWidget);
    expect(find.text('アップストアで更新'), findsOneWidget);
    expect(find.text('あとで'), findsOneWidget);
  });

  testWidgets('the required screen has no あとで', (tester) async {
    await _pumpScreen(
      tester,
      const AppUpdateScreen(
        decision: AppUpdateDecision.required,
        storeUrl: 'https://apps.apple.com/jp/app/id6814054275',
      ),
    );

    expect(find.text('アップデートが必要です'), findsOneWidget);
    expect(find.text('このバージョンでは続けられません。'), findsOneWidget);
    expect(find.text('アップストアで更新'), findsOneWidget);
    expect(find.text('あとで'), findsNothing);
  });

  testWidgets('the store button opens the policy url and ignores failure', (
    tester,
  ) async {
    Uri? opened;
    LaunchMode? openedMode;
    await _pumpScreen(
      tester,
      AppUpdateScreen(
        decision: AppUpdateDecision.required,
        storeUrl: 'https://apps.apple.com/jp/app/id6814054275',
        launch: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
          opened = uri;
          openedMode = mode;
          return false;
        },
      ),
    );

    await tester.tap(find.text('アップストアで更新'));
    await tester.pump();

    expect(opened, Uri.parse('https://apps.apple.com/jp/app/id6814054275'));
    expect(openedMode, LaunchMode.externalApplication);
    expect(find.text('アップデートが必要です'), findsOneWidget);

    await _pumpScreen(
      tester,
      AppUpdateScreen(
        decision: AppUpdateDecision.recommended,
        storeUrl: 'https://apps.apple.com/jp/app/id6814054275',
        launch: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
          throw StateError('unavailable');
        },
      ),
    );
    await tester.tap(find.text('アップストアで更新'));
    await tester.pump();
    expect(find.text('新しいバージョンがあります'), findsOneWidget);
    expect(find.text('あとで'), findsOneWidget);
  });

  testWidgets('あとで dismisses the recommended prompt for this process', (
    tester,
  ) async {
    final prompt = AppUpdatePrompt();
    final repository = AppVersionPolicyRepository(
      load: () async => const AppVersionPolicy(
        minimum: '0.0.0',
        recommended: '9.0.0',
        storeUrl: 'https://apps.apple.com/jp/app/id6814054275',
      ),
    );
    final navigator = await _pumpHost(tester);

    final first = prompt.present(
      navigator: navigator,
      currentVersion: '1.0.0+2',
      repository: repository,
    );
    await tester.pumpAndSettle();
    expect(find.text('あとで'), findsOneWidget);

    await tester.tap(find.text('あとで'));
    await tester.pumpAndSettle();
    await first;

    expect(prompt.recommendedDismissed, isTrue);
    expect(find.text('新しいバージョンがあります'), findsNothing);

    await prompt.present(
      navigator: navigator,
      currentVersion: '1.0.0+2',
      repository: repository,
    );
    await tester.pumpAndSettle();
    expect(find.text('あとで'), findsNothing);
  });

  testWidgets('a required update still shows after recommended was dismissed', (
    tester,
  ) async {
    final prompt = AppUpdatePrompt()..recommendedDismissed = true;
    final navigator = await _pumpHost(tester);

    final repository = AppVersionPolicyRepository(
      load: () async => const AppVersionPolicy(
        minimum: '9.0.0',
        recommended: '9.0.0',
        storeUrl: 'https://apps.apple.com/jp/app/id6814054275',
      ),
    );
    await prompt.present(
      navigator: navigator,
      currentVersion: '1.0.0+2',
      repository: repository,
    );
    await tester.pumpAndSettle();

    expect(find.text('アップデートが必要です'), findsOneWidget);
    expect(find.text('あとで'), findsNothing);

    await prompt.present(
      navigator: navigator,
      currentVersion: '1.0.0+2',
      repository: repository,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('a failed fetch shows nothing', (tester) async {
    final prompt = AppUpdatePrompt();
    final navigator = await _pumpHost(tester);

    await prompt.present(
      navigator: navigator,
      currentVersion: '1.0.0+2',
      repository: AppVersionPolicyRepository(
        load: () async => throw StateError('down'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('アップストアで更新'), findsNothing);
  });

  testWidgets('an unreadable app version shows nothing', (tester) async {
    final prompt = AppUpdatePrompt();
    final navigator = await _pumpHost(tester);

    await prompt.present(
      navigator: navigator,
      currentVersion: null,
      repository: AppVersionPolicyRepository(
        load: () async => const AppVersionPolicy(
          minimum: '1.0.0+14',
          recommended: '1.0.0+14',
          storeUrl: 'https://apps.apple.com/jp/app/id6814054275',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('アップデートが必要です'), findsNothing);
    expect(find.text('アップストアで更新'), findsNothing);
  });

  testWidgets('a prompt route already on the stack is not pushed again', (
    tester,
  ) async {
    final navigator = await _pumpHost(tester);
    navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: appUpdatePromptRouteName),
        builder: (context) => const Text('already'),
      ),
    );
    await tester.pumpAndSettle();

    await AppUpdatePrompt().present(
      navigator: navigator,
      currentVersion: '1.0.0',
      repository: AppVersionPolicyRepository(
        load: () async => const AppVersionPolicy(
          minimum: '9.0.0',
          recommended: '9.0.0',
          storeUrl: 'https://apps.apple.com/jp/app/id6814054275',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('already'), findsOneWidget);
    expect(find.text('アップデートが必要です'), findsNothing);
  });

  testWidgets('the required screen does not pop', (tester) async {
    final navigator = await _pumpHost(tester);
    navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: appUpdatePromptRouteName),
        builder: (context) => const AppUpdateScreen(
          decision: AppUpdateDecision.required,
          storeUrl: 'https://apps.apple.com/jp/app/id6814054275',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await navigator.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('アップデートが必要です'), findsOneWidget);
  });
}

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
}

Future<NavigatorState> _pumpHost(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final key = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      navigatorKey: key,
      home: const Scaffold(body: Text('home')),
    ),
  );
  return key.currentState!;
}
