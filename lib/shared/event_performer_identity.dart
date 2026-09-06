/// A fail-closed view of the performer identity returned with an event.
///
/// A profile link is usable only when the declared performer type and the
/// corresponding id agree, and the opposite id is absent. This prevents stale
/// or malformed event payloads from making an unapproved profile navigable.
class EventPerformerIdentity {
  final String performerType;
  final String? musicianProfileId;
  final String? bandId;

  const EventPerformerIdentity._({
    required this.performerType,
    required this.musicianProfileId,
    required this.bandId,
  });

  factory EventPerformerIdentity.fromWire({
    required Object? performerType,
    required Object? musicianProfileId,
    required Object? bandId,
  }) {
    final normalizedType = performerType?.toString().trim().toUpperCase();
    final musicianId = _nonBlank(musicianProfileId);
    final normalizedBandId = _nonBlank(bandId);

    if (normalizedType == 'MUSICIAN' &&
        musicianId != null &&
        normalizedBandId == null) {
      return EventPerformerIdentity._(
        performerType: 'MUSICIAN',
        musicianProfileId: musicianId,
        bandId: null,
      );
    }
    if (normalizedType == 'BAND' &&
        normalizedBandId != null &&
        musicianId == null) {
      return EventPerformerIdentity._(
        performerType: 'BAND',
        musicianProfileId: null,
        bandId: normalizedBandId,
      );
    }

    return EventPerformerIdentity._(
      performerType: switch (normalizedType) {
        'MUSICIAN' => 'MUSICIAN',
        'BAND' => 'BAND',
        _ => 'MANUAL',
      },
      musicianProfileId: null,
      bandId: null,
    );
  }

  bool get hasLinkedProfile => musicianProfileId != null || bandId != null;

  static String? _nonBlank(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
