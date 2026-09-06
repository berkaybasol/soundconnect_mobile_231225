part of 'weekly_event_carousel.dart';

extension _WeeklyEventCardStateMethods on _WeeklyEventCardState {
  Future<String?> _resolvePosterImage() async {
    final event = widget.event;
    final eventId = event.id;
    final raw = event.imageAssetPath?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (_isNetworkImage(raw) || _isAssetImage(raw)) return raw;

    final cached = _WeeklyEventCardState._resolvedPosterCache[eventId];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    try {
      final payload = await _loadEventPayload(eventId);
      final poster = payload.posterImage?.trim();
      if (poster == null || poster.isEmpty) return null;
      _WeeklyEventCardState._cacheResolvedValue(
        _WeeklyEventCardState._resolvedPosterCache,
        eventId,
        poster,
      );
      return poster;
    } catch (_) {
      return null;
    }
  }

  String _fallbackArtistName(WeeklyCalendarEvent event) {
    final raw = event.artistName.trim();
    if (raw.isEmpty) return 'Sanatci';
    final normalized = raw.toLowerCase();
    if (normalized == 'performer') return 'Sanatci';
    return raw;
  }

  String _displayTimeLabel() {
    final raw = widget.event.startTime.trim();
    if (raw.isEmpty) return '-';
    final parts = raw.split(':');
    if (parts.length >= 2) {
      final hour = parts[0].padLeft(2, '0');
      final minute = parts[1].padLeft(2, '0');
      return '$hour:$minute';
    }
    return raw;
  }

  Future<String> _resolveArtistName() async {
    final event = widget.event;
    final eventId = event.id;
    final fallback = _fallbackArtistName(event);
    String? musicianProfileId = event.linkedArtistProfileId;
    String? bandProfileId = event.linkedBandProfileId;

    VenueEventDetail? payload;
    if ((musicianProfileId == null || musicianProfileId.isEmpty) &&
            (bandProfileId == null || bandProfileId.isEmpty) ||
        fallback == 'Sanatci') {
      try {
        payload = await _loadEventPayload(eventId);
        final payloadIdentity = payload.performerIdentity;
        final payloadMusicianId = payloadIdentity.musicianProfileId;
        final payloadBandId = payloadIdentity.bandId;
        if (payloadMusicianId != null && payloadMusicianId.isNotEmpty) {
          musicianProfileId = payloadMusicianId;
        }
        if (payloadBandId != null && payloadBandId.isNotEmpty) {
          bandProfileId = payloadBandId;
        }
      } catch (_) {
        // Payload fallback sessizce yoksayilir.
      }
    }

    final linkedId = bandProfileId?.isNotEmpty == true
        ? bandProfileId!
        : musicianProfileId;
    if (linkedId == null || linkedId.isEmpty) {
      final payloadPerformer = payload?.performerName?.trim();
      if (payloadPerformer != null &&
          payloadPerformer.isNotEmpty &&
          payloadPerformer.toLowerCase() != 'performer') {
        return payloadPerformer;
      }
      return fallback;
    }

    final cacheKey = bandProfileId?.isNotEmpty == true
        ? 'BAND:$linkedId'
        : 'MUSICIAN:$linkedId';
    final cached = _WeeklyEventCardState._resolvedArtistCache[cacheKey];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    try {
      if (bandProfileId?.isNotEmpty == true) {
        final repository = serviceLocator<BandRepository>();
        final result = await repository.getPublicBandById(linkedId);
        final name = result.data?.name.trim();
        if (name != null && name.isNotEmpty) {
          _WeeklyEventCardState._cacheResolvedValue(
            _WeeklyEventCardState._resolvedArtistCache,
            cacheKey,
            name,
          );
          return name;
        }
      } else {
        final repository = serviceLocator<MusicianProfileRepository>();
        final result = await repository.getPublicProfileByProfileId(linkedId);
        final username = result.data?.username?.trim();
        if (username != null && username.isNotEmpty) {
          _WeeklyEventCardState._cacheResolvedValue(
            _WeeklyEventCardState._resolvedArtistCache,
            cacheKey,
            username,
          );
          return username;
        }
      }
    } catch (_) {
      // Fallback mevcut event ismine donecek.
    }

    final payloadPerformer = payload?.performerName?.trim();
    if (payloadPerformer != null &&
        payloadPerformer.isNotEmpty &&
        payloadPerformer.toLowerCase() != 'performer') {
      return payloadPerformer;
    }

    return fallback;
  }

  Future<VenueEventDetail> _loadEventPayload(String eventId) {
    final inFlight = _eventPayloadFuture;
    if (inFlight != null) return inFlight;
    final future = _fetchEventPayload(eventId);
    _eventPayloadFuture = future;
    return future;
  }

  Future<VenueEventDetail> _fetchEventPayload(String eventId) async {
    final repository = serviceLocator<VenueEventRepository>();
    final result = await repository.getDetail(eventId);
    final payload =
        result.data ??
        VenueEventDetail(
          id: eventId,
          shareUrl: null,
          posterImage: null,
          performerName: null,
          musicianProfileId: null,
          bandId: null,
          performerType: 'MANUAL',
        );
    return payload;
  }
}
