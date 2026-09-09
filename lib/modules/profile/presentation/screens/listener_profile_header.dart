import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import 'profile_common_widgets.dart';
import 'profile_screen_support.dart';

/// Listener identity uses the same hierarchy and controls as artist profiles.
class ListenerProfileHeader extends StatelessWidget {
  const ListenerProfileHeader({
    super.key,
    required this.username,
    required this.actionButtons,
    required this.bio,
    this.imageUrl,
    this.followerCount,
    this.followingCount,
    this.afterBio,
    this.editableAvatar = false,
    this.avatarBusy = false,
    this.onEditAvatar,
    this.identityBadge,
    this.avatarMarkerIcon,
    this.editAvatarKey,
  });

  final String username;
  final String? imageUrl;
  final int? followerCount;
  final int? followingCount;
  final Widget actionButtons;
  final String bio;
  final Widget? afterBio;
  final bool editableAvatar;
  final bool avatarBusy;
  final VoidCallback? onEditAvatar;
  final Widget? identityBadge;
  final IconData? avatarMarkerIcon;
  final Key? editAvatarKey;

  @override
  Widget build(BuildContext context) {
    return ProfileTopSection(
      header: _ListenerAvatar(
        imageUrl: imageUrl,
        editable: editableAvatar,
        busy: avatarBusy,
        onEdit: onEditAvatar,
        markerIcon: avatarMarkerIcon,
        editKey: editAvatarKey,
      ),
      identity: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            ProfileIdentityHeader(
              username: username,
              secondaryText: null,
              fallbackName: '—',
            ),
            if (identityBadge != null) ...[
              const SizedBox(height: 8),
              identityBadge!,
            ],
          ],
        ),
      ),
      followerSummary: followerCount != null && followingCount != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ProfileFollowerSummary(
                followersCount: followerCount,
                followingCount: followingCount,
              ),
            )
          : const SizedBox.shrink(),
      actionButtons: actionButtons,
      bioSection: bio.trim().isEmpty
          ? const SizedBox.shrink()
          : EditableBioSection(bio: bio, editable: false, onSave: null),
      afterBio: afterBio,
    );
  }
}

class _ListenerAvatar extends StatelessWidget {
  const _ListenerAvatar({
    required this.imageUrl,
    required this.editable,
    required this.busy,
    required this.onEdit,
    required this.markerIcon,
    required this.editKey,
  });

  final String? imageUrl;
  final bool editable;
  final bool busy;
  final VoidCallback? onEdit;
  final IconData? markerIcon;
  final Key? editKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidate = imageUrl?.trim();
    final fallback = Icon(
      Icons.person_outline,
      color: theme.colorScheme.onSurfaceVariant,
      size: 40,
    );
    final edit = busy ? null : onEdit;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox.square(
        dimension: 96,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              key: const Key('listener-profile-avatar'),
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest,
                border: Border.all(color: theme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGradient[2].withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: isValidNetworkImageUrl(candidate)
                    ? AppCachedNetworkImage(
                        imageUrl: candidate,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        cacheWidth:
                            (96 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        errorBuilder: (_) => fallback,
                      )
                    : fallback,
              ),
            ),
            Positioned(
              left: editable || markerIcon != null ? -2 : null,
              right: editable || markerIcon != null ? null : -2,
              bottom: -2,
              child: Semantics(
                label: 'Dinleyici profili',
                image: true,
                child: Container(
                  key: const Key('listener-profile-type-badge'),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.brandGradient,
                    ),
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/headphone2.png',
                      width: 14,
                      height: 14,
                      color: AppColors.white,
                      colorBlendMode: BlendMode.srcIn,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
            ),
            if (editable)
              Positioned(
                right: 0,
                bottom: 0,
                child: Semantics(
                  label: 'Profil fotoğrafını düzenle',
                  button: true,
                  enabled: edit != null,
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: editKey ?? const Key('listener-edit-avatar'),
                      customBorder: const CircleBorder(),
                      onTap: edit,
                      child: SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: Transform.translate(
                            offset: const Offset(12, 12),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: AppColors.brandGradient,
                                ),
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 14,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (markerIcon != null)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Icon(
                    markerIcon,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
