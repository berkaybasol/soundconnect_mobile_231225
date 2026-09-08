import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../../dm/domain/dm_user_profile_resolver.dart';
import '../../../dm/domain/entities/dm_profile_target.dart';
import '../../../dm/presentation/dm_profile_navigation.dart';
import '../../domain/entities/comment_item.dart';

String commentAuthorLabel(CommentItem comment) {
  if (comment.deleted) return 'Silinen yorum';
  if (comment.anonymousAuthor) return 'Kimliğini açıklamak istemeyen yazar';
  final name = comment.user.username.trim();
  return name.isEmpty ? 'Kullanıcı' : '@$name';
}

bool _identifiable(CommentItem comment) =>
    !comment.deleted &&
    !comment.anonymousAuthor &&
    comment.user.id.trim().isNotEmpty;

class CommentAuthorAvatar extends StatelessWidget {
  const CommentAuthorAvatar({
    super.key,
    required this.comment,
    this.size = 36,
    this.onTap,
  });
  final CommentItem comment;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visible = _identifiable(comment);
    final url = visible ? comment.user.avatarUrl?.trim() ?? '' : '';
    final name = visible ? comment.user.username.trim() : '';
    final placeholder = Center(
      child: name.isEmpty
          ? Icon(
              comment.anonymousAuthor ? Icons.person_outline : Icons.person,
              size: size * .5,
            )
          : Text(
              name.characters.first.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
    );
    return Semantics(
      label: commentAuthorLabel(comment),
      button: visible && onTap != null,
      child: InkWell(
        onTap: visible ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: AppColors.brandGradient),
          ),
          child: ClipOval(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: url.isEmpty
                  ? placeholder
                  : AppCachedNetworkImage(
                      imageUrl: url,
                      width: size - 2,
                      height: size - 2,
                      cacheWidth: (size * 3).round(),
                      cacheHeight: (size * 3).round(),
                      fit: BoxFit.cover,
                      errorBuilder: (_) => placeholder,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class CommentAuthorLabel extends StatelessWidget {
  const CommentAuthorLabel({super.key, required this.comment, this.onTap});
  final CommentItem comment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: _identifiable(comment) ? onTap : null,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              commentAuthorLabel(comment),
              maxLines: comment.anonymousAuthor ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          if (!comment.deleted && comment.isVisibleGhostAuthor) ...[
            const SizedBox(width: 6),
            const Flexible(child: GhostProfileBadge()),
          ],
        ],
      ),
    ),
  );
}

// Weak route keys prevent double pushes without retaining routes or identities.
final Expando<bool> _openingAuthor = Expando<bool>();

Future<void> openCommentAuthorProfile(
  BuildContext context,
  CommentItem comment, {
  AuthSessionManager? sessions,
  DmUserProfileResolver? resolver,
  bool Function()? isCurrent,
}) async {
  if (!_identifiable(comment) || !context.mounted) return;
  if (isCurrent?.call() == false) return;
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent || _openingAuthor[route] == true) {
    return;
  }
  final manager =
      sessions ??
      (serviceLocator.isRegistered<AuthSessionManager>()
          ? serviceLocator<AuthSessionManager>()
          : null);
  final expected = manager?.session;
  if (expected?.isAuthenticated != true || expected?.isActive != true) return;
  bool current() =>
      context.mounted &&
      route.isCurrent &&
      identical(manager?.session, expected) &&
      (isCurrent?.call() ?? true);
  _openingAuthor[route] = true;
  try {
    final own = comment.user.id.trim() == expected!.userId?.trim();
    // An author is a user, never a band. Only actual profile IDs from the
    // canonical resolver may be used for another user's destination.
    if (own) {
      final types = <DmProfileTargetType>[
        if (expected.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']))
          DmProfileTargetType.listener,
        if (expected.hasAnyRole(const ['MUSICIAN', 'ROLE_MUSICIAN']))
          DmProfileTargetType.musician,
        if (expected.hasAnyRole(const ['VENUE', 'ROLE_VENUE']))
          DmProfileTargetType.venue,
        if (expected.hasAnyRole(const ['STUDIO', 'ROLE_STUDIO']))
          DmProfileTargetType.studio,
      ];
      if (types.length == 1 && current()) {
        await Navigator.of(
          context,
        ).pushNamed(ownerProfileRouteFor(types.single));
        return;
      }
    }
    final actualResolver = resolver ?? serviceLocator<DmUserProfileResolver>();
    final targets = await actualResolver.resolveByUserId(
      userId: comment.user.id.trim(),
    );
    if (!current() || !context.mounted) return;
    if (targets.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.info,
          content: const Text('Profil şu anda açılamıyor.'),
        ),
      );
      return;
    }
    final target = targets.single;
    final destination = dmProfileRouteFor(target);
    if (destination == null) return;
    await Navigator.of(context).pushNamed(
      own ? ownerProfileRouteFor(target.type) : destination.routeName,
      arguments: own ? null : destination.arguments,
    );
  } catch (_) {
    if (current() && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: const Text('Profil açılamadı. Yeniden deneyebilirsin.'),
        ),
      );
    }
  } finally {
    _openingAuthor[route] = false;
  }
}
