enum AnalyticsObservationType {
  eventImpression('EVENT_IMPRESSION'),
  eventDetailView('EVENT_DETAIL_VIEW'),
  venueProfileView('VENUE_PROFILE_VIEW'),
  announcementImpression('ANNOUNCEMENT_IMPRESSION'),
  announcementDetailView('ANNOUNCEMENT_DETAIL_VIEW'),
  announcementVideoStart('ANNOUNCEMENT_VIDEO_START'),
  announcementVideoComplete('ANNOUNCEMENT_VIDEO_COMPLETE');

  const AnalyticsObservationType(this.wireValue);
  final String wireValue;
  bool get isAnnouncement => wireValue.startsWith('ANNOUNCEMENT_');
  bool get isAnnouncementVideo =>
      this == announcementVideoStart || this == announcementVideoComplete;
}

bool isAnalyticsUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
).hasMatch(value);

/// One immutable observation. Retry always retains the same ID and time.
class AnalyticsObservation {
  const AnalyticsObservation({
    required this.id,
    required this.type,
    required this.observedAt,
    this.eventId,
    this.venueId,
    this.sourceEventId,
    this.announcementId,
    this.source,
    this.playbackId,
    this.impressionToken,
  });

  final String id;
  final AnalyticsObservationType type;
  final DateTime observedAt;
  final String? eventId;
  final String? venueId;
  final String? sourceEventId;
  final String? announcementId;
  final String? source;
  final String? playbackId;
  final String? impressionToken;

  bool get isValid {
    if (!isAnalyticsUuid(id)) return false;
    if (type.isAnnouncement) {
      return announcementId != null &&
          isAnalyticsUuid(announcementId!) &&
          announcementId != '00000000-0000-0000-0000-000000000000' &&
          const {'FEED', 'DIRECTORY'}.contains(source) &&
          eventId == null &&
          venueId == null &&
          sourceEventId == null &&
          (type.isAnnouncementVideo == (playbackId != null)) &&
          (playbackId == null ||
              (isAnalyticsUuid(playbackId!) &&
                  playbackId != '00000000-0000-0000-0000-000000000000')) &&
          ((source == 'FEED') == (impressionToken != null)) &&
          (impressionToken == null ||
              (impressionToken!.trim().isNotEmpty &&
                  impressionToken!.length <= 4096));
    }
    if (announcementId != null ||
        source != null ||
        playbackId != null ||
        impressionToken != null) {
      return false;
    }
    return switch (type) {
      AnalyticsObservationType.eventImpression ||
      AnalyticsObservationType.eventDetailView =>
        eventId != null &&
            isAnalyticsUuid(eventId!) &&
            venueId == null &&
            sourceEventId == null,
      AnalyticsObservationType.venueProfileView =>
        venueId != null &&
            isAnalyticsUuid(venueId!) &&
            eventId == null &&
            (sourceEventId == null || isAnalyticsUuid(sourceEventId!)),
      _ => false,
    };
  }

  Map<String, Object> toJson() => {
    'id': id,
    'type': type.wireValue,
    'observedAt': observedAt.toUtc().toIso8601String(),
    if (eventId != null) 'eventId': eventId!,
    if (venueId != null) 'venueId': venueId!,
    if (sourceEventId != null) 'sourceEventId': sourceEventId!,
    if (announcementId != null) 'announcementId': announcementId!,
    if (source != null) 'source': source!,
    if (playbackId != null) 'playbackId': playbackId!,
    if (impressionToken != null) 'impressionToken': impressionToken!,
  };

  factory AnalyticsObservation.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final wireType = json['type'];
    final observedAt = json['observedAt'];
    if (id is! String || wireType is! String || observedAt is! String) {
      throw const FormatException('Invalid stored analytics observation');
    }
    final parsed = AnalyticsObservation(
      id: id,
      type: AnalyticsObservationType.values.firstWhere(
        (value) => value.wireValue == wireType,
      ),
      observedAt: DateTime.parse(observedAt).toUtc(),
      eventId: json['eventId'] as String?,
      venueId: json['venueId'] as String?,
      sourceEventId: json['sourceEventId'] as String?,
      announcementId: json['announcementId'] as String?,
      source: json['source'] as String?,
      playbackId: json['playbackId'] as String?,
      impressionToken: json['impressionToken'] as String?,
    );
    if (!parsed.isValid) {
      throw const FormatException('Invalid stored analytics observation');
    }
    return parsed;
  }
}
