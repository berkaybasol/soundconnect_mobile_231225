part of 'venue_public_profile_screen.dart';

class _ProfileHeader extends StatelessWidget {
  final MusicianProfile profile;

  _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: 0),
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (AppColors.isLight
                    ? AppColors.avatarBackground
                    : Theme.of(context).colorScheme.surfaceContainerHighest),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: (AppColors.isLight
                        ? AppColors.avatarShadow.withValues(alpha: 0.16)
                        : AppColors.brandGradient[2].withValues(alpha: 0.35)),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: profile.profilePicture?.startsWith('http') == true
                    ? AppCachedNetworkImage(
                        imageUrl: profile.profilePicture,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        cacheWidth:
                            (96 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        errorBuilder: (context) => Icon(
                          Icons.person_outline,
                          color: (AppColors.isLight
                              ? AppColors.avatarForeground
                              : Theme.of(context).colorScheme.onSurfaceVariant),
                          size: 40,
                        ),
                      )
                    : Icon(
                        Icons.person_outline,
                        color: (AppColors.isLight
                            ? AppColors.avatarForeground
                            : Theme.of(context).colorScheme.onSurfaceVariant),
                        size: 40,
                      ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: GradientOutline(
                enabled: AppColors.isLight,
                radius: 999,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: AppColors.isLight
                      ? BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.transparent,
                            width: 2,
                          ),
                        )
                      : BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: AppColors.isLight
                                ? AppColors.decorativeGradient
                                : [
                                    Color(0xFF7C3AED),
                                    Color(0xFFA855F7),
                                    Color(0xFFD946EF),
                                  ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.navBlueDeep,
                            width: 2,
                          ),
                        ),
                  child: Icon(
                    Icons.storefront_outlined,
                    size: 14,
                    color: AppColors.decorativeForeground,
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

class _ProfileIdentity extends StatelessWidget {
  final MusicianProfile profile;

  _ProfileIdentity({required this.profile});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final name = profile.username?.trim().isNotEmpty == true
        ? profile.username!
        : 'Kullanıcı';
    final bandName = profile.bands.isNotEmpty ? profile.bands.first : null;

    return Column(
      children: [
        GradientText(
          text: name,
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: AppColors.brandTextGradient,
          ),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        if (bandName != null) ...[
          SizedBox(height: 6),
          Text(
            bandName,
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

class _FollowerRow extends StatelessWidget {
  final int? followersCount;
  final int? followingCount;

  _FollowerRow({required this.followersCount, required this.followingCount});

  String _formatCount(int? value, String label) {
    if (value == null) return '... $label';
    return '$value $label';
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PillBadge(text: _formatCount(followersCount, 'Takipçi')),
        SizedBox(width: 12),
        _PillBadge(text: _formatCount(followingCount, 'Takip')),
      ],
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String text;

  _PillBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
