enum EventPerformerTargetType { musician, band }

extension EventPerformerTargetTypeX on EventPerformerTargetType {
  String get wireValue => switch (this) {
    EventPerformerTargetType.musician => 'MUSICIAN',
    EventPerformerTargetType.band => 'BAND',
  };

  String get label => switch (this) {
    EventPerformerTargetType.musician => 'Müzisyen',
    EventPerformerTargetType.band => 'Grup',
  };
}

enum EventPerformerRequestStatus { pending, accepted, rejected, cancelled }

enum EventPerformerRequestPurpose { performerConsent, profileVisibility }

class EventPerformerRequest {
  final String requestId;
  final String eventId;
  final String eventTitle;
  final String? posterImage;
  final DateTime? eventDate;
  final String? startTime;
  final String? endTime;
  final String venueId;
  final String venueName;
  final String? venueProfilePictureUrl;
  final EventPerformerTargetType targetType;
  final String targetId;
  final String? musicianProfileId;
  final String? bandId;
  final String performerName;
  final EventPerformerRequestStatus status;
  final EventPerformerRequestPurpose requestPurpose;

  /// Null only for legacy servers that cannot confirm independent publication
  /// consent. Such invitations must not be accepted with the new UI contract.
  final bool? profileCalendarApproved;

  /// Authoritative, server-clock action eligibility. Missing values belong to
  /// legacy responses and must never enable reconsidering a rejected request.
  final bool? decisionAllowed;
  final bool? canReconsider;
  final bool? expired;
  final DateTime? serverNow;
  final DateTime? eventStartsAt;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  const EventPerformerRequest({
    required this.requestId,
    required this.eventId,
    required this.eventTitle,
    this.posterImage,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.venueId,
    required this.venueName,
    required this.venueProfilePictureUrl,
    required this.targetType,
    required this.targetId,
    required this.musicianProfileId,
    required this.bandId,
    required this.performerName,
    required this.status,
    this.requestPurpose = EventPerformerRequestPurpose.performerConsent,
    this.profileCalendarApproved,
    this.decisionAllowed,
    this.canReconsider,
    this.expired,
    this.serverNow,
    this.eventStartsAt,
    required this.createdAt,
    required this.decidedAt,
  });

  bool get hasValidTargetIdentity {
    final normalizedTargetId = targetId.trim();
    final musicianId = musicianProfileId?.trim() ?? '';
    final normalizedBandId = bandId?.trim() ?? '';
    if (requestId.trim().isEmpty ||
        eventId.trim().isEmpty ||
        normalizedTargetId.isEmpty) {
      return false;
    }
    return switch (targetType) {
      EventPerformerTargetType.musician =>
        musicianId == normalizedTargetId && normalizedBandId.isEmpty,
      EventPerformerTargetType.band =>
        normalizedBandId == normalizedTargetId && musicianId.isEmpty,
    };
  }

  bool targets({EventPerformerTargetType? type, String? id}) {
    if (!hasValidTargetIdentity) return false;
    if (type != null && targetType != type) return false;
    final normalizedId = id?.trim() ?? '';
    return normalizedId.isEmpty || targetId == normalizedId;
  }
}

class EventPerformerRequestPage {
  final List<EventPerformerRequest> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;

  const EventPerformerRequestPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
  });

  bool get isOutOfRange => page > 0 && page >= totalPages;
}
