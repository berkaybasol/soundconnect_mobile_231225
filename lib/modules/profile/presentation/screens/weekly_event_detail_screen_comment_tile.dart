part of 'weekly_event_detail_screen.dart';

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.timeLabel,
    required this.replies,
    required this.replyTimeLabelBuilder,
    required this.onReplyTap,
    required this.onRepliesTap,
    required this.onToggleReplies,
    required this.repliesExpanded,
    required this.replyTotal,
    required this.onAuthorTap,
    required this.repliesLoading,
    required this.repliesError,
    required this.hasMoreReplies,
    required this.viewerId,
    required this.deletingCommentId,
    required this.actionsEnabled,
    required this.onDeleteTap,
    required this.likeButtonBuilder,
  });
  final CommentItem comment;
  final String timeLabel;
  final List<CommentItem> replies;
  final String Function(DateTime?) replyTimeLabelBuilder;
  final VoidCallback? onReplyTap;
  final VoidCallback onRepliesTap;
  final VoidCallback onToggleReplies;
  final bool repliesExpanded;
  final int replyTotal;
  final ValueChanged<CommentItem>? onAuthorTap;
  final ValueChanged<CommentItem> onDeleteTap;
  final String? viewerId, deletingCommentId;
  final bool actionsEnabled;
  final bool repliesLoading, repliesError, hasMoreReplies;
  final Widget Function(CommentItem item, bool compact) likeButtonBuilder;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('event-comment-card-${comment.id}'),
    padding: const EdgeInsets.all(.8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: const LinearGradient(
        colors: [Color(0xFF604366), Color(0xFF304663)],
      ),
    ),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(const Color(0x0C9D5BCE), AppColors.navBlue),
            AppColors.navBlue,
            Color.alphaBlend(const Color(0x0D6398D8), AppColors.navBlue),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _entry(context, comment, timeLabel, onReplyTap: onReplyTap),
          if (replyTotal > 0 ||
              repliesExpanded ||
              repliesLoading ||
              repliesError)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  expanded: repliesExpanded,
                  child: TextButton.icon(
                    key: ValueKey('event-replies-${comment.id}'),
                    onPressed: onToggleReplies,
                    style: _replyControlStyle(),
                    icon: BrandGradientIcon.social(
                      repliesExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                    ),
                    label: Text(
                      repliesExpanded
                          ? 'Yanıtları gizle'
                          : 'Yanıtları göster ($replyTotal)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          if (repliesExpanded) ...[
            for (final reply in replies)
              Container(
                key: ValueKey('event-reply-${reply.id}'),
                margin: const EdgeInsets.only(left: 21, bottom: 6),
                padding: const EdgeInsets.fromLTRB(14, 4, 0, 4),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: _replyEntry(reply),
              ),
            if (repliesLoading || hasMoreReplies || repliesError)
              Padding(
                padding: const EdgeInsets.only(left: 35, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: repliesLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : TextButton.icon(
                          key: ValueKey('event-replies-more-${comment.id}'),
                          onPressed: onRepliesTap,
                          style: _replyControlStyle(),
                          icon: BrandGradientIcon.social(
                            repliesError
                                ? Icons.refresh_rounded
                                : Icons.subdirectory_arrow_right_rounded,
                            size: 16,
                          ),
                          label: Text(
                            repliesError
                                ? 'Yanıtlar yüklenemedi · Tekrar dene'
                                : 'Daha fazla yanıt',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                ),
              ),
          ],
        ],
      ),
    ),
  );

  ButtonStyle _replyControlStyle() => TextButton.styleFrom(
    foregroundColor: AppColors.textMuted,
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.centerLeft,
  );

  Widget _replyEntry(CommentItem item) {
    final own =
        !item.deleted &&
        !item.anonymousAuthor &&
        viewerId != null &&
        item.user.id == viewerId;
    final deleting = deletingCommentId == item.id;
    final authorTap = actionsEnabled && onAuthorTap != null
        ? () => onAuthorTap!(item)
        : null;
    final time = replyTimeLabelBuilder(item.createdAt);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          // The decorative initial must fit its fixed-size avatar. The author
          // label beside it retains the user's full accessibility text scale.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1,
            child: CommentAuthorAvatar(
              comment: item,
              size: 28,
              onTap: authorTap,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CommentAuthorLabel(comment: item, onTap: authorTap),
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                item.deleted ? 'Bu yorum silindi.' : item.text,
                style: TextStyle(
                  color: item.deleted
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (!item.deleted) likeButtonBuilder(item, true),
        if (own) ...[
          const SizedBox(width: 4),
          IconButton(
            key: ValueKey('event-comment-delete-${item.id}'),
            tooltip: 'Yorumu sil',
            onPressed: actionsEnabled && !deleting
                ? () => onDeleteTap(item)
                : null,
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              maximumSize: const Size(44, 44),
              padding: const EdgeInsets.all(12),
              foregroundColor: AppColors.textMuted,
              backgroundColor: Colors.transparent,
              side: BorderSide.none,
            ),
            icon: deleting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 18),
          ),
        ],
      ],
    );
  }

  Widget _entry(
    BuildContext context,
    CommentItem item,
    String time, {
    bool isReply = false,
    VoidCallback? onReplyTap,
  }) {
    final own =
        !item.deleted &&
        !item.anonymousAuthor &&
        viewerId != null &&
        item.user.id == viewerId;
    final deleting = deletingCommentId == item.id;
    final canReply = !item.deleted && onReplyTap != null;
    final authorTap = actionsEnabled && onAuthorTap != null
        ? () => onAuthorTap!(item)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommentAuthorAvatar(
              comment: item,
              size: isReply ? 32 : 44,
              onTap: authorTap,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CommentAuthorLabel(comment: item, onTap: authorTap),
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
            if (own) ...[
              const SizedBox(width: 8),
              IconButton.outlined(
                key: ValueKey('event-comment-delete-${item.id}'),
                tooltip: 'Yorumu sil',
                onPressed: actionsEnabled && !deleting
                    ? () => onDeleteTap(item)
                    : null,
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  maximumSize: const Size(44, 44),
                  padding: const EdgeInsets.all(10),
                  foregroundColor: AppColors.textPrimary,
                  backgroundColor: AppColors.navBlueSoft.withValues(alpha: .5),
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: deleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          item.deleted ? 'Bu yorum silindi.' : item.text,
          style: TextStyle(
            color: item.deleted ? AppColors.textMuted : AppColors.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (!item.deleted) ...[
          const SizedBox(height: 8),
          Divider(height: .6, thickness: .6, color: AppColors.border),
          Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              likeButtonBuilder(item, false),
              if (canReply)
                TextButton.icon(
                  onPressed: actionsEnabled ? onReplyTap : null,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    foregroundColor: AppColors.brandGradient[2],
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const BrandGradientIcon.social(
                    Icons.reply_rounded,
                    size: 19,
                  ),
                  label: const Text('Yanıtla'),
                ),
            ],
          ),
        ] else
          const SizedBox(height: 14),
      ],
    );
  }
}
