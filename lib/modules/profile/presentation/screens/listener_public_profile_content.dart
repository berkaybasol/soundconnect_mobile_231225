import 'package:flutter/material.dart';

import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/entities/listener_public_profile.dart';
import '../../../spotify/domain/entities/spotify_playlist_preview.dart';
import 'listener_playlist_section.dart';
import 'listener_profile_header.dart';
import 'listener_profile_theme.dart';

class ListenerPublicProfileContent extends StatelessWidget {
  const ListenerPublicProfileContent({
    super.key,
    required this.profile,
    required this.isFollowing,
    required this.followBusy,
    required this.onRefresh,
    required this.onPlaylistTap,
    this.onFollow,
    this.onMessage,
    this.eventPosts,
  });

  final ListenerPublicProfile profile;
  final bool isFollowing;
  final bool followBusy;
  final Future<void> Function() onRefresh;
  final ValueChanged<SpotifyPlaylistPreview> onPlaylistTap;
  final VoidCallback? onFollow;
  final VoidCallback? onMessage;
  final Widget? eventPosts;

  @override
  Widget build(BuildContext context) {
    assert(
      !profile.isGhost && !profile.restricted,
      'Standard public content cannot render a restricted listener profile.',
    );
    if (profile.isGhost || profile.restricted) {
      return const SizedBox.shrink();
    }

    final normalizedUsername = profile.username.trim().replaceFirst(
      RegExp(r'^@+'),
      '',
    );
    assert(
      normalizedUsername.isNotEmpty,
      'Public listener identity requires an authoritative username.',
    );
    final username = normalizedUsername.isEmpty ? '—' : normalizedUsername;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('listener-public-standard-content'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 34),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListenerProfileHeader(
                    username: username,
                    imageUrl: profile.profilePictureUrl,
                    followerCount: profile.followerCount,
                    followingCount: profile.followingCount,
                    bio: profile.bio?.trim() ?? '',
                    actionButtons: onFollow != null || onMessage != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: _PublicProfileActions(
                              isFollowing: isFollowing,
                              followBusy: followBusy,
                              onFollow: onFollow,
                              onMessage: onMessage,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (profile.playlists.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    ListenerPlaylistSection(
                      playlists: profile.playlists,
                      onPlaylistTap: onPlaylistTap,
                    ),
                  ],
                  if (eventPosts != null)
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: ListenerProfileTheme(child: eventPosts!),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicProfileActions extends StatelessWidget {
  const _PublicProfileActions({
    required this.isFollowing,
    required this.followBusy,
    required this.onFollow,
    required this.onMessage,
  });

  final bool isFollowing;
  final bool followBusy;
  final VoidCallback? onFollow;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final followButton = onFollow == null
        ? null
        : OutlinedButton(
            key: const Key('listener-public-follow'),
            onPressed: followBusy ? null : onFollow,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
              side: BorderSide(color: theme.dividerColor),
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              followBusy
                  ? 'Bekle...'
                  : (isFollowing ? 'Takibi Bırak' : 'Takip Et'),
              textAlign: TextAlign.center,
            ),
          );
    final messageButton = onMessage == null
        ? null
        : ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: GradientOutlineButton(
              label: 'Mesaj Gönder',
              onPressed: onMessage,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              horizontalPadding: 12,
              strokeWidth: 0.7,
              maxLines: null,
              leading: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            ),
          );

    if (followButton == null) {
      return SizedBox(width: double.infinity, child: messageButton);
    }
    if (messageButton == null) {
      return SizedBox(width: double.infinity, child: followButton);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackActions = constraints.maxWidth < 300 || textScale > 1.35;
        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [followButton, const SizedBox(height: 12), messageButton],
          );
        }
        return Row(
          children: [
            Expanded(child: followButton),
            const SizedBox(width: 12),
            Expanded(child: messageButton),
          ],
        );
      },
    );
  }
}
