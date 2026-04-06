// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously

part of 'venue_profile_screen.dart';

extension _VenueProfileViewStateFormatters on _MusicianPublicProfileViewState {
  MusicianProfile _toDisplayProfile(VenueOwnerProfile profile) {
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

  List<WeeklyCalendarEvent> _toWeeklyCalendarEvents(VenueOwnerProfile profile) {
    return profile.weeklyEvents
        .map(
          (item) => WeeklyCalendarEvent(
            id: item.eventId,
            title: item.title,
            artistName: item.performerName,
            artistProfileId: item.musicianProfileId,
            venueName: profile.venueName,
            venueId: profile.venueId,
            city: profile.cityName ?? '',
            district: profile.districtName ?? '',
            neighborhood: profile.neighborhoodName ?? '',
            eventDate: _formatDate(item.eventDate),
            startTime: item.startTime ?? '-',
            endTime: item.endTime ?? '-',
            imageAssetPath: item.posterImage,
            description:
                profile.description ?? '${item.performerType} performansi',
          ),
        )
        .toList();
  }

  WeeklyCalendarEvent _toWeeklyCalendarEvent(
    VenueOwnerProfile profile,
    VenueOwnerEventItem item,
  ) {
    return WeeklyCalendarEvent(
      id: item.id,
      title: item.title,
      artistName: item.performerName.trim().isEmpty
          ? 'Sanatci'
          : item.performerName,
      artistProfileId: item.musicianProfileId,
      venueName: profile.venueName,
      venueId: profile.venueId,
      city: profile.cityName ?? '',
      district: profile.districtName ?? '',
      neighborhood: profile.neighborhoodName ?? '',
      eventDate: _formatDate(item.eventDate),
      startTime: formatVenueDisplayTime(item.startTime),
      endTime: item.endTime == null || item.endTime!.trim().isEmpty
          ? '-'
          : formatVenueDisplayTime(item.endTime!),
      imageAssetPath: item.posterImage?.trim().isEmpty == true
          ? null
          : item.posterImage?.trim(),
      description: item.description?.trim().isNotEmpty == true
          ? item.description!.trim()
          : '${item.performerName.trim().isEmpty ? 'Sanatci' : item.performerName} performansi',
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }
}
