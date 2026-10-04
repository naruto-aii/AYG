import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/announcement.dart';

/// 公開済みのお知らせ。失敗してもホームは止めない。
abstract class AnnouncementRepository {
  Future<List<Announcement>> published();
}

class SupabaseAnnouncementRepository implements AnnouncementRepository {
  SupabaseAnnouncementRepository({this.client});

  final SupabaseClient? client;

  @override
  Future<List<Announcement>> published() async {
    final resolved = client ?? _currentClient();
    if (resolved == null) {
      return const [];
    }
    try {
      final rows = await resolved
          .from('announcements')
          .select('id, title, body, published_at')
          .order('published_at', ascending: false);
      return [for (final row in rows) ?_announcement(row)];
    } catch (_) {
      return const [];
    }
  }

  SupabaseClient? _currentClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}

Announcement? _announcement(Map<String, dynamic> row) {
  final id = row['id']?.toString();
  final title = row['title']?.toString().trim();
  final body = row['body']?.toString().trim();
  final published = DateTime.tryParse(row['published_at']?.toString() ?? '');
  if (id == null ||
      id.isEmpty ||
      title == null ||
      title.isEmpty ||
      body == null ||
      body.isEmpty ||
      published == null) {
    return null;
  }
  return Announcement(
    id: id,
    title: title,
    body: body,
    publishedAt: published.toLocal(),
  );
}
