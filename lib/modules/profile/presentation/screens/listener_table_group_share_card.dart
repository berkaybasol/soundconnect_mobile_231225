import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../tablegroup/domain/entities/table_group_profile_share.dart';
import '../../../tablegroup/domain/table_group_expiry_policy.dart';
import '../../../tablegroup/presentation/widgets/table_group_overview_style.dart';
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
    final table = share?.tableGroup ?? _draftTable!;
    final instant = now ?? DateTime.now();
    final active = table.isActiveAt(instant);
    final awaitingFinalSnapshot = table.needsFinalSnapshotAt(instant);
    final endedLabel = active
        ? null
        : table.status == 'CANCELLED'
        ? 'Bu masa kapatıldı'
        : 'Bu masanın süresi doldu';
    final published = share?.publishedAt.toLocal();
    final subtitle = published == null
        ? visibilityLabel
        : 'Bir masa paylaştı · ${published.day}.${published.month}.${published.year}';
    final note = share?.note?.trim() ?? '';
    final location = [table.districtName, table.cityName]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' · ');
    final description = table.description?.trim() ?? '';
    final venue = table.venueName?.trim() ?? '';
    final handle = username.trim().replaceFirst(RegExp(r'^@+'), '');
    return Container(
      key: ValueKey(
        share == null
            ? 'listener-table-group-draft-${table.id}'
            : 'listener-table-group-share-${share!.shareId}',
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: listenerProfileSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: listenerProfileBorder),
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
                  decoration: const BoxDecoration(
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
                        color: listenerProfileSurface,
                        child: Center(
                          child: handle.isEmpty
                              ? const Icon(
                                  Icons.person_outline_rounded,
                                  size: 22,
                                  color: listenerProfileMuted,
                                )
                              : Text(
                                  handle.characters.first.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: listenerProfileMuted,
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
                    foregroundColor: listenerProfileMuted,
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Column(
            key: const Key('listener-table-group-source-preview'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  description.isEmpty ? 'Birlikte bir masada' : description,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                    height: 1.22,
                  ),
                ),
              ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 7),
                _TableDetail(icon: Icons.location_on_outlined, text: location),
              ],
              const SizedBox(height: 17),
              _TableInformation(
                table: table,
                venue: venue.isEmpty
                    ? TableGroupOverviewStyle.unspecifiedVenueLabel
                    : venue,
                instant: instant,
                awaitingFinalSnapshot: awaitingFinalSnapshot,
                endedLabel: endedLabel,
                openAction: share != null && active
                    ? TextButton(
                        key: ValueKey(
                          'listener-table-group-open-${share!.shareId}',
                        ),
                        onPressed: busy ? null : onOpen,
                        style: TextButton.styleFrom(
                          foregroundColor: listenerProfileMuted,
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
            ],
          ),
          if (share != null) ...[
            const SizedBox(height: 16),
            const Divider(color: listenerProfileBorder, height: 1),
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
                      color: listenerProfileMuted,
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
                      foregroundColor: listenerProfileMuted,
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

class _TableInformation extends StatelessWidget {
  const _TableInformation({
    required this.table,
    required this.venue,
    required this.instant,
    required this.awaitingFinalSnapshot,
    required this.endedLabel,
    required this.openAction,
  });

  final TableGroupProfileShareSource table;
  final String venue;
  final DateTime instant;
  final bool awaitingFinalSnapshot;
  final String? endedLabel;
  final Widget? openAction;

  @override
  Widget build(BuildContext context) {
    final meeting = formatTableGroupMeetingAt(table.meetingAt, now: instant);
    final separator = meeting.lastIndexOf(' ');
    final venueField = _TableInformationField(
      icon: Icons.storefront_outlined,
      value: venue,
      semanticLabel: 'Mekân, $venue',
    );
    final timeField = _TableInformationField(
      icon: Icons.access_time_rounded,
      label: separator < 0
          ? 'BULUŞMA'
          : meeting.substring(0, separator).toUpperCase(),
      value: separator < 0 ? meeting : meeting.substring(separator + 1),
      semanticLabel: table.meetingAt == null
          ? 'Buluşma saati belirtilmemiş'
          : 'Buluşma, $meeting',
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF151D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: listenerProfileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
                // Preserve readable metadata at narrow widths and large text.
                // The actual inset width matters more than the device width.
                if (constraints.maxWidth < 224 * scale) {
                  return Column(
                    children: [
                      venueField,
                      const SizedBox(height: 16),
                      timeField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: venueField),
                    const SizedBox(
                      height: 28,
                      child: VerticalDivider(
                        color: listenerProfileBorder,
                        width: 1,
                        thickness: 1,
                      ),
                    ),
                    Expanded(child: timeField),
                  ],
                );
              },
            ),
          ),
          const Divider(color: listenerProfileBorder, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 44,
                      maxWidth: constraints.maxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: awaitingFinalSnapshot
                          ? const Text(
                              'Katılımcı bilgisi güncelleniyor…',
                              style: TextStyle(
                                color: listenerProfileMuted,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            )
                          : _TableCapacity(table: table),
                    ),
                  ),
                  if (openAction != null) openAction!,
                ],
              ),
            ),
          ),
          if (endedLabel != null) ...[
            const Divider(color: listenerProfileBorder, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _TableDetail(
                icon: table.status == 'CANCELLED'
                    ? Icons.event_busy_outlined
                    : Icons.history_rounded,
                text: endedLabel!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TableInformationField extends StatelessWidget {
  const _TableInformationField({
    required this.icon,
    this.label,
    required this.value,
    required this.semanticLabel,
  });
  final IconData icon;
  final String? label;
  final String value;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            BrandGradientIcon(icon, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null) ...[
                    Text(
                      label!,
                      style: const TextStyle(
                        color: listenerProfileMuted,
                        fontSize: 11,
                        letterSpacing: .3,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    value,
                    style: const TextStyle(
                      color: listenerProfileMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TableCapacity extends StatelessWidget {
  const _TableCapacity({required this.table});
  final TableGroupProfileShareSource table;

  @override
  Widget build(BuildContext context) {
    final count = '${table.acceptedCount}/${table.maxPersonCount} kişi';
    // Glyphs are decorative; the numeric label remains the authoritative count.
    final seats = table.maxPersonCount.clamp(0, 6);
    return Semantics(
      label: count,
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < seats; index++) ...[
                  Icon(
                    index < table.acceptedCount
                        ? Icons.person_rounded
                        : Icons.person_outline_rounded,
                    size: 16,
                    color: index < table.acceptedCount
                        ? TableGroupOverviewStyle.brandGradient[1]
                        : const Color(0xFF8252A8),
                  ),
                  if (index + 1 < seats) const SizedBox(width: 3),
                ],
              ],
            ),
            Text(
              count,
              style: const TextStyle(
                color: listenerProfileMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableDetail extends StatelessWidget {
  const _TableDetail({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(
        child: Icon(icon, size: 16, color: listenerProfileMuted),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: listenerProfileMuted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    ],
  );
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
  Widget build(BuildContext context) => Semantics(
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
              style: const TextStyle(color: listenerProfileMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}
