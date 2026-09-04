import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../domain/entities/listener_profile.dart';
import '../../../spotify/domain/entities/spotify_playlist_preview.dart';
import 'listener_playlist_section.dart';
import 'listener_profile_preview_data.dart';
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

    return ColoredBox(
      color: _listenerDeepSurface,
      child: ListView(
        key: const Key('listener-owner-profile-content'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const SizedBox(height: 14),
          _ListenerOwnerAvatar(
            username: username,
            imageUrl: profile.profilePictureUrl,
            onEdit: actionBusy ? null : onEditAvatar,
          ),
          const SizedBox(height: 10),
          Center(
            child: GradientText(
              text: username,
              gradient: LinearGradient(colors: AppColors.brandGradient),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              textAlign: TextAlign.center,
            ),
          ),
          if (followerCount != null && followingCount != null) ...[
            const SizedBox(height: 12),
            _ListenerFollowerSummary(
              followersCount: followerCount,
              followingCount: followingCount,
            ),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 38),
              child: Text(
                bio,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFC1C8D2),
                  fontSize: 12,
                  height: 1.42,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ListenerEditProfileButton(
              key: const Key('listener-edit-profile'),
              onPressed: actionBusy ? null : onEditProfile,
            ),
          ),
          const SizedBox(height: 20),
          ListenerPlaylistSection(
            playlists: profile.playlists,
            onPlaylistTap: onPlaylistTap,
            onEdit: actionBusy ? null : onEditPlaylists,
            showWhenEmpty: true,
          ),
          if (showPreviewSections && preview != null) ...[
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
              child: Column(
                children: [
                  _ListenerEventPostCard(
                    username: username,
                    imageUrl: profile.profilePictureUrl,
                    post: preview.eventShare,
                    onAction: onPreviewAction,
                  ),
                  const SizedBox(height: 16),
                  _ListenerOverthinkingPostCard(
                    username: username,
                    imageUrl: profile.profilePictureUrl,
                    post: preview.overthinkingShare,
                    onAction: onPreviewAction,
                  ),
                ],
              ),
            ),
          ],
        ],
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

class _ListenerFollowerSummary extends StatelessWidget {
  const _ListenerFollowerSummary({
    required this.followersCount,
    required this.followingCount,
  });

  final int followersCount;
  final int followingCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        _ListenerMetricPill(value: followersCount, label: 'Takipçi'),
        _ListenerMetricPill(value: followingCount, label: 'Takip'),
      ],
    );
  }
}

class _ListenerMetricPill extends StatelessWidget {
  const _ListenerMetricPill({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: _listenerSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _listenerBorder),
      ),
      alignment: Alignment.center,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$value ',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: label,
              style: const TextStyle(
                color: _listenerMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _ListenerEditProfileButton extends StatelessWidget {
  const _ListenerEditProfileButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.all(0.8),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(colors: AppColors.brandGradient),
      ),
      child: Material(
        color: _listenerSurface,
        borderRadius: BorderRadius.circular(13.2),
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final stackContent =
                  constraints.maxWidth < 220 || textScale > 1.35;
              const icon = Icon(
                Icons.edit_outlined,
                size: 16,
                color: Colors.white,
              );
              const label = Text(
                'Profili Düzenle',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              );
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: stackContent
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [icon, SizedBox(height: 4), label],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          icon,
                          SizedBox(width: 8),
                          Flexible(child: label),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ListenerOwnerAvatar extends StatelessWidget {
  const _ListenerOwnerAvatar({
    required this.username,
    required this.imageUrl,
    required this.onEdit,
  });

  final String username;
  final String? imageUrl;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl?.trim();
    final hasImage = isValidNetworkImageUrl(normalizedUrl);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Center(
      child: SizedBox.square(
        dimension: 88,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF7A45), Color(0xFF8B2CFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B2CFF).withValues(alpha: 0.22),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1.2),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: _listenerDeepSurface,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: hasImage
                          ? AppCachedNetworkImage(
                              imageUrl: normalizedUrl,
                              width: 86,
                              height: 86,
                              fit: BoxFit.cover,
                              cacheWidth: (86 * pixelRatio).round(),
                              errorBuilder: (_) => _InitialsAvatar(
                                initials: _initials(username),
                              ),
                            )
                          : _InitialsAvatar(initials: _initials(username)),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Semantics(
                button: onEdit != null,
                enabled: onEdit != null,
                label: 'Profil fotoğrafını düzenle',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const Key('listener-edit-avatar'),
                    customBorder: const CircleBorder(),
                    onTap: onEdit,
                    child: SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: Transform.translate(
                          // Preserve the visual overlap without placing the
                          // 48 px tap target outside the avatar's hit-test
                          // bounds.
                          offset: const Offset(13, 13),
                          child: Ink(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: AppColors.brandGradient,
                              ),
                              border: Border.all(
                                color: _listenerDeepSurface,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              color: AppColors.white,
                              size: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B2033), Color(0xFF151525), _listenerDeepSurface],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
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

class _ListenerEventPostCard extends StatelessWidget {
  const _ListenerEventPostCard({
    required this.username,
    required this.imageUrl,
    required this.post,
    required this.onAction,
  });

  final String username;
  final String? imageUrl;
  final ListenerEventSharePreview post;
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
          const SizedBox(height: 16),
          Text(
            post.message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _EventPreviewCard(post: post),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _listenerDivider),
          const SizedBox(height: 10),
          _EventPostActions(post: post, onAction: onAction),
        ],
      ),
    );
  }
}

class _EventPreviewCard extends StatelessWidget {
  const _EventPreviewCard({required this.post});

  final ListenerEventSharePreview post;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _listenerDeepSurface,
          border: Border.all(color: _listenerBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 82),
              color: _listenerDeepSurface,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF261923),
                            Color(0xFF151422),
                            _listenerDeepSurface,
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(-0.90, -0.95),
                          radius: 1.12,
                          colors: [Color(0x70F06C86), Color(0x00F06C86)],
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0.72, -0.10),
                          radius: 0.82,
                          colors: [Color(0x668B2CFF), Color(0x008B2CFF)],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CANLI ETKİNLİK',
                                style: TextStyle(
                                  color: AppColors.coralLight,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                post.eventTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 42,
                            minHeight: 44,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xE609111E),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _listenerBorder),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                post.day,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                post.month,
                                style: TextStyle(
                                  color: AppColors.socialPink,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const ColoredBox(
              color: _listenerDivider,
              child: SizedBox(height: 1),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              color: _listenerDeepSurface,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.venue,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          post.time,
                          style: const TextStyle(
                            color: _listenerMuted,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          post.location,
                          style: const TextStyle(
                            color: _listenerMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.spotifyGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Katılıyor',
                      style: TextStyle(
                        color: AppColors.spotifyGreenBright,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

class _EventPostActions extends StatelessWidget {
  const _EventPostActions({required this.post, required this.onAction});

  final ListenerEventSharePreview post;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final attendance = _PostAction(
      key: const Key('listener-event-attendance-action'),
      icon: Icons.event_available_outlined,
      label: post.attendanceLabel,
      color: AppColors.socialPink,
      onTap: () => onAction('Etkinlik katılımı'),
    );
    final comments = _PostAction(
      key: const Key('listener-event-comment-action'),
      icon: Icons.chat_bubble_outline_rounded,
      label: '${post.commentCount}',
      onTap: () => onAction('Etkinlik yorumları'),
    );
    final share = _PostIconAction(
      icon: Icons.send_outlined,
      label: 'Etkinliği paylaş',
      onTap: () => onAction('Etkinlik paylaşımı'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        if (textScale > 1.35 || constraints.maxWidth < 240) {
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [attendance, comments, share],
          );
        }
        return Row(
          children: [
            attendance,
            const SizedBox(width: 18),
            comments,
            const Spacer(),
            share,
          ],
        );
      },
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

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
              Icon(icon, color: resolvedColor, size: 18),
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
