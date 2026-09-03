import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../domain/entities/listener_public_profile.dart';
import 'profile_screen_support.dart';

const _publicDeepSurface = Color(0xFF070B13);
const _publicSurface = Color(0xFF101722);
const _publicBorder = Color(0xFF202B3A);
const _publicMuted = Color(0xFFA0A9B6);

class ListenerPublicProfileContent extends StatelessWidget {
  const ListenerPublicProfileContent({
    super.key,
    required this.profile,
    required this.isFollowing,
    required this.followBusy,
    required this.onRefresh,
    this.onFollow,
    this.onMessage,
  });

  final ListenerPublicProfile profile;
  final bool isFollowing;
  final bool followBusy;
  final Future<void> Function() onRefresh;
  final VoidCallback? onFollow;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    assert(
      !profile.isGhost && !profile.restricted,
      'Standard public content cannot render a restricted listener profile.',
    );
    if (profile.isGhost || profile.restricted) {
      return const SizedBox.shrink();
    }

    final normalizedUsername = profile.username.trim();
    assert(
      normalizedUsername.isNotEmpty,
      'Public listener identity requires an authoritative username.',
    );
    final username = normalizedUsername.isEmpty ? '—' : normalizedUsername;
    final handle = normalizedUsername.isEmpty ? username : '@$username';
    final bio = profile.bio?.trim() ?? '';
    final followerCount = profile.followerCount;
    final followingCount = profile.followingCount;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ColoredBox(
        color: _publicDeepSurface,
        child: ListView(
          key: const Key('listener-public-standard-content'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 34),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PublicAvatar(
                      username: username,
                      imageUrl: profile.profilePictureUrl,
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: GradientText(
                        text: handle,
                        gradient: LinearGradient(
                          colors: AppColors.brandGradient,
                        ),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.25,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Center(child: _ListenerTypePill()),
                    if (followerCount != null && followingCount != null) ...[
                      const SizedBox(height: 16),
                      _PublicCountRow(
                        followerCount: followerCount,
                        followingCount: followingCount,
                      ),
                    ],
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFC7CED8),
                            fontSize: 12.5,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                    if (onFollow != null || onMessage != null) ...[
                      const SizedBox(height: 22),
                      _PublicProfileActions(
                        isFollowing: isFollowing,
                        followBusy: followBusy,
                        onFollow: onFollow,
                        onMessage: onMessage,
                      ),
                    ],
                    const SizedBox(height: 28),
                    const Divider(height: 1, color: _publicBorder),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicAvatar extends StatelessWidget {
  const _PublicAvatar({required this.username, required this.imageUrl});

  final String username;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl?.trim();
    final hasImage = isValidNetworkImageUrl(normalizedUrl);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Center(
      child: Container(
        width: 104,
        height: 104,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF765D), Color(0xFFD04CCC), Color(0xFF8137E8)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.socialPurple.withValues(alpha: 0.2),
              blurRadius: 22,
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: _publicDeepSurface,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: hasImage
                  ? AppCachedNetworkImage(
                      imageUrl: normalizedUrl,
                      width: 93,
                      height: 93,
                      fit: BoxFit.cover,
                      cacheWidth: (93 * pixelRatio).round(),
                      errorBuilder: (_) =>
                          _PublicAvatarFallback(initials: _initials(username)),
                    )
                  : _PublicAvatarFallback(initials: _initials(username)),
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicAvatarFallback extends StatelessWidget {
  const _PublicAvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34263D), Color(0xFF202238), Color(0xFF111825)],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ListenerTypePill extends StatelessWidget {
  const _ListenerTypePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _publicSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _publicBorder),
      ),
      child: const Text(
        'DİNLEYİCİ',
        style: TextStyle(
          color: _publicMuted,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.55,
        ),
      ),
    );
  }
}

class _PublicCountRow extends StatelessWidget {
  const _PublicCountRow({
    required this.followerCount,
    required this.followingCount,
  });

  final int followerCount;
  final int followingCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        _CountPill(value: followerCount, label: 'Takipçi'),
        _CountPill(value: followingCount, label: 'Takip'),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 35),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _publicSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _publicBorder),
      ),
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
                color: _publicMuted,
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
    final followButton = onFollow == null
        ? null
        : _GradientFilledButton(
            key: const Key('listener-public-follow'),
            label: isFollowing ? 'Takibi Bırak' : 'Takip Et',
            loading: followBusy,
            icon: isFollowing
                ? Icons.person_remove_alt_1_outlined
                : Icons.person_add_alt_1_outlined,
            onPressed: followBusy ? null : onFollow,
          );
    final messageButton = onMessage == null
        ? null
        : ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: GradientOutlineButton(
              label: 'Mesaj Gönder',
              onPressed: onMessage,
              backgroundColor: _publicSurface,
              horizontalPadding: 14,
              leading: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
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
        final stackActions = constraints.maxWidth < 320 || textScale > 1.35;
        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [followButton, const SizedBox(height: 10), messageButton],
          );
        }
        return Row(
          children: [
            Expanded(child: followButton),
            const SizedBox(width: 10),
            Expanded(child: messageButton),
          ],
        );
      },
    );
  }
}

class _GradientFilledButton extends StatelessWidget {
  const _GradientFilledButton({
    super.key,
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? const LinearGradient(
                colors: [Color(0xFF343A46), Color(0xFF252A33)],
              )
            : LinearGradient(colors: AppColors.brandGradient),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(icon, color: Colors.white, size: 17),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(String username) {
  final pieces = username
      .trim()
      .split(RegExp(r'[\s._-]+'))
      .where((piece) => piece.isNotEmpty)
      .toList(growable: false);
  if (pieces.isEmpty || username.trim() == '—') return '?';
  if (pieces.length > 1) {
    return '${pieces.first[0]}${pieces.last[0]}'.toUpperCase();
  }
  final initial = pieces.first[0].toUpperCase();
  return '$initial$initial';
}
