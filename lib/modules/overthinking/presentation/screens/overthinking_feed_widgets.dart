part of 'overthinking_feed_screen.dart';

class _FeedHeading extends StatelessWidget {
  const _FeedHeading({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Geri',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 28,
                color: TableGroupOverviewStyle.bodyMuted,
              ),
            ),
            const Spacer(),
            IconButton(
              key: const ValueKey('overthinking-create'),
              tooltip: 'Yeni yazı',
              onPressed: onCreate,
              icon: const OverthinkingBrandIcon(Icons.edit_square, size: 27),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Text(
            'Overthinking',
            key: ValueKey('overthinking-hero-title'),
            style: TextStyle(
              color: TableGroupOverviewStyle.warmHeading,
              fontSize: 34,
              height: 1.02,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Text(
            'Birbirimizi tanımıyoruz. Ama bu hissi biliyoruz.',
            style: TextStyle(
              color: TableGroupOverviewStyle.bodyMuted,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _FeedShortcuts extends StatelessWidget {
  const _FeedShortcuts({
    required this.onMine,
    required this.onIncoming,
    required this.onSent,
    required this.hasUnread,
  });
  final VoidCallback onMine;
  final VoidCallback onIncoming;
  final VoidCallback onSent;
  final bool? hasUnread;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        _Shortcut(
          icon: Icons.edit_note_rounded,
          label: 'Yazılarım',
          onTap: onMine,
        ),
        const SizedBox(width: 8),
        _Shortcut(
          icon: Icons.inbox_outlined,
          label: 'Gelen istekler',
          iconWidget: OverthinkingIncomingRequestIcon(hasUnread: hasUnread),
          onTap: onIncoming,
        ),
        const SizedBox(width: 8),
        _Shortcut(
          icon: Icons.north_east_rounded,
          label: 'Gönderilenler',
          onTap: onSent,
        ),
      ],
    ),
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconWidget,
  });
  final IconData icon;
  final Widget? iconWidget;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      backgroundColor: TableGroupOverviewStyle.insetTop,
      foregroundColor: TableGroupOverviewStyle.headingMuted,
      side: const BorderSide(color: TableGroupOverviewStyle.insetBorder),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    icon: iconWidget ?? Icon(icon, size: 17),
    label: Text(label),
  );
}

class _FeedSection extends StatelessWidget {
  const _FeedSection({required this.sort, required this.onSortChanged});
  final OverthinkingFeedSort sort;
  final ValueChanged<OverthinkingFeedSort> onSortChanged;

  static String _label(OverthinkingFeedSort sort) => switch (sort) {
    OverthinkingFeedSort.newest => 'En yeni',
    OverthinkingFeedSort.mostLiked => 'En çok beğenilenler',
    OverthinkingFeedSort.oldest => 'En eski',
  };
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Yazılar',
            style: TextStyle(
              color: TableGroupOverviewStyle.headingMuted,
              fontSize: 23,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<OverthinkingFeedSort>(
          key: const ValueKey('overthinking-sort'),
          tooltip: 'Yazıları sırala: ${_label(sort)}',
          initialValue: sort,
          onSelected: onSortChanged,
          color: TableGroupOverviewStyle.cardTop,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: TableGroupOverviewStyle.cardBorder),
          ),
          itemBuilder: (context) => [
            for (final option in OverthinkingFeedSort.values)
              CheckedPopupMenuItem(
                value: option,
                checked: option == sort,
                child: Text(_label(option)),
              ),
          ],
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: TableGroupOverviewStyle.cardTop,
              shape: BoxShape.circle,
              border: Border.all(color: TableGroupOverviewStyle.cardBorder),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 21,
              color: sort == OverthinkingFeedSort.newest
                  ? TableGroupOverviewStyle.headingMuted
                  : OverthinkingPalette.accent,
            ),
          ),
        ),
      ],
    ),
  );
}

class OverthinkingPostCard extends StatelessWidget {
  const OverthinkingPostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLike,
    required this.onComments,
    this.onDelete,
    this.busy = false,
    this.isOwnPost = false,
  });
  final OverthinkingPost post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback? onDelete;
  final bool busy;
  final bool isOwnPost;

  @override
  Widget build(BuildContext context) => OverthinkingSurface(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: busy ? null : onTap,
          splashColor: AppColors.gradientC.withValues(alpha: .1),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _AuthorLine(post: post, isOwnPost: isOwnPost),
                    ),
                    const SizedBox(width: 8),
                    if (onDelete != null)
                      IconButton(
                        key: ValueKey('overthinking-delete-${post.id}'),
                        tooltip: 'Yazıyı sil',
                        onPressed: busy ? null : onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 23,
                          color: TableGroupOverviewStyle.bodyMuted,
                        ),
                      )
                    else
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 23,
                        color: TableGroupOverviewStyle.bodyMuted,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TableGroupOverviewStyle.primaryText,
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  post.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TableGroupOverviewStyle.bodyMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Devamını oku',
                        style: TextStyle(
                          color: TableGroupOverviewStyle.headingMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: TableGroupOverviewStyle.headingMuted,
                      size: 17,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_hasMusic(post))
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 9),
            child: _MusicChip(key: ValueKey('music-${post.id}'), post: post),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(9, 0, 9, 9),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            gradient: TableGroupOverviewStyle.insetGradient,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: TableGroupOverviewStyle.insetBorder),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            children: [
              _PostAction(
                icon: post.likedByMe
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '${post.likeCount} beğeni',
                tooltip: post.likedByMe ? 'Beğeniyi kaldır' : 'Beğen',
                active: post.likedByMe,
                onTap: busy ? null : onLike,
              ),
              _PostAction(
                icon: Icons.chat_bubble_outline_rounded,
                label: '${post.commentCount} yorum',
                tooltip: 'Yorumları aç',
                onTap: busy ? null : onComments,
              ),
              OverthinkingProfileShareButton(post: post, enabled: !busy),
            ],
          ),
        ),
      ],
    ),
  );
}

bool _hasMusic(OverthinkingPost post) =>
    (post.spotifyTrackUrl?.trim().isNotEmpty ?? false) ||
    post.musicianTrackId != null ||
    post.bandTrackId != null;

class _AuthorLine extends StatelessWidget {
  const _AuthorLine({required this.post, this.isOwnPost = false});
  final OverthinkingPost post;
  final bool isOwnPost;
  @override
  Widget build(BuildContext context) {
    final hidden = !post.hasVisibleAuthor;
    final session = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>().session
        : null;
    final own =
        isOwnPost ||
        (session?.isAuthenticated == true &&
            post.authorId != null &&
            post.authorId == session?.userId);
    final visibilityLabel = post.anonymous
        ? own
              ? 'Anonim olarak paylaştın'
              : hidden
              ? 'Kimliği gizli'
              : 'Kimliği sana açık'
        : 'Profilinden paylaştı';
    final minutes = (post.content.trim().split(RegExp(r'\s+')).length / 200)
        .ceil()
        .clamp(1, 99);
    return OverthinkingProfileLink(
      userId: post.hasVisibleAuthor ? post.authorId : null,
      enabled: post.hasVisibleAuthor,
      semanticsLabel: hidden ? null : '${post.authorUsername} profilini aç',
      child: Row(
        children: [
          _AuthorAvatar(
            key: ValueKey('overthinking-author-avatar-${post.id}'),
            post: post,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hidden ? 'Anonim' : '@${post.authorUsername}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TableGroupOverviewStyle.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$visibilityLabel · $minutes dk okuma',
                  style: const TextStyle(
                    color: TableGroupOverviewStyle.tertiaryText,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (post.isVisibleGhostAuthor) ...[
            const SizedBox(width: 5),
            const GhostProfileBadge(showLabel: false),
          ],
        ],
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({super.key, required this.post});
  final OverthinkingPost post;
  @override
  Widget build(BuildContext context) {
    final visible = post.hasVisibleAuthor;
    final imageUrl = visible ? post.authorAvatarUrl?.trim() : null;
    final fallback = Icon(
      visible ? Icons.person_outline_rounded : Icons.visibility_off_outlined,
      color: TableGroupOverviewStyle.headingMuted,
      size: 22,
    );
    return Container(
      width: 46,
      height: 46,
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: TableGroupOverviewStyle.brandGradient,
        ),
      ),
      child: ClipOval(
        child: ColoredBox(
          color: TableGroupOverviewStyle.insetBottom,
          child: imageUrl?.isNotEmpty == true
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: active
            ? AppColors.coral
            : TableGroupOverviewStyle.bodyMuted,
        minimumSize: const Size(48, 44),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      icon: Icon(icon, size: 19),
      label: Text(label),
    ),
  );
}

class _FeedLoadingState extends StatelessWidget {
  const _FeedLoadingState();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Yazılar yükleniyor',
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: List.generate(
          2,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OverthinkingSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 130,
                    height: 14,
                    color: TableGroupOverviewStyle.cardBorder,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 16,
                    color: TableGroupOverviewStyle.cardBorder,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 10,
                    color: TableGroupOverviewStyle.insetBorder,
                  ),
                  const SizedBox(height: 18),
                  const LinearProgressIndicator(minHeight: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
