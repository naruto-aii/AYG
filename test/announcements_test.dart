import 'package:ayg/models/announcement.dart';
import 'package:ayg/repositories/announcement_read_store.dart';
import 'package:ayg/repositories/announcement_repository.dart';
import 'package:ayg/screens/announcements/announcements_screen.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/announcements/home_announcements_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final notice = Announcement(
    id: 'a1',
    title: '検証中の機能について',
    body: '今日のコーチは検証中です。',
    publishedAt: DateTime(2026, 10, 4),
  );

  test('one unread item is enough', () {
    expect(Announcement.hasUnread([notice], {}), isTrue);
    expect(Announcement.hasUnread([notice], {'a1'}), isFalse);
    expect(Announcement.hasUnread(const [], {}), isFalse);
  });

  testWidgets('home shows a red dot until the announcements are opened', (
    tester,
  ) async {
    final repository = _FixedAnnouncements([notice]);
    final reads = _MemoryReads();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeAnnouncementsEntry(
            repository: repository,
            readStore: reads,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('announcement_unread_dot')), findsOneWidget);
    expect(find.text('検証中の機能について'), findsOneWidget);

    await tester.tap(find.text('お知らせ'));
    await tester.pumpAndSettle();

    expect(find.text('今日のコーチは検証中です。'), findsOneWidget);
    expect(reads.ids, {'a1'});

    await tester.tap(find.text('戻る'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('announcement_unread_dot')), findsNothing);
  });

  testWidgets('opening an empty list does not show a dot', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AnnouncementsScreen(
          repository: _FixedAnnouncements(const []),
          readStore: _MemoryReads(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('お知らせはありません'), findsOneWidget);
  });
}

class _FixedAnnouncements implements AnnouncementRepository {
  _FixedAnnouncements(this.items);

  final List<Announcement> items;

  @override
  Future<List<Announcement>> published() async => items;
}

class _MemoryReads implements AnnouncementReadStore {
  final ids = <String>{};

  @override
  Future<Set<String>> readIds() async => ids;

  @override
  Future<void> markRead(Iterable<String> next) async {
    ids.addAll(next);
  }
}
