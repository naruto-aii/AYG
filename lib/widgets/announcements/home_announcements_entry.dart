import 'package:flutter/material.dart';

import '../../models/announcement.dart';
import '../../repositories/announcement_read_store.dart';
import '../../repositories/announcement_repository.dart';
import '../../screens/announcements/announcements_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../design/design_card.dart';
import '../design/design_icon.dart';

/// ホームのお知らせ欄。未読が1件でもあれば赤い点を付ける。
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            AnnouncementsScreen(repository: _repository, readStore: _readStore),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final unread = Announcement.hasUnread(_items, _readIds);
    final latest = _items.isEmpty ? null : _items.first.title;
    return DesignCard(
      onTap: _open,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('お知らせ', style: AppTypography.titleM),
                    if (unread) ...[
                      const SizedBox(width: 8),
                      const _UnreadDot(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  latest ?? '運営からの連絡です',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyS.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const DesignIcon(
            Symbols.chevron_right_rounded,
            size: 16,
            color: AppColors.iconMuted,
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
