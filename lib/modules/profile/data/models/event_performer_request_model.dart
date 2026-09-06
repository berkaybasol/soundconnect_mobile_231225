import '../../domain/entities/event_performer_request.dart';

class EventPerformerRequestModel extends EventPerformerRequest {
  const EventPerformerRequestModel({
    required super.requestId,
    required super.eventId,
    required super.eventTitle,
    super.posterImage,
    required super.eventDate,
    required super.startTime,
    required super.endTime,
    required super.venueId,
    required super.venueName,
    required super.venueProfilePictureUrl,
    required super.targetType,
    required super.targetId,
    required super.musicianProfileId,
    required super.bandId,
    required super.performerName,
    required super.status,
    super.requestPurpose,
    super.profileCalendarApproved,
    super.decisionAllowed,
    super.canReconsider,
    super.expired,
    super.serverNow,
    super.eventStartsAt,
    required super.createdAt,
    required super.decidedAt,
  });

  factory EventPerformerRequestModel.fromJson(Map<String, dynamic> json) {
    final explicitTargetType = _nonBlank(json['targetType']);
    final performerType = _nonBlank(json['performerType']);
    final targetType = _parseTargetType(explicitTargetType ?? performerType);
    if (explicitTargetType != null &&
        performerType != null &&
        _parseTargetType(performerType) != targetType) {
      throw const FormatException('Performer type aliases disagree.');
    }
    final musicianProfileId = _nonBlank(json['musicianProfileId']);
    final bandId = _nonBlank(json['bandId']);
    final explicitTargetId = _nonBlank(json['targetId']);
    final requestId = _nonBlank(json['requestId']);
    final legacyRequestId = _nonBlank(json['id']);
    if (requestId != null &&
        legacyRequestId != null &&
        requestId != legacyRequestId) {
      throw const FormatException('Request id aliases disagree.');
    }
    final targetId = switch (targetType) {
      EventPerformerTargetType.musician => _validatedTargetId(
        expectedId: musicianProfileId,
        forbiddenId: bandId,
        explicitTargetId: explicitTargetId,
      ),
      EventPerformerTargetType.band => _validatedTargetId(
        expectedId: bandId,
        forbiddenId: musicianProfileId,
        explicitTargetId: explicitTargetId,
      ),
    };

    final status = _parseStatus(json['status']);
    final decisionAllowed = _optionalBoolean(json, 'decisionAllowed');
    final canReconsider = _optionalBoolean(json, 'canReconsider');
    final expired = _optionalBoolean(json, 'expired');
    if ((decisionAllowed == true &&
            status != EventPerformerRequestStatus.pending) ||
        (canReconsider == true &&
            status != EventPerformerRequestStatus.rejected) ||
        (expired == true &&
            (decisionAllowed == true || canReconsider == true))) {
      throw const FormatException(
        'Request action eligibility is inconsistent.',
      );
    }

    return EventPerformerRequestModel(
      requestId: requestId ?? legacyRequestId ?? '',
      eventId: _nonBlank(json['eventId']) ?? '',
      eventTitle: _nonBlank(json['eventTitle']) ?? 'Etkinlik',
      posterImage: json['posterImage'] is String
          ? _nonBlank(json['posterImage'])
          : null,
      eventDate: DateTime.tryParse(json['eventDate']?.toString() ?? ''),
      startTime: _nonBlank(json['startTime']),
      endTime: _nonBlank(json['endTime']),
      venueId: _nonBlank(json['venueId']) ?? '',
      venueName: _nonBlank(json['venueName']) ?? 'Mekan',
      venueProfilePictureUrl: _firstNonBlank(json, const [
        'venueProfilePictureUrl',
        'venueProfilePicture',
        'venueImageUrl',
      ]),
      targetType: targetType,
      targetId: targetId,
      musicianProfileId: musicianProfileId,
      bandId: bandId,
      performerName:
          _nonBlank(json['performerName']) ??
          (targetType == EventPerformerTargetType.band ? 'Grup' : 'Müzisyen'),
      status: status,
      requestPurpose: json.containsKey('requestPurpose')
          ? _parsePurpose(json['requestPurpose'])
          : EventPerformerRequestPurpose.performerConsent,
      profileCalendarApproved: json.containsKey('profileCalendarApproved')
          ? _parseProfileApproval(json['profileCalendarApproved'])
          : null,
      decisionAllowed: decisionAllowed,
      canReconsider: canReconsider,
      expired: expired,
      serverNow: _optionalInstant(json, 'serverNow'),
      eventStartsAt: _optionalInstant(json, 'eventStartsAt'),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      decidedAt: DateTime.tryParse(json['decidedAt']?.toString() ?? ''),
    );
  }

  static bool _parseProfileApproval(Object? value) {
    if (value is! bool) {
      throw const FormatException('Invalid profile publication approval.');
    }
    return value;
  }

  static bool? _optionalBoolean(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) return null;
    final value = json[key];
    if (value is! bool) throw FormatException('Invalid $key flag.');
    return value;
  }

  static DateTime? _optionalInstant(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) return null;
    final value = json[key];
    if (value is! String) throw FormatException('Invalid $key timestamp.');
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?(?:Z|[+-](\d{2}):(\d{2}))$',
    ).firstMatch(value);
    if (match == null) throw FormatException('Unzoned $key timestamp.');
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final calendarDate = DateTime.utc(year, month, day);
    if (calendarDate.year != year ||
        calendarDate.month != month ||
        calendarDate.day != day ||
        int.parse(match[4]!) > 23 ||
        int.parse(match[5]!) > 59 ||
        int.parse(match[6]!) > 59 ||
        (match[7] != null && int.parse(match[7]!) > 23) ||
        (match[8] != null && int.parse(match[8]!) > 59)) {
      throw FormatException('Invalid $key timestamp components.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('Invalid $key timestamp.');
    return parsed.toUtc();
  }

  static String? _nonBlank(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static String? _firstNonBlank(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = _nonBlank(json[key]);
      if (value != null) return value;
    }
    return null;
  }

  static String _validatedTargetId({
    required String? expectedId,
    required String? forbiddenId,
    required String? explicitTargetId,
  }) {
    if (expectedId == null || forbiddenId != null) {
      throw const FormatException('Performer target identity is invalid.');
    }
    if (explicitTargetId != null && explicitTargetId != expectedId) {
      throw const FormatException('Performer target ids disagree.');
    }
    return expectedId;
  }

  static EventPerformerTargetType _parseTargetType(Object? raw) {
    return switch (raw?.toString().trim().toUpperCase()) {
      'MUSICIAN' => EventPerformerTargetType.musician,
      'BAND' => EventPerformerTargetType.band,
      _ => throw const FormatException('Unknown performer target type.'),
    };
  }

  static EventPerformerRequestStatus _parseStatus(Object? raw) {
    return switch (raw?.toString().trim().toUpperCase()) {
      'PENDING' => EventPerformerRequestStatus.pending,
      'ACCEPTED' => EventPerformerRequestStatus.accepted,
      'REJECTED' => EventPerformerRequestStatus.rejected,
      'CANCELLED' || 'CANCELED' => EventPerformerRequestStatus.cancelled,
      _ => throw const FormatException('Unknown performer request status.'),
    };
  }

  static EventPerformerRequestPurpose _parsePurpose(Object? raw) {
    if (raw is! String) {
      throw const FormatException('Invalid performer request purpose.');
    }
    return switch (raw.trim().toUpperCase()) {
      'PERFORMER_CONSENT' => EventPerformerRequestPurpose.performerConsent,
      'PROFILE_VISIBILITY' => EventPerformerRequestPurpose.profileVisibility,
      _ => throw const FormatException('Unknown performer request purpose.'),
    };
  }
}
