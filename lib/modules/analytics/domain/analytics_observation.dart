enum AnalyticsObservationType {
  eventImpression('EVENT_IMPRESSION'),
  eventDetailView('EVENT_DETAIL_VIEW'),
  venueProfileView('VENUE_PROFILE_VIEW');

  const AnalyticsObservationType(this.wireValue);
  final String wireValue;
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
  });

  final String id;
  final AnalyticsObservationType type;
  final DateTime observedAt;
  final String? eventId;
  final String? venueId;
  final String? sourceEventId;

  bool get isValid =>
      isAnalyticsUuid(id) &&
      switch (type) {
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
      };

  Map<String, Object> toJson() => {
    'id': id,
    'type': type.wireValue,
    'observedAt': observedAt.toUtc().toIso8601String(),
    if (eventId != null) 'eventId': eventId!,
    if (venueId != null) 'venueId': venueId!,
    if (sourceEventId != null) 'sourceEventId': sourceEventId!,
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
    );
    if (!parsed.isValid) {
      throw const FormatException('Invalid stored analytics observation');
    }
    return parsed;
  }
}
