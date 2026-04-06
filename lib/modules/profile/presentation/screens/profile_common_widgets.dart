import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/waveform_stub.dart';
import 'profile_section_support.dart';

part 'profile_common_widgets_bio_section.dart';
part 'profile_common_widgets_audio_preview.dart';

class ProfileIdentityHeader extends StatelessWidget {
  final String? username;
  final String? secondaryText;
  final String fallbackName;

  const ProfileIdentityHeader({
    super.key,
    required this.username,
    required this.secondaryText,
    this.fallbackName = 'Kullanici',
  });

  @override
  Widget build(BuildContext context) {
    final name = username?.trim().isNotEmpty == true
        ? username!.trim()
        : fallbackName;
    final resolvedSecondary = secondaryText?.trim();

    return Column(
      children: [
        GradientText(
          text: name,
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: AppColors.brandGradient,
          ),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        if (resolvedSecondary != null && resolvedSecondary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            resolvedSecondary,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class ProfileFollowerSummary extends StatelessWidget {
  final int? followersCount;
  final int? followingCount;
  final String followersLabel;
  final String followingLabel;
  final bool showFollowing;

  const ProfileFollowerSummary({
    super.key,
    required this.followersCount,
    required this.followingCount,
    this.followersLabel = 'Takipci',
    this.followingLabel = 'Takip',
    this.showFollowing = true,
  });

  String _formatCount(int? value, String label) {
    if (value == null) return '... $label';
    return '$value $label';
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      ProfilePillBadge(text: _formatCount(followersCount, followersLabel)),
    ];
    if (showFollowing) {
      children.add(const SizedBox(width: 12));
      children.add(
        ProfilePillBadge(text: _formatCount(followingCount, followingLabel)),
      );
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: children);
  }
}

class ProfileTopSection extends StatelessWidget {
  final Widget header;
  final Widget identity;
  final Widget followerSummary;
  final Widget actionButtons;
  final Widget bioSection;
  final Widget? afterBio;

  const ProfileTopSection({
    super.key,
    required this.header,
    required this.identity,
    required this.followerSummary,
    required this.actionButtons,
    required this.bioSection,
    this.afterBio,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Align(alignment: Alignment.center, child: header),
        const SizedBox(height: 16),
        identity,
        const SizedBox(height: 14),
        followerSummary,
        const SizedBox(height: 12),
        actionButtons,
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: bioSection,
        ),
        if (afterBio != null) ...[const SizedBox(height: 12), afterBio!],
      ],
    );
  }
}
