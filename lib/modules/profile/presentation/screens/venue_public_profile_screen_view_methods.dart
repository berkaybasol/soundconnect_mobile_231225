part of 'venue_public_profile_screen.dart';

extension _VenuePublicProfileViewMethods on _MusicianPublicProfileViewState {
  Future<void> _ensureFallbackWeeklyEvents(VenuePublicProfile profile) async {
    final venueId = profile.venueId.trim();
    if (venueId.isEmpty) return;
    if (profile.weeklyEvents.isNotEmpty) {
      if (_fallbackWeeklyEvents.isNotEmpty ||
          _fallbackWeeklyEventsVenueId != null) {
        _updateState(() {
          _fallbackWeeklyEvents = const [];
          _fallbackWeeklyEventsVenueId = null;
        });
      }
      return;
    }
    if (_loadingFallbackWeeklyEvents &&
        _fallbackWeeklyEventsVenueId == venueId) {
      return;
    }
    if (_fallbackWeeklyEventsVenueId == venueId) {
      return;
    }

    _fallbackWeeklyEventsVenueId = venueId;
    _loadingFallbackWeeklyEvents = true;
    try {
      final result = await _venueEventRepository.listPublicByVenue(venueId);
      final items = result.data ?? const <VenueOwnerEventItem>[];
      if (!mounted) return;
      _updateState(() {
        _fallbackWeeklyEvents = items
            .map((item) => _toWeeklyCalendarEvent(profile, item))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      _updateState(() {
        _fallbackWeeklyEvents = const [];
        _fallbackWeeklyEventsVenueId = venueId;
      });
    } finally {
      _loadingFallbackWeeklyEvents = false;
    }
  }

  MusicianProfile _toDisplayProfile(VenuePublicProfile profile) {
    final location = [
      profile.neighborhoodName,
      profile.districtName,
      profile.cityName,
    ].where((item) => item != null && item.trim().isNotEmpty).join(' / ');

    return MusicianProfile(
      id: profile.venueId,
      userId: profile.ownerUserId,
      username: profile.venueName,
      stageName: profile.venueName,
      bio: profile.bio ?? profile.description,
      profilePicture: profile.profilePictureUrl,
      instagramUrl: profile.instagramUrl,
      youtubeUrl: profile.youtubeUrl,
      soundcloudUrl: profile.website,
      spotifyEmbedUrl: profile.websiteUrl,
      spotifyArtistId: null,
      spotifyTrackIds: const [],
      spotifyTracks: const [],
      instruments: const [],
      activeVenues: profile.activeMusicians
          .map((item) => item.displayName)
          .toList(),
      bands: location.isEmpty ? const [] : [location],
    );
  }

  List<WeeklyCalendarEvent> _toWeeklyCalendarEvents(
    VenuePublicProfile profile,
  ) {
    return profile.weeklyEvents
        .map(
          (item) => WeeklyCalendarEvent(
            id: item.eventId,
            title: item.title,
            artistName: item.performerName,
            artistProfileId: item.musicianProfileId,
            bandProfileId: item.bandId,
            performerType: item.performerType,
            venueName: profile.venueName,
            venueId: profile.venueId,
            city: profile.cityName ?? '',
            district: profile.districtName ?? '',
            neighborhood: profile.neighborhoodName ?? '',
            eventDate: _formatDate(item.eventDate),
            startTime: item.startTime ?? '-',
            endTime: item.endTime ?? '-',
            imageAssetPath: item.posterImage,
            // Profile summaries do not include event descriptions. The detail
            // screen loads the authored description from the event endpoint.
            description: '',
          ),
        )
        .toList();
  }

  WeeklyCalendarEvent _toWeeklyCalendarEvent(
    VenuePublicProfile profile,
    VenueOwnerEventItem item,
  ) {
    return WeeklyCalendarEvent(
      id: item.id,
      title: item.title,
      artistName: item.performerName.trim().isEmpty
          ? 'Sanatci'
          : item.performerName,
      artistProfileId: item.musicianProfileId,
      bandProfileId: item.bandId,
      performerType: item.performerType,
      venueName: profile.venueName,
      venueId: profile.venueId,
      city: profile.cityName ?? '',
      district: profile.districtName ?? '',
      neighborhood: profile.neighborhoodName ?? '',
      eventDate: formatVenueEventDate(item.eventDate),
      startTime: formatVenueDisplayTime(item.startTime),
      endTime: item.endTime == null || item.endTime!.trim().isEmpty
          ? '-'
          : formatVenueDisplayTime(item.endTime!),
      imageAssetPath: item.posterImage?.trim().isEmpty == true
          ? null
          : item.posterImage?.trim(),
      description: item.description?.trim() ?? '',
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }
}
