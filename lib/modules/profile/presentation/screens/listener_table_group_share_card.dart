import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../tablegroup/domain/entities/table_group_profile_share.dart';
import '../../../tablegroup/presentation/widgets/table_group_overview_style.dart';
import '../../../tablegroup/presentation/widgets/table_group_share_preview.dart';
import 'listener_profile_theme.dart';

/// A publication preview contains public table information, never chat or
/// participant details. The draft and published card share the same layout.
class ListenerTableGroupShareCard extends StatelessWidget {
  const ListenerTableGroupShareCard({
    super.key,
    required this.share,
    required this.username,
    this.avatarUrl,
    this.onOpen,
    this.onRemove,
    this.onLike,
    this.onComments,
    this.onShare,
    this.likeCount,
    this.commentCount,
    this.isLiked = false,
    this.likeBusy = false,
    this.busy = false,
    this.isCurrent,
    this.now,
  }) : _draftTable = null,
       noteEditor = null,
       actions = null,
       visibilityLabel = null;

  const ListenerTableGroupShareCard.draft({
    super.key,
    required TableGroupProfileShareSource tableGroup,
    required this.username,
    this.avatarUrl,
    this.noteEditor,
    this.actions,
    this.visibilityLabel = 'Taslak · Henüz paylaşılmadı',
    this.busy = false,
    this.isCurrent,
    this.now,
  }) : _draftTable = tableGroup,
       share = null,
       onOpen = null,
       onRemove = null,
       onLike = null,
       onComments = null,
       onShare = null,
       likeCount = null,
       commentCount = null,
       isLiked = false,
       likeBusy = false;

  final TableGroupProfileShare? share;
  final TableGroupProfileShareSource? _draftTable;
  final String username;
  final String? avatarUrl;
  final Widget? noteEditor;
  final Widget? actions;
  final String? visibilityLabel;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;
  final VoidCallback? onLike;
  final VoidCallback? onComments;
  final VoidCallback? onShare;
  final int? likeCount;
  final int? commentCount;
  final bool isLiked;
  final bool likeBusy;
  final bool busy;
  final bool Function()? isCurrent;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final table = share?.tableGroup ?? _draftTable!;
    final instant = now ?? DateTime.now();
    final active = table.isActiveAt(instant);
    final published = share?.publishedAt.toLocal();
    final subtitle = published == null
        ? visibilityLabel
        : 'Bir masa paylaştı · ${published.day}.${published.month}.${published.year}';
    final note = share?.note?.trim() ?? '';
    final handle = username.trim().replaceFirst(RegExp(r'^@+'), '');
    return Container(
      key: ValueKey(
        share == null
            ? 'listener-table-group-draft-${table.id}'
            : 'listener-table-group-share-${share!.shareId}',
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.legacy(listenerProfileSurface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.legacyBorder(listenerProfileBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(1.3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: TableGroupOverviewStyle.brandGradient,
                    ),
                  ),
                  child: ClipOval(
                    child: AppCachedNetworkImage(
                      imageUrl: avatarUrl,
                      width: 41.4,
                      height: 41.4,
                      fit: BoxFit.cover,
                      errorBuilder: (_) => ColoredBox(
                        color: AppColors.legacy(listenerProfileSurface),
                        child: Center(
                          child: handle.isEmpty
                              ? Icon(
                                  Icons.person_outline_rounded,
                                  size: 22,
                                  color: AppColors.legacy(listenerProfileMuted),
                                )
                              : Text(
                                  handle.characters.first.toUpperCase(),
                                  style: TextStyle(
                                    color: AppColors.legacy(Colors.white),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$handle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.legacy(Colors.white),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: AppColors.legacy(listenerProfileMuted),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onRemove != null && share != null)
                PopupMenuButton<String>(
                  key: ValueKey(
                    'listener-table-group-remove-${share!.shareId}',
                  ),
                  tooltip: 'Paylaşım seçenekleri',
                  enabled: !busy,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz_rounded, size: 19),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: AppColors.legacy(listenerProfileMuted),
                  ),
                  onSelected: (action) {
                    if (action == 'delete' &&
                        !busy &&
                        (isCurrent?.call() ?? true)) {
                      onRemove?.call();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Paylaşımı sil'),
                    ),
                  ],
                ),
            ],
          ),
          if (noteEditor != null) ...[
            const SizedBox(height: 12),
            noteEditor!,
          ] else if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              note,
              style: TextStyle(
                color: AppColors.legacy(Colors.white),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TableGroupSharePreview(
            key: const Key('listener-table-group-source-preview'),
            table: table,
            now: instant,
            openAction: share != null && active
                ? TextButton(
                    key: ValueKey(
                      'listener-table-group-open-${share!.shareId}',
                    ),
                    onPressed: busy ? null : onOpen,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.legacy(listenerProfileMuted),
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Masayı gör',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(Icons.chevron_right_rounded, size: 16),
                      ],
                    ),
                  )
                : null,
          ),
          if (share != null) ...[
            const SizedBox(height: 16),
            Divider(color: AppColors.legacy(listenerProfileBorder), height: 1),
            const SizedBox(height: 5),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Wrap(
                  spacing: 19,
                  runSpacing: 8,
                  children: [
                    _TableAction(
                      key: ValueKey(
                        'listener-table-group-like-${share!.shareId}',
                      ),
                      label: isLiked ? 'Beğeniyi kaldır' : 'Beğen',
                      countLabel: 'beğeni',
                      count: likeCount,
                      icon: isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: AppColors.likeHeart,
                      selected: isLiked,
                      onPressed: busy || likeBusy ? null : onLike,
                    ),
                    _TableAction(
                      key: ValueKey(
                        'listener-table-group-comments-${share!.shareId}',
                      ),
                      label: 'Yorumlar',
                      countLabel: 'yorum',
                      count: commentCount,
                      icon: Icons.chat_bubble_outline_rounded,
                      color: AppColors.legacy(listenerProfileMuted),
                      onPressed: busy || likeBusy ? null : onComments,
                    ),
                  ],
                ),
                if (onShare != null)
                  IconButton(
                    key: ValueKey(
                      'listener-table-group-external-share-${share!.shareId}',
                    ),
                    tooltip: 'Paylaş',
                    onPressed: busy || likeBusy ? null : onShare,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: AppColors.legacy(listenerProfileMuted),
                    ),
                    icon: const Icon(Icons.send_outlined, size: 20),
                  ),
              ],
            ),
          ],
          if (actions != null) ...[const SizedBox(height: 16), actions!],
        ],
      ),
    );
  }
}

class _TableAction extends StatelessWidget {
  const _TableAction({
    super.key,
    required this.label,
    required this.countLabel,
    required this.count,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.selected,
  });
  final String label;
  final String countLabel;
  final int? count;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: label,
      value: count == null ? 'Sayı doğrulanamadı' : '$count $countLabel',
      onTap: onPressed,
      child: ExcludeSemantics(
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 5),
              Text(
                count == null
                    ? '—'
                    : NumberFormat.compact(locale: 'tr').format(count),
                style: TextStyle(
                  color: AppColors.legacy(listenerProfileMuted),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
