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

  ProfileIdentityHeader({
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
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return Column(
      children: [
        isLightTheme
            ? Text(
                name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : GradientText(
                text: name,
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: AppColors.brandGradient,
                ),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
        if (resolvedSecondary != null && resolvedSecondary.isNotEmpty) ...[
          SizedBox(height: 6),
          Text(
            resolvedSecondary,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
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

  ProfileFollowerSummary({
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
      children.add(SizedBox(width: 12));
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

  ProfileTopSection({
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
        SizedBox(height: 12),
        Align(alignment: Alignment.center, child: header),
        SizedBox(height: 16),
        identity,
        SizedBox(height: 14),
        followerSummary,
        SizedBox(height: 12),
        actionButtons,
        SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: bioSection,
        ),
        SizedBox(height: 14),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
                  blurRadius: 8,
                  spreadRadius: 0.2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              height: 1.2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Theme.of(context).dividerColor.withValues(alpha: 0.0),
                    Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.40),
                    Theme.of(context).dividerColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (afterBio != null) ...[SizedBox(height: 12), afterBio!],
      ],
    );
  }
}
