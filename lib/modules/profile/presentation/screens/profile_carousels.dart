import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/network/network_config.dart';
import '../../domain/entities/venue_active_band.dart';
import '../../domain/entities/venue_active_musician.dart';
import '../../domain/entities/profile_venue_models.dart';
import 'profile_mini_card.dart';
import 'profile_route_args.dart';

class VenueNameCarousel extends StatelessWidget {
  final List<VenueConnection> items;
  final bool editable;
  final VoidCallback? onAddTap;
  final String emptyMessage;

  const VenueNameCarousel({
    super.key,
    required this.items,
    this.editable = false,
    this.onAddTap,
    this.emptyMessage = 'Mekan bilgisi yok.',
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _ConnectionEmpty(
        message: emptyMessage,
        addLabel: 'Mekan ekle',
        onAdd: editable ? onAddTap : null,
      );
    }
    return ProfileMiniCarousel(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final venue = items[index];
        return ProfileMiniCard(
          key: ValueKey('venue-${venue.venueId}'),
          title: venue.venueName,
          imageUrl: resolveProfileConnectionImageUrl(venue.profileImageUrl),
          fallbackIcon: Icons.storefront_outlined,
          onTap: venue.venueId.trim().isEmpty
              ? null
              : () => Navigator.of(context).pushNamed(
                  AppRoutes.venuePublicProfile,
                  arguments: VenuePublicProfileArgs(venueId: venue.venueId),
                ),
        );
      },
    );
  }
}

class ActiveMusicianCarousel extends StatelessWidget {
  final List<VenueActiveMusician> items;
  final bool editable;
  final VoidCallback? onAddTap;
  final String emptyMessage;

  const ActiveMusicianCarousel({
    super.key,
    required this.items,
    this.editable = false,
    this.onAddTap,
    this.emptyMessage = 'Müzisyen bilgisi yok.',
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _ConnectionEmpty(
        message: emptyMessage,
        addLabel: 'Müzisyen ekle',
        onAdd: editable ? onAddTap : null,
      );
    }
    return ProfileMiniCarousel(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final artist = items[index];
        final isBand = artist.bandId.trim().isNotEmpty;
        final id = isBand ? artist.bandId : artist.musicianProfileId;
        return ProfileMiniCard(
          key: ValueKey('${isBand ? 'band' : 'musician'}-$id'),
          title: artist.displayName,
          imageUrl: resolveProfileConnectionImageUrl(artist.profileImageUrl),
          fallbackIcon: isBand
              ? Icons.groups_2_outlined
              : Icons.person_outline_rounded,
          onTap: id.trim().isEmpty
              ? null
              : () => Navigator.of(context).pushNamed(
                  isBand
                      ? AppRoutes.bandPublicProfile
                      : AppRoutes.musicianPublicProfile,
                  arguments: isBand ? id : {'profileId': id},
                ),
        );
      },
    );
  }
}

class ActiveBandCarousel extends StatelessWidget {
  final List<VenueActiveBand> items;

  const ActiveBandCarousel({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return ActiveMusicianCarousel(
      emptyMessage: 'Band bilgisi yok.',
      items: [
        for (final band in items)
          VenueActiveMusician(
            musicianProfileId: '',
            bandId: band.bandId,
            displayName: band.displayName,
            profileImageUrl: band.profileImageUrl,
          ),
      ],
    );
  }
}

class _ConnectionEmpty extends StatelessWidget {
  const _ConnectionEmpty({
    required this.message,
    required this.addLabel,
    this.onAdd,
  });

  final String message;
  final String addLabel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: onAdd == null ? 6 : 8,
      ),
      child: onAdd == null
          ? Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text(addLabel),
              ),
            ),
    );
  }
}

/// Resolve API-relative thumbnails without passing unsupported URI schemes
/// to the image cache or silently treating them as relative paths.
String? resolveProfileConnectionImageUrl(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  final parsed = Uri.tryParse(value);
  if (parsed == null) return null;
  final Uri resolved;
  if (value.startsWith('//')) {
    resolved = parsed.replace(scheme: 'https');
  } else if (parsed.hasScheme) {
    resolved = parsed;
  } else {
    final base = Uri.tryParse(NetworkConfig.baseUrl);
    if (base == null || !base.hasScheme || base.host.isEmpty) return null;
    resolved = base.resolve(value.startsWith('/') ? value : '/$value');
  }
  if ((resolved.scheme != 'http' && resolved.scheme != 'https') ||
      resolved.host.isEmpty) {
    return null;
  }
  return resolved.toString();
}
