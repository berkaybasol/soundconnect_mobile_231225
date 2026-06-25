part of 'musician_public_profile_screen.dart';

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;

  _SectionHeader({required this.title, this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          Spacer(),
          if (actionLabel != null)
            Text(
              actionLabel!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _VenueCarousel extends StatelessWidget {
  final List<VenueConnection> items;

  _VenueCarousel({required this.items});

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
          final venue = items[index];
          final imageUrl = venue.profileImageUrl?.trim();
          final hasImage =
              imageUrl != null &&
              (imageUrl.startsWith('http://') ||
                  imageUrl.startsWith('https://'));
          final canOpen = venue.venueId.trim().isNotEmpty;

          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: canOpen
                ? () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.venuePublicProfile,
                      arguments: VenuePublicProfileArgs(
                        venueId: venue.venueId,
                      ),
                    );
                  }
                : null,
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
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : Icon(
                              Icons.storefront_outlined,
                              color: AppColors.coralAlt,
                              size: 20,
                            ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: GradientText(
                      text: venue.venueName,
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
