import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../../overthinking/domain/entities/overthinking_post.dart';
import '../../../overthinking/domain/entities/overthinking_profile_share.dart';
import '../../../overthinking/domain/trusted_spotify_artwork.dart';
import '../../../overthinking/presentation/screens/overthinking_profile_link.dart';
import 'listener_profile_theme.dart';

const _sharePink = Color(0xFFF06C86);

class ListenerOverthinkingShareCard extends StatelessWidget {
  const ListenerOverthinkingShareCard({
    super.key,
    required this.share,
    required this.username,
    this.avatarUrl,
    required this.onOpen,
    this.onRemove,
    this.onShare,
    this.onLike,
    this.onComments,
    this.likeBusy = false,
    this.engagementUnknown = false,
    this.busy = false,
    this.isCurrent,
  }) : _draftPost = null,
       noteEditor = null,
       actions = null,
       visibilityLabel = null,
       maskAnonymousAuthor = false;

  const ListenerOverthinkingShareCard.draft({
    super.key,
    required OverthinkingPost post,
    required this.username,
    this.avatarUrl,
    this.noteEditor,
    this.actions,
    this.visibilityLabel = 'Taslak · Henüz paylaşılmadı',
    this.maskAnonymousAuthor = true,
    this.busy = false,
    this.isCurrent,
  }) : _draftPost = post,
       share = null,
       onOpen = null,
       onRemove = null,
       onShare = null,
       onLike = null,
       onComments = null,
       likeBusy = false,
       engagementUnknown = false;

  final OverthinkingProfileShare? share;
  final OverthinkingPost? _draftPost;
  final Widget? noteEditor;
  final Widget? actions;
  final String? visibilityLabel;
  final bool maskAnonymousAuthor;
  final String username;
  final String? avatarUrl;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;
  final VoidCallback? onShare;
  final VoidCallback? onLike;
  final VoidCallback? onComments;
  final bool likeBusy;
  final bool engagementUnknown;
  final bool busy;
  final bool Function()? isCurrent;

  @override
  Widget build(BuildContext context) {
    final source = share?.post ?? _draftPost!;
    final note = share?.note?.trim() ?? '';
    final anonymous =
        source.anonymous ||
        source.visibilityType.trim().toUpperCase() == 'ANONYMOUS';
    final authorVisible =
        source.hasVisibleAuthor && !(maskAnonymousAuthor && anonymous);
    final published = share?.publishedAt.toLocal();
    final subtitle = published == null
        ? visibilityLabel
        : 'Bir overthinking paylaştı · ${published.day}.${published.month}.${published.year}';
    final song = source.spotifyTrackName?.trim() ?? '';
    final artist = source.spotifyArtistName?.trim() ?? '';
    final hasMusic =
        song.isNotEmpty ||
        source.spotifyTrackUrl != null ||
        source.musicianTrackId != null ||
        source.bandTrackId != null;
    return Container(
      key: ValueKey(
        share == null
            ? 'listener-overthinking-draft-${source.id}'
            : 'listener-overthinking-share-${share!.shareId}',
      ),
      decoration: BoxDecoration(
        color: listenerProfileSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: listenerProfileBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _ShareAvatar(imageUrl: avatarUrl, label: username, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${username.replaceFirst(RegExp(r'^@+'), '')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    if (subtitle?.isNotEmpty == true) ...[
                      const SizedBox(height: 3),
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
              if (onRemove != null)
                PopupMenuButton<String>(
                  key: ValueKey(
                    'listener-overthinking-remove-${share!.shareId}',
                  ),
                  tooltip: 'Paylaşım seçenekleri',
                  enabled: !busy,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 180),
                  icon: const Icon(Icons.more_horiz_rounded, size: 19),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    maximumSize: const Size(48, 48),
                    foregroundColor: const Color(0xFFA0A9B6),
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
          Container(
            key: const Key('listener-overthinking-source-quote'),
            decoration: BoxDecoration(
              color: const Color(0xFF151D2D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: listenerProfileBorder),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OverthinkingProfileLink(
                  userId: authorVisible ? source.authorId : null,
                  enabled: share != null && authorVisible && !busy,
                  isCurrent: isCurrent,
                  child: Row(
                    children: [
                      _ShareAvatar(
                        imageUrl: authorVisible ? source.authorAvatarUrl : null,
                        label: authorVisible ? source.authorUsername : '',
                        size: 27,
                        anonymous: !authorVisible,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          authorVisible
                              ? '@${source.authorUsername}'
                              : 'Anonim yazar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: listenerProfileMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (authorVisible && source.isVisibleGhostAuthor) ...[
                        const SizedBox(width: 6),
                        const GhostProfileBadge(showLabel: false),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  source.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                _SourceExcerpt(
                  content: source.content,
                  openKey: share == null
                      ? null
                      : ValueKey(
                          'listener-overthinking-open-${share!.shareId}',
                        ),
                  showLink: share != null,
                  onOpen: busy ? null : onOpen,
                ),
                if (hasMusic) ...[
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: SizedBox.square(
                          dimension: 36,
                          child: AppCachedNetworkImage(
                            imageUrl: trustedSpotifyArtworkUrl(
                              source.spotifyAlbumImageUrl,
                            ),
                            width: 36,
                            height: 36,
                            cacheWidth: 108,
                            cacheHeight: 108,
                            errorBuilder: (_) => const ColoredBox(
                              color: Color(0xFF1B2433),
                              child: Icon(
                                Icons.music_note_rounded,
                                color: _sharePink,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.isEmpty
                                  ? 'Bu yazıya eşlik eden parça'
                                  : song,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            if (artist.isNotEmpty)
                              Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: listenerProfileMuted,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (share != null) ...[
            const SizedBox(height: 8),
            const Divider(color: listenerProfileBorder, height: 1),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _SourceAction(
                      key: ValueKey(
                        'listener-overthinking-like-${share!.shareId}',
                      ),
                      count: engagementUnknown ? null : share!.likeCount,
                      label: share!.likedByMe ? 'Beğeniyi kaldır' : 'Beğen',
                      countLabel: 'beğeni',
                      selected: !engagementUnknown && share!.likedByMe,
                      onPressed: busy || likeBusy ? null : onLike,
                      icon: share!.likedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: AppColors.likeHeart,
                    ),
                    _SourceAction(
                      key: ValueKey(
                        'listener-overthinking-comments-${share!.shareId}',
                      ),
                      count: engagementUnknown ? null : share!.commentCount,
                      label: 'Yorumlar',
                      countLabel: 'yorum',
                      onPressed: busy || likeBusy ? null : onComments,
                      icon: Icons.chat_bubble_outline_rounded,
                      color: listenerProfileMuted,
                    ),
                  ],
                ),
                if (onShare != null)
                  IconButton(
                    key: ValueKey(
                      'listener-overthinking-external-share-${share!.shareId}',
                    ),
                    tooltip: 'Paylaş',
                    onPressed: busy ? null : onShare,
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

class _SourceExcerpt extends StatelessWidget {
  const _SourceExcerpt({
    required this.content,
    required this.openKey,
    required this.showLink,
    required this.onOpen,
  });

  final String content;
  final Key? openKey;
  final bool showLink;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(
      const TextStyle(color: Color(0xFFD4D9E2), fontSize: 13, height: 1.65),
    );
    if (!showLink) {
      return Text(
        content,
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          content.trim(),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            link: true,
            child: TextButton(
              key: openKey,
              onPressed: onOpen,
              style: TextButton.styleFrom(
                foregroundColor: listenerProfileMuted,
                disabledForegroundColor: listenerProfileMuted,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(vertical: 3),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: style.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              child: const Text('Devamını gör…'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceAction extends StatelessWidget {
  const _SourceAction({
    super.key,
    required this.count,
    required this.icon,
    required this.color,
    required this.label,
    required this.countLabel,
    required this.onPressed,
    this.selected,
  });
  final int? count;
  final IconData icon;
  final Color color;
  final String label;
  final String countLabel;
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
      child: Tooltip(
        message: label,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 5),
              Text(
                count == null
                    ? '—'
                    : NumberFormat.compact(locale: 'tr').format(count),
                style: const TextStyle(
                  color: listenerProfileMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ShareAvatar extends StatelessWidget {
  const _ShareAvatar({
    required this.imageUrl,
    required this.label,
    required this.size,
    this.anonymous = false,
  });
  final String? imageUrl;
  final String label;
  final double size;
  final bool anonymous;
  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFF232A3B),
      child: Center(
        child: anonymous || label.trim().isEmpty
            ? Icon(
                anonymous
                    ? Icons.visibility_off_outlined
                    : Icons.person_outline_rounded,
                size: size * .5,
                color: listenerProfileMuted,
              )
            : Text(
                label.trim().characters.first.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * .35,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(.8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF684253), width: .7),
      ),
      child: ClipOval(
        child: anonymous || imageUrl?.trim().isNotEmpty != true
            ? fallback
            : AppCachedNetworkImage(
                imageUrl: imageUrl,
                width: size,
                height: size,
                cacheWidth: (size * 3).round(),
                cacheHeight: (size * 3).round(),
                errorBuilder: (_) => fallback,
              ),
      ),
    );
  }
}
