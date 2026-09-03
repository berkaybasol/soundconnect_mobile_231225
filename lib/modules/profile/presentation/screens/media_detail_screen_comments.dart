part of 'media_detail_screen.dart';

class _CommentBubble extends StatelessWidget {
  final CommentItem comment;
  final String timeLabel;
  final VoidCallback onReply;

  _CommentBubble({
    required this.comment,
    required this.timeLabel,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = comment.user.avatarUrl?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            child: ClipOval(
              child: hasAvatar
                  ? AppCachedNetworkImage(
                      imageUrl: avatarUrl,
                      width: 36,
                      height: 36,
                      cacheWidth: 108,
                      cacheHeight: 108,
                      errorBuilder: (context) => Icon(
                        Icons.person,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    Flexible(
                      child: Text(
                        '@${comment.user.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (comment.isVisibleGhostAuthor) ...[
                      const SizedBox(width: 7),
                      const GhostProfileBadge(),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  comment.text,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      timeLabel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    SizedBox(width: 12),
                    InkWell(
                      onTap: onReply,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          'Yanitla',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyTo;
  final bool submitting;
  final VoidCallback onSend;
  final VoidCallback onClearReply;

  _CommentInput({
    required this.controller,
    required this.focusNode,
    required this.replyTo,
    required this.submitting,
    required this.onSend,
    required this.onClearReply,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (replyTo != null)
          Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Yanitlaniyor $replyTo',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClearReply,
                  icon: Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.sentiment_satisfied_alt,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: replyTo == null
                        ? 'Yorum yaz...'
                        : 'Yanitla $replyTo',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: submitting ? null : onSend,
                icon: Icon(
                  Icons.send,
                  color: submitting
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : AppColors.coralAlt,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
