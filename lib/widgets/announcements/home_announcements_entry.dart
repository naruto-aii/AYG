import 'package:flutter/material.dart';

import '../../models/announcement.dart';
import '../../services/analytics/catalog_actions.dart';
import '../../repositories/announcement_read_store.dart';
import '../../repositories/announcement_repository.dart';
import '../../screens/announcements/announcements_screen.dart';
import '../../theme/app_colors.dart';
import '../design/design_icon.dart';

/// ホーム右上の共有ボタンの隣に置く、お知らせを開く丸ボタン。
/// 未読が1件でもあれば右上に赤い点を付ける。
class HomeAnnouncementsEntry extends StatefulWidget {
  const HomeAnnouncementsEntry({super.key, this.repository, this.readStore});

  final AnnouncementRepository? repository;
  final AnnouncementReadStore? readStore;

  @override
  State<HomeAnnouncementsEntry> createState() => _HomeAnnouncementsEntryState();
}

class _HomeAnnouncementsEntryState extends State<HomeAnnouncementsEntry> {
  List<Announcement> _items = const [];
  Set<String> _readIds = const {};

  AnnouncementRepository get _repository =>
      widget.repository ?? SupabaseAnnouncementRepository();

  AnnouncementReadStore get _readStore =>
      widget.readStore ?? PreferencesAnnouncementReadStore();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final items = await _repository.published();
    final readIds = await _readStore.readIds();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _readIds = readIds;
    });
  }

  Future<void> _open() async {
    final id = _items.isEmpty ? 'list' : _items.first.id;
    CatalogActions.announcementRead(id);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'home_announcements_entry_MaterialPageRoute_0'),
        builder: (context) =>
            AnnouncementsScreen(repository: _repository, readStore: _readStore),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final unread = Announcement.hasUnread(_items, _readIds);
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            key: const Key('home_announcements_button'),
            tooltip: 'お知らせ',
            onPressed: _open,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            icon: const DesignIcon(
              Symbols.campaign_rounded,
              size: 20,
              color: AppColors.iconMuted,
            ),
          ),
          if (unread)
            const Positioned(
              top: 1,
              right: 1,
              child: IgnorePointer(child: _UnreadDot()),
            ),
        ],
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('announcement_unread_dot'),
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.red500,
        shape: BoxShape.circle,
      ),
    );
  }
}
