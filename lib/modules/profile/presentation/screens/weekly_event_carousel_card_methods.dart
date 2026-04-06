part of 'weekly_event_carousel.dart';

extension _WeeklyEventCardStateMethods on _WeeklyEventCardState {
  Future<String?> _resolvePosterImage() async {
    final raw = widget.event.imageAssetPath?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (_isNetworkImage(raw) || _isAssetImage(raw)) return raw;

    final cached = _WeeklyEventCardState._resolvedPosterCache[widget.event.id];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    try {
      final payload = await _loadEventPayload();
      final poster = payload.posterImage?.trim();
      if (poster == null || poster.isEmpty) return null;
      _WeeklyEventCardState._resolvedPosterCache[widget.event.id] = poster;
      return poster;
    } catch (_) {
      return null;
    }
  }

  String _fallbackArtistName() {
    final raw = widget.event.artistName.trim();
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
    final fallback = _fallbackArtistName();
    String? profileId = widget.event.artistProfileId?.trim();

    VenueEventDetail? payload;
    if (profileId == null || profileId.isEmpty || fallback == 'Sanatci') {
      try {
        payload = await _loadEventPayload();
        final payloadProfileId = payload.musicianProfileId?.trim();
        if (payloadProfileId != null && payloadProfileId.isNotEmpty) {
          profileId = payloadProfileId;
        }
      } catch (_) {
        // Payload fallback sessizce yoksayilir.
      }
    }

    if (profileId == null || profileId.isEmpty) {
      final payloadPerformer = payload?.performerName?.trim();
      if (payloadPerformer != null &&
          payloadPerformer.isNotEmpty &&
          payloadPerformer.toLowerCase() != 'performer') {
        return payloadPerformer;
      }
      return fallback;
    }

    final cached = _WeeklyEventCardState._resolvedArtistCache[profileId];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    try {
      final repository = serviceLocator<MusicianProfileRepository>();
      final result = await repository.getPublicProfileByProfileId(profileId);
      final username = result.data?.username?.trim();
      if (username != null && username.isNotEmpty) {
        final resolved = username;
        _WeeklyEventCardState._resolvedArtistCache[profileId] = resolved;
        return resolved;
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

  Future<VenueEventDetail> _loadEventPayload() async {
    final cached = _WeeklyEventCardState._eventPayloadCache[widget.event.id];
    if (cached != null) {
      return cached;
    }

    final repository = serviceLocator<VenueEventRepository>();
    final result = await repository.getDetail(widget.event.id);
    final payload =
        result.data ??
        VenueEventDetail(
          id: widget.event.id,
          shareUrl: null,
          posterImage: null,
          performerName: null,
          musicianProfileId: null,
        );
    _WeeklyEventCardState._eventPayloadCache[widget.event.id] = payload;
    return payload;
  }
}
