/// 運営が announcements に入れた1件。
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime publishedAt;

  /// 未読が1件でもあれば true。
  static bool hasUnread(List<Announcement> items, Set<String> readIds) {
    for (final item in items) {
      if (!readIds.contains(item.id)) {
        return true;
      }
    }
    return false;
  }
}
