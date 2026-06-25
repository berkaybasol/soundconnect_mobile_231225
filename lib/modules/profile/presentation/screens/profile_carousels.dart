import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../domain/entities/venue_active_band.dart';
import '../../domain/entities/venue_active_musician.dart';
import '../../domain/entities/profile_venue_models.dart';
import 'profile_route_args.dart';

class VenueNameCarousel extends StatelessWidget {
  final List<VenueConnection> items;
  final bool editable;
  final VoidCallback? onAddTap;

  VenueNameCarousel({
    super.key,
    required this.items,
    this.editable = false,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      if (editable && onAddTap != null) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAddTap,
              icon: Icon(Icons.add_circle_outline, size: 18),
              label: Text('Mekan ekle'),
            ),
          ),
        );
      }
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
                    child: Theme.of(context).brightness == Brightness.light
                        ? Text(
                            venue.venueName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          )
                        : GradientText(
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

class ActiveMusicianCarousel extends StatelessWidget {
  final List<VenueActiveMusician> items;
  final bool editable;
  final VoidCallback? onAddTap;

  ActiveMusicianCarousel({
    super.key,
    required this.items,
    this.editable = false,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      if (editable && onAddTap != null) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAddTap,
              icon: Icon(Icons.add_circle_outline, size: 18),
              label: Text('Müzisyen ekle'),
            ),
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Text(
          'Müzisyen bilgisi yok.',
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
                          ? Image.network(imageUrl, fit: BoxFit.cover)
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
                    child: GradientText(
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

class ActiveBandCarousel extends StatelessWidget {
  final List<VenueActiveBand> items;

  ActiveBandCarousel({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Text(
          'Band bilgisi yok.',
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
          final band = items[index];
          final imageUrl = band.profileImageUrl?.trim();
          final hasImage =
              imageUrl != null &&
              (imageUrl.startsWith('http://') ||
                  imageUrl.startsWith('https://'));

          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: band.bandId.trim().isEmpty
                ? null
                : () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.bandPublicProfile,
                      arguments: band.bandId,
                    );
                  },
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
                              Icons.groups_2_outlined,
                              color: AppColors.coralAlt,
                              size: 20,
                            ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: GradientText(
                      text: band.displayName,
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
