import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../domain/entities/comment_item.dart';
import 'comment_author_identity.dart';

/// Shared reference card / compact reply anatomy. Callers own permissions,
/// author routing and async work; supplied thread content is presentation.
class CommentEntry extends StatelessWidget {
  const CommentEntry({
    super.key,
    required this.comment,
    required this.timeLabel,
    this.onAuthorTap,
    this.onReplyTap,
    this.onDeleteTap,
    this.isReply = false,
    this.deleting = false,
    this.actionsEnabled = true,
    this.useThemeColors = false,
    this.deleteKey,
    this.likeButton,
    this.threadFooter,
  });

  final CommentItem comment;
  final String timeLabel;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onReplyTap;
  final VoidCallback? onDeleteTap;
  final bool isReply;
  final bool deleting;
  final bool actionsEnabled;
  final bool useThemeColors;
  final Key? deleteKey;
  final Widget? likeButton;
  final Widget? threadFooter;

  bool get _showReply => !comment.deleted && onReplyTap != null;
  bool get _showDelete =>
      !comment.deleted && !comment.anonymousAuthor && onDeleteTap != null;
  VoidCallback? get _authorTap => actionsEnabled ? onAuthorTap : null;

  bool _usesThemeColors(BuildContext context) =>
      useThemeColors && Theme.of(context).brightness == Brightness.dark;

  Color _textPrimary(BuildContext context) => _usesThemeColors(context)
      ? Theme.of(context).colorScheme.onSurface
      : AppColors.textPrimary;

  Color _textMuted(BuildContext context) => _usesThemeColors(context)
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : AppColors.textMuted;

  Color _border(BuildContext context) => _usesThemeColors(context)
      ? Theme.of(context).colorScheme.outline
      : AppColors.border;

  Color _surface(BuildContext context) => _usesThemeColors(context)
      ? Theme.of(context).colorScheme.surfaceContainer
      : AppColors.navBlue;

  Color _raisedSurface(BuildContext context) => _usesThemeColors(context)
      ? Theme.of(context).colorScheme.surfaceContainerHigh
      : AppColors.navBlueSoft;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return isReply ? _reply(context) : _root(context);
  }

  Widget _root(BuildContext context) => Container(
    padding: const EdgeInsets.all(.8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        colors: AppColors.isLight
            ? AppColors.decorativeGradient
            : const [Color(0xFF604366), Color(0xFF304663)],
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
            Color.alphaBlend(const Color(0x0C9D5BCE), _surface(context)),
            _surface(context),
            Color.alphaBlend(const Color(0x0D6398D8), _surface(context)),
          ],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommentAuthorAvatar(
                  comment: comment,
                  size: 44,
                  onTap: _authorTap,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CommentAuthorLabel(comment: comment, onTap: _authorTap),
                      if (timeLabel.isNotEmpty) _age(context, 12, 1.3),
                    ],
                  ),
                ),
                if (_showDelete) ...[
                  const SizedBox(width: 8),
                  _deleteButton(context),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _body(context, 14, 1.4),
            if (_showReply || (!comment.deleted && likeButton != null)) ...[
              const SizedBox(height: 8),
              Divider(height: .6, thickness: .6, color: _border(context)),
              _actions(context),
            ] else
              const SizedBox(height: 14),
            if (threadFooter != null) threadFooter!,
          ],
        ),
      ),
    ),
  );

  Widget _reply(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1,
            child: CommentAuthorAvatar(
              comment: comment,
              size: 28,
              onTap: _authorTap,
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
                  CommentAuthorLabel(comment: comment, onTap: _authorTap),
                  if (timeLabel.isNotEmpty) _age(context, 11, 1.2),
                ],
              ),
              const SizedBox(height: 2),
              _body(context, 13, 1.35),
              if (_showReply || (!comment.deleted && likeButton != null))
                _actions(context),
            ],
          ),
        ),
        if (_showDelete) ...[const SizedBox(width: 4), _deleteButton(context)],
      ],
    ),
  );

  Widget _age(BuildContext context, double size, double height) => Text(
    timeLabel,
    style: TextStyle(
      color: _textMuted(context),
      fontSize: size,
      height: height,
    ),
  );

  Widget _body(BuildContext context, double size, double height) => Text(
    comment.deleted ? 'Bu yorum silindi.' : comment.text,
    style: TextStyle(
      color: comment.deleted ? _textMuted(context) : _textPrimary(context),
      fontSize: size,
      height: height,
    ),
  );

  Widget _actions(BuildContext context) => Wrap(
    spacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (!comment.deleted && likeButton != null) likeButton!,
      if (_showReply)
        TextButton.icon(
          onPressed: actionsEnabled && !deleting ? onReplyTap : null,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            foregroundColor: AppColors.isLight
                ? AppColors.accentText
                : AppColors.brandGradient[2],
            backgroundColor: Colors.transparent,
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: isReply ? 12 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          icon: BrandGradientIcon.social(
            Icons.reply_rounded,
            size: isReply ? 16 : 19,
          ),
          label: const Text('Yanıtla'),
        ),
    ],
  );

  Widget _deleteButton(BuildContext context) {
    final style = IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      maximumSize: const Size(44, 44),
      padding: EdgeInsets.all(isReply ? 12 : 10),
      foregroundColor: isReply ? _textMuted(context) : _textPrimary(context),
      backgroundColor: isReply
          ? Colors.transparent
          : _raisedSurface(context).withValues(alpha: .5),
      side: isReply ? BorderSide.none : BorderSide(color: _border(context)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    final icon = deleting
        ? SizedBox.square(
            dimension: isReply ? 16 : 18,
            child: const CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(Icons.delete_outline_rounded, size: isReply ? 18 : 20);
    return isReply
        ? IconButton(
            key: deleteKey,
            tooltip: 'Yorumu sil',
            style: style,
            onPressed: actionsEnabled && !deleting ? onDeleteTap : null,
            icon: icon,
          )
        : IconButton.outlined(
            key: deleteKey,
            tooltip: 'Yorumu sil',
            style: style,
            onPressed: actionsEnabled && !deleting ? onDeleteTap : null,
            icon: icon,
          );
  }
}
