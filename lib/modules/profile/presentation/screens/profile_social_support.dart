import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/musician_profile_save_request.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/entities/studio_profile.dart';
import '../../domain/studio_profile_repository.dart';

enum ProfileSocialPlatform { soundcloud, instagram, youtube, spotify }

const studioSocialPlatforms = <ProfileSocialPlatform>[
  ProfileSocialPlatform.instagram,
  ProfileSocialPlatform.youtube,
];

extension ProfileSocialPlatformUi on ProfileSocialPlatform {
  String get label {
    switch (this) {
      case ProfileSocialPlatform.soundcloud:
        return 'SoundCloud';
      case ProfileSocialPlatform.instagram:
        return 'Instagram';
      case ProfileSocialPlatform.youtube:
        return 'YouTube';
      case ProfileSocialPlatform.spotify:
        return 'Spotify';
    }
  }

  String get placeholder {
    switch (this) {
      case ProfileSocialPlatform.soundcloud:
        return 'https://soundcloud.com/kullanici';
      case ProfileSocialPlatform.instagram:
        return 'https://instagram.com/kullanici';
      case ProfileSocialPlatform.youtube:
        return 'https://youtube.com/@kanal';
      case ProfileSocialPlatform.spotify:
        return 'https://open.spotify.com/artist/...';
    }
  }

  FaIconData get icon {
    switch (this) {
      case ProfileSocialPlatform.soundcloud:
        return FontAwesomeIcons.soundcloud;
      case ProfileSocialPlatform.instagram:
        return FontAwesomeIcons.instagram;
      case ProfileSocialPlatform.youtube:
        return FontAwesomeIcons.youtube;
      case ProfileSocialPlatform.spotify:
        return FontAwesomeIcons.spotify;
    }
  }
}

String? socialUrlForMusicianProfile(
  MusicianProfile profile,
  ProfileSocialPlatform platform,
) {
  switch (platform) {
    case ProfileSocialPlatform.soundcloud:
      return profile.soundcloudUrl;
    case ProfileSocialPlatform.instagram:
      return profile.instagramUrl;
    case ProfileSocialPlatform.youtube:
      return profile.youtubeUrl;
    case ProfileSocialPlatform.spotify:
      return profile.spotifyEmbedUrl;
  }
}

MusicianProfileSaveRequest buildMusicianSocialLinkRequest(
  ProfileSocialPlatform platform,
  String normalizedUrl,
) {
  return switch (platform) {
    ProfileSocialPlatform.soundcloud => MusicianProfileSaveRequest(
      soundcloudUrl: normalizedUrl,
    ),
    ProfileSocialPlatform.instagram => MusicianProfileSaveRequest(
      instagramUrl: normalizedUrl,
    ),
    ProfileSocialPlatform.youtube => MusicianProfileSaveRequest(
      youtubeUrl: normalizedUrl,
    ),
    ProfileSocialPlatform.spotify => MusicianProfileSaveRequest(
      spotifyEmbedUrl: normalizedUrl,
    ),
  };
}

String? socialUrlForStudioProfile(
  StudioProfile profile,
  ProfileSocialPlatform platform,
) {
  return switch (platform) {
    ProfileSocialPlatform.instagram => profile.instagramUrl,
    ProfileSocialPlatform.youtube => profile.youtubeUrl,
    ProfileSocialPlatform.soundcloud || ProfileSocialPlatform.spotify => null,
  };
}

StudioProfileSaveRequest buildStudioSocialLinkRequest(
  ProfileSocialPlatform platform,
  String normalizedUrl,
) {
  return switch (platform) {
    ProfileSocialPlatform.instagram => StudioProfileSaveRequest(
      instagramUrl: normalizedUrl,
    ),
    ProfileSocialPlatform.youtube => StudioProfileSaveRequest(
      youtubeUrl: normalizedUrl,
    ),
    ProfileSocialPlatform.soundcloud ||
    ProfileSocialPlatform.spotify => throw ArgumentError.value(
      platform,
      'platform',
      'Studio profiles do not support this social platform.',
    ),
  };
}

Future<String?> promptForSocialLink(
  BuildContext context, {
  required ProfileSocialPlatform platform,
  required String initialValue,
}) async {
  var draftValue = initialValue;
  final isEditing = draftValue.trim().isNotEmpty;

  final submitted = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('${platform.label} ${isEditing ? 'duzenle' : 'ekle'}'),
        content: TextFormField(
          initialValue: draftValue,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(hintText: platform.placeholder),
          onChanged: (value) => draftValue = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(draftValue),
            child: Text('Kaydet'),
          ),
        ],
      );
    },
  );
  if (submitted == null) return null;
  final trimmed = submitted.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.contains('://') ? trimmed : 'https://$trimmed';
}

Future<void> _launchProfileSocialUrl(BuildContext context, String? url) async {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) return;

  final normalized = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Gecersiz link')));
    return;
  }

  final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!success && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Link acilamadi')));
  }
}

class ProfileSocialButtonRow extends StatelessWidget {
  final MusicianProfile profile;
  final bool editable;
  final ValueChanged<ProfileSocialPlatform>? onAddLink;
  final double pillWidth;

  ProfileSocialButtonRow({
    super.key,
    required this.profile,
    this.editable = false,
    this.onAddLink,
    this.pillWidth = 64,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSocialLinksRow(
      items: ProfileSocialPlatform.values
          .map(
            (platform) => ProfileSocialLinkItem(
              platform: platform,
              url: socialUrlForMusicianProfile(profile, platform),
            ),
          )
          .toList(),
      editable: editable,
      onAddLink: onAddLink,
      pillWidth: pillWidth,
    );
  }
}

class ProfileSocialLinkItem {
  final ProfileSocialPlatform platform;
  final String? url;

  const ProfileSocialLinkItem({required this.platform, required this.url});

  bool get active => _isSocialUrlUsable(url);
}

class ProfileSocialLinksRow extends StatelessWidget {
  final List<ProfileSocialLinkItem> items;
  final bool editable;
  final ValueChanged<ProfileSocialPlatform>? onAddLink;
  final double pillWidth;

  const ProfileSocialLinksRow({
    super.key,
    required this.items,
    this.editable = false,
    this.onAddLink,
    this.pillWidth = 64,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = editable
        ? items
        : items.where((item) => item.active).toList();

    if (visibleItems.isEmpty) return SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: visibleItems.map((item) {
        return _ProfileSocialPill(
          icon: item.platform.icon,
          active: item.active,
          showAddBadge: editable && !item.active,
          width: pillWidth,
          onTap: editable
              ? () => onAddLink?.call(item.platform)
              : (item.active
                    ? () => _launchProfileSocialUrl(context, item.url)
                    : null),
        );
      }).toList(),
    );
  }
}

bool _isSocialUrlUsable(String? raw) {
  final value = raw?.trim().toLowerCase();
  if (value == null || value.isEmpty) return false;
  return value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('www.');
}

class _ProfileSocialPill extends StatefulWidget {
  final FaIconData icon;
  final bool active;
  final bool showAddBadge;
  final double width;
  final VoidCallback? onTap;

  _ProfileSocialPill({
    required this.icon,
    required this.active,
    required this.width,
    this.showAddBadge = false,
    this.onTap,
  });

  @override
  State<_ProfileSocialPill> createState() => _ProfileSocialPillState();
}

class _ProfileSocialPillState extends State<_ProfileSocialPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final iconGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.socialOrange,
        AppColors.socialPink,
        AppColors.socialPurple,
      ],
    );

    final isInteractive = widget.onTap != null;
    final borderColor = _pressed
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).dividerColor;
    final shadowOpacity = _pressed ? 0.12 : 0.05;

    return GestureDetector(
      onTapDown: isInteractive ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: isInteractive
          ? () => setState(() => _pressed = false)
          : null,
      onTapUp: isInteractive ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 140),
              curve: Curves.easeOut,
              width: widget.width,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pureBlack.withValues(alpha: shadowOpacity),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: widget.active
                    ? ShaderMask(
                        shaderCallback: (bounds) =>
                            iconGradient.createShader(bounds),
                        child: FaIcon(
                          widget.icon,
                          size: 20,
                          color: AppColors.white,
                        ),
                      )
                    : FaIcon(
                        widget.icon,
                        size: 20,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
              ),
            ),
            if (widget.showAddBadge)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Color(0xFFF47C7C),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, size: 12, color: AppColors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
