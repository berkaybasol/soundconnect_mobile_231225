part of 'overthinking_manage_screen.dart';

class _PostPreviewSheet extends StatelessWidget {
  final OverthinkingPost post;
  const _PostPreviewSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    final hasMusic =
        (post.spotifyTrackName?.trim().isNotEmpty ?? false) ||
        (post.spotifyTrackUrl?.trim().isNotEmpty ?? false) ||
        (post.musicianTrackId?.trim().isNotEmpty ?? false) ||
        (post.bandTrackId?.trim().isNotEmpty ?? false);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('manage-post-preview-scroll'),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text('Yazı önizlemesi', style: _manageEyebrow),
                  ),
                  IconButton(
                    tooltip: 'Önizlemeyi kapat',
                    onPressed: () => Navigator.of(context).pop(),
                    color: OverthinkingPalette.muted,
                    icon: const Icon(Icons.close_rounded, size: 21),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: _VisibilityPill(post: post),
              ),
              const SizedBox(height: 20),
              _PreviewAuthorLine(post: post),
              const SizedBox(height: 20),
              Text(
                post.title,
                style: _manageHeading.copyWith(fontSize: 27, height: 1.2),
              ),
              if (hasMusic) ...[
                const SizedBox(height: 22),
                _ManageMusicStrip(post: post),
              ],
              const SizedBox(height: 24),
              SelectableText(
                post.content,
                style: const TextStyle(
                  color: OverthinkingPalette.text,
                  fontSize: 16,
                  height: 1.85,
                ),
              ),
              const SizedBox(height: 26),
              const Divider(color: OverthinkingPalette.border),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                children: [
                  _ManageMetric(
                    icon: Icons.favorite_border_rounded,
                    iconColor: AppColors.likeHeart,
                    value: post.likeCount,
                    label: 'beğeni',
                  ),
                  _ManageMetric(
                    icon: Icons.chat_bubble_outline_rounded,
                    value: post.commentCount,
                    label: 'yorum',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewAuthorLine extends StatelessWidget {
  const _PreviewAuthorLine({required this.post});
  final OverthinkingPost post;

  @override
  Widget build(BuildContext context) {
    final visible = post.hasVisibleAuthor;
    final imageUrl = visible ? post.authorAvatarUrl?.trim() : null;
    final fallback = Icon(
      visible ? Icons.person_outline_rounded : Icons.visibility_off_outlined,
      color: OverthinkingPalette.lilac,
      size: 22,
    );
    return OverthinkingProfileLink(
      userId: visible ? post.authorId : null,
      enabled: visible,
      semanticsLabel: 'Yazarın profilini görüntüle',
      child: Row(
        children: [
          Container(
            key: const ValueKey('preview-author-avatar'),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: OverthinkingPalette.lilac.withValues(alpha: .13),
              border: Border.all(
                color: OverthinkingPalette.lilac.withValues(alpha: .2),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl == null || imageUrl.isEmpty
                ? fallback
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback,
                  ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              visible ? '@${post.authorUsername}' : 'Anonim',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: OverthinkingPalette.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (post.isVisibleGhostAuthor) ...[
            const SizedBox(width: 7),
            const GhostProfileBadge(),
          ],
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 34,
      height: 4,
      decoration: BoxDecoration(
        color: OverthinkingPalette.muted.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );
}
