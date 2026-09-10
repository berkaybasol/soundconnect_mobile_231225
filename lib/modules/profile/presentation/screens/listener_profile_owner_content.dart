import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/entities/listener_profile.dart';
import '../../../spotify/domain/entities/spotify_playlist_preview.dart';
import 'listener_playlist_section.dart';
import 'listener_profile_header.dart';
import 'listener_profile_preview_data.dart';
import 'listener_profile_theme.dart';
import 'profile_screen_support.dart';

const _listenerDeepSurface = Color(0xFF070B13);
const _listenerSurface = Color(0xFF101722);
const _listenerBorder = Color(0xFF202B3A);
const _listenerDivider = Color(0xFF151D29);
const _listenerMuted = Color(0xFFA0A9B6);

class ListenerProfileOwnerContent extends StatelessWidget {
  const ListenerProfileOwnerContent({
    super.key,
    required this.profile,
    required this.onEditProfile,
    required this.onEditAvatar,
    required this.onEditPlaylists,
    required this.onPlaylistTap,
    required this.onPreviewAction,
    this.previewData,
    this.showPreviewSections = false,
    this.actionBusy = false,
    this.posts,
    this.postsAreSlivers = false,
    this.eventPosts,
    this.overthinkingPosts,
    this.eventPlansAction,
    this.scrollController,
  });

  final ListenerProfile profile;
  final VoidCallback onEditProfile;
  final VoidCallback onEditAvatar;
  final VoidCallback onEditPlaylists;
  final ValueChanged<SpotifyPlaylistPreview> onPlaylistTap;
  final ValueChanged<String> onPreviewAction;
  final ListenerProfilePreviewData? previewData;
  final bool showPreviewSections;
  final bool actionBusy;
  final Widget? posts;
  final bool postsAreSlivers;
  final Widget? eventPosts;
  final Widget? overthinkingPosts;
  final Widget? eventPlansAction;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    assert(
      !profile.isGhost && profile.profileContentVisible,
      'Standard owner content cannot render a restricted listener profile.',
    );
    if (profile.isGhost || !profile.profileContentVisible) {
      return const SizedBox.shrink();
    }

    final normalizedUsername = profile.username?.trim() ?? '';
    assert(
      normalizedUsername.isNotEmpty,
      'Owner listener identity requires an authoritative username.',
    );
    final username = normalizedUsername.isEmpty ? '—' : normalizedUsername;
    final bio = profile.bio?.trim() ?? '';
    final followerCount = profile.followerCount;
    final followingCount = profile.followingCount;
    final preview = previewData;

    final content = <Widget>[
      ListenerProfileHeader(
        username: username,
        imageUrl: profile.profilePictureUrl,
        followerCount: followerCount,
        followingCount: followingCount,
        editableAvatar: true,
        avatarBusy: actionBusy,
        onEditAvatar: onEditAvatar,
        actionButtons: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Center(
            child: GradientOutlineButton(
              key: const Key('listener-edit-profile'),
              label: 'Profili Düzenle',
              onPressed: actionBusy ? null : onEditProfile,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              leading: const Icon(Icons.edit_outlined, size: 16),
              horizontalPadding: 24,
              maxLines: 2,
            ),
          ),
        ),
        bio: bio,
        afterBio: eventPlansAction == null
            ? null
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: eventPlansAction!,
              ),
      ),
      const SizedBox(height: 20),
      ListenerPlaylistSection(
        playlists: profile.playlists,
        onPlaylistTap: onPlaylistTap,
        onEdit: actionBusy ? null : onEditPlaylists,
        showWhenEmpty: true,
      ),
      if (posts != null ||
          eventPosts != null ||
          overthinkingPosts != null ||
          (showPreviewSections && preview != null)) ...[
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: ColoredBox(
            color: _listenerDivider,
            child: SizedBox(height: 1),
          ),
        ),
        const SizedBox(height: 20),
        const _ListenerSectionHeader(title: 'Paylaşımlar'),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListenerProfileTheme(
            child: Column(
              children: [
                if (posts != null && !postsAreSlivers) posts!,
                if (eventPosts != null) eventPosts!,
                if (overthinkingPosts != null) overthinkingPosts!,
                if (showPreviewSections && preview != null)
                  _ListenerOverthinkingPostCard(
                    username: username,
                    imageUrl: profile.profilePictureUrl,
                    post: preview.overthinkingShare,
                    onAction: onPreviewAction,
                  ),
              ],
            ),
          ),
        ),
      ],
    ];
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: postsAreSlivers
          ? CustomScrollView(
              controller: scrollController,
              key: const Key('listener-owner-profile-content'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverList.list(children: content),
                if (posts != null)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: ListenerProfileTheme(child: posts!),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            )
          : ListView(
              controller: scrollController,
              key: const Key('listener-owner-profile-content'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 28),
              children: content,
            ),
    );
  }
}

String _initials(String username) {
  final parts = username
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty || username.trim() == '—') return '?';
  if (parts.length > 1) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  final first = parts.first[0].toUpperCase();
  return '$first$first';
}

class _ListenerSectionHeader extends StatelessWidget {
  const _ListenerSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _ListenerPostHeader extends StatelessWidget {
  const _ListenerPostHeader({
    required this.username,
    required this.imageUrl,
    required this.meta,
  });

  final String username;
  final String? imageUrl;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl?.trim();
    final hasImage = isValidNetworkImageUrl(normalizedUrl);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(1.4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: AppColors.brandGradient),
          ),
          child: ClipOval(
            child: hasImage
                ? AppCachedNetworkImage(
                    imageUrl: normalizedUrl,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    cacheWidth: (34 * pixelRatio).round(),
                    errorBuilder: (_) => _ListenerPostAvatarFallback(
                      initials: _initials(username),
                    ),
                  )
                : _ListenerPostAvatarFallback(initials: _initials(username)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _listenerMuted, fontSize: 10),
              ),
            ],
          ),
        ),
        const Icon(Icons.more_horiz, color: _listenerMuted, size: 20),
      ],
    );
  }
}

class _ListenerPostAvatarFallback extends StatelessWidget {
  const _ListenerPostAvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF312A49), Color(0xFF17243A)],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ListenerPostShell extends StatelessWidget {
  const _ListenerPostShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _listenerSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _listenerBorder),
      ),
      child: Padding(padding: const EdgeInsets.all(15), child: child),
    );
  }
}

class _ListenerOverthinkingPostCard extends StatelessWidget {
  const _ListenerOverthinkingPostCard({
    required this.username,
    required this.imageUrl,
    required this.post,
    required this.onAction,
  });

  final String username;
  final String? imageUrl;
  final ListenerOverthinkingSharePreview post;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return _ListenerPostShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ListenerPostHeader(
            username: username,
            imageUrl: imageUrl,
            meta: post.meta,
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: _listenerDeepSurface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _listenerBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF291D35), Color(0xFF151B28)],
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.78, -0.70),
                        radius: 1.05,
                        colors: [Color(0x508B2CFF), Color(0x008B2CFF)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              gradient: LinearGradient(
                                colors: AppColors.brandGradient,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.socialPink.withValues(
                                    alpha: 0.28,
                                  ),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppColors.white,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Overthinking',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.socialPink,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        post.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _listenerDivider),
          _OverthinkingPostActions(post: post, onAction: onAction),
        ],
      ),
    );
  }
}

class _OverthinkingPostActions extends StatelessWidget {
  const _OverthinkingPostActions({required this.post, required this.onAction});

  final ListenerOverthinkingSharePreview post;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final like = _PostAction(
      key: const Key('listener-overthinking-like-action'),
      icon: Icons.favorite_border_rounded,
      label: '${post.likeCount}',
      color: AppColors.socialPink,
      iconColor: AppColors.likeHeart,
      onTap: () => onAction('Overthinking beğenisi'),
    );
    final comments = _PostAction(
      key: const Key('listener-overthinking-comment-action'),
      icon: Icons.chat_bubble_outline_rounded,
      label: '${post.commentCount}',
      onTap: () => onAction('Overthinking yorumları'),
    );
    final open = _OpenOverthinkingAction(onTap: () => onAction('Paylaşımı aç'));
    final share = _PostIconAction(
      icon: Icons.send_outlined,
      label: 'Overthinking paylaş',
      onTap: () => onAction('Overthinking paylaşımı'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        if (textScale > 1.35 || constraints.maxWidth < 300) {
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [like, comments, open, share],
          );
        }
        return SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  like,
                  const SizedBox(width: 18),
                  comments,
                  const Spacer(),
                  share,
                ],
              ),
              open,
            ],
          ),
        );
      },
    );
  }
}

class _OpenOverthinkingAction extends StatelessWidget {
  const _OpenOverthinkingAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('listener-open-overthinking-action'),
      container: true,
      button: true,
      enabled: true,
      label: 'Paylaşımı aç',
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Ink(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _listenerSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: _listenerBorder),
                ),
                child: const Icon(
                  Icons.arrow_downward_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? _listenerMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor ?? resolvedColor, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: resolvedColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostIconAction extends StatelessWidget {
  const _PostIconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: Icon(icon, color: _listenerMuted, size: 19),
    );
  }
}
