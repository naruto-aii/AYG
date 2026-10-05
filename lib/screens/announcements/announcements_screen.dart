import 'package:flutter/material.dart';

import '../../models/announcement.dart';
import '../../repositories/announcement_read_store.dart';
import '../../repositories/announcement_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/local_date.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_page.dart';

/// お知らせを開いたら、今出ている行を既読にする。
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, this.repository, this.readStore});

  final AnnouncementRepository? repository;
  final AnnouncementReadStore? readStore;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<Announcement>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = widget.repository ?? SupabaseAnnouncementRepository();
    final readStore = widget.readStore ?? PreferencesAnnouncementReadStore();
    final items = await repository.published();
    await readStore.markRead(items.map((item) => item.id));
    if (!mounted) {
      return;
    }
    setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: 'お知らせ',
            subtitle: '運営からの連絡です。ホームの赤い点は、まだ開いていないお知らせです。',
          ),
          const SizedBox(height: 8),
          if (items == null)
            Text('読み込んでいます', style: AppTypography.bodyS)
          else if (items.isEmpty)
            Text('お知らせはありません', style: AppTypography.bodyS)
          else
            for (final item in items) ...[
              DesignCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: AppTypography.titleM),
                    const SizedBox(height: 4),
                    Text(
                      formatJapaneseDateWithWeekday(item.publishedAt),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(item.body, style: AppTypography.bodyS),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}
