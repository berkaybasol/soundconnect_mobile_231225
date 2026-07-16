part of 'venue_public_profile_screen.dart';

class _ActiveMusicianCarousel extends StatelessWidget {
  final List<VenueActiveMusician> items;

  _ActiveMusicianCarousel({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Text(
          'Mekan bilgisi yok.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final musician = items[index];
          final isBand = musician.bandId.trim().isNotEmpty;
          final imageUrl = musician.profileImageUrl?.trim();
          final hasImage =
              imageUrl != null &&
              (imageUrl.startsWith('http://') ||
                  imageUrl.startsWith('https://'));
          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: isBand
                ? (musician.bandId.trim().isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.bandPublicProfile,
                            arguments: musician.bandId,
                          );
                        })
                : (musician.musicianProfileId.trim().isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.musicianPublicProfile,
                            arguments: {
                              'profileId': musician.musicianProfileId,
                            },
                          );
                        }),
            child: Container(
              width: 170,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    Theme.of(context).colorScheme.surfaceContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.white.withValues(alpha: 0.08),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: hasImage
                          ? AppCachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              cacheWidth:
                                  (36 * MediaQuery.devicePixelRatioOf(context))
                                      .round(),
                              errorBuilder: (context) => Icon(
                                isBand
                                    ? Icons.groups_2_outlined
                                    : Icons.person_outline,
                                color: AppColors.coralAlt,
                                size: 20,
                              ),
                            )
                          : Icon(
                              isBand
                                  ? Icons.groups_2_outlined
                                  : Icons.person_outline,
                              color: AppColors.coralAlt,
                              size: 20,
                            ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GradientText(
                          text: musician.displayName,
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: AppColors.brandGradient,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }
}
