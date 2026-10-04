import 'package:shared_preferences/shared_preferences.dart';

/// 開いたお知らせの id。端末に残し、announcements へは書かない。
abstract class AnnouncementReadStore {
  Future<Set<String>> readIds();
  Future<void> markRead(Iterable<String> ids);
}

class PreferencesAnnouncementReadStore implements AnnouncementReadStore {
  PreferencesAnnouncementReadStore({this.preferences});

  static const storageKey = 'announcement_read_ids_v1';

  final SharedPreferences? preferences;

  @override
  Future<Set<String>> readIds() async {
    try {
      final raw = (await _prefs()).getStringList(storageKey);
      return raw?.toSet() ?? {};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> markRead(Iterable<String> ids) async {
    try {
      final prefs = await _prefs();
      final next = await readIds()
        ..addAll(ids);
      await prefs.setStringList(storageKey, next.toList());
    } catch (_) {
      return;
    }
  }

  Future<SharedPreferences> _prefs() async {
    return preferences ?? await SharedPreferences.getInstance();
  }
}
