part of 'weekly_event_detail_screen.dart';

class _CommentTile extends StatelessWidget {
  final CommentItem comment;
  final String timeLabel;
  final List<CommentItem> replies;
  final String Function(DateTime? createdAt) replyTimeLabelBuilder;
  final VoidCallback onReplyTap;

  _CommentTile({
    required this.comment,
    required this.timeLabel,
    required this.replies,
    required this.replyTimeLabelBuilder,
    required this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(colors: AppColors.brandGradient),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: (comment.user.avatarUrl?.trim().isNotEmpty ?? false)
                  ? Image.network(
                      comment.user.avatarUrl!.trim(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text(
                        comment.user.username.isNotEmpty
                            ? comment.user.username[0]
                            : '?',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : Text(
                      comment.user.username.isNotEmpty
                          ? comment.user.username[0]
                          : '?',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '@${comment.user.username}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Text(
                    comment.text,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      InkWell(
                        onTap: onReplyTap,
                        child: Text(
                          comment.replyCount > 0
                              ? 'Yanitla (${comment.replyCount})'
                              : 'Yanitla',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (replies.isNotEmpty) ...[
                    SizedBox(height: 10),
                    ...replies.map(
                      (reply) => Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      gradient: LinearGradient(
                                        colors: AppColors.brandGradient,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    alignment: Alignment.center,
                                    child:
                                        (reply.user.avatarUrl
                                                ?.trim()
                                                .isNotEmpty ??
                                            false)
                                        ? Image.network(
                                            reply.user.avatarUrl!.trim(),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Text(
                                              reply.user.username.isNotEmpty
                                                  ? reply.user.username[0]
                                                  : '?',
                                              style: TextStyle(
                                                color: AppColors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            reply.user.username.isNotEmpty
                                                ? reply.user.username[0]
                                                : '?',
                                            style: TextStyle(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                            ),
                                          ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '@${reply.user.username}',
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              replyTimeLabelBuilder(
                                                reply.createdAt,
                                              ),
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          reply.text,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
