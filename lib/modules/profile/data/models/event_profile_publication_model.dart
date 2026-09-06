import '../../domain/entities/event_performer_request.dart';
import '../../domain/entities/event_profile_publication.dart';

class EventProfilePublicationModel extends EventProfilePublication {
  const EventProfilePublicationModel({
    required super.eventId,
    required super.targetType,
    required super.targetId,
    required super.visible,
    required super.version,
    required super.eventTitle,
    required super.eventDate,
    required super.startTime,
    super.endTime,
    super.posterImage,
    required super.venueId,
    required super.venueName,
    required super.performerName,
  });

  // Reject versions that could lose precision on a JavaScript client. This is
  // vastly beyond a realistic number of updates to a single event preference.
  static const maxSafeVersion = 9007199254740991;
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isValidId(String value) => _uuid.hasMatch(value);

  factory EventProfilePublicationModel.fromJson(Map<String, dynamic> json) {
    final visible = json['visible'];
    final version = json['version'];
    if (visible is! bool ||
        version is! int ||
        version < 0 ||
        version > maxSafeVersion) {
      throw const FormatException('Invalid publication preference/version.');
    }
    final targetType = switch (json['targetType']) {
      'MUSICIAN' => EventPerformerTargetType.musician,
      'BAND' => EventPerformerTargetType.band,
      _ => throw const FormatException('Invalid publication target type.'),
    };
    return EventProfilePublicationModel(
      eventId: _id(json['eventId']),
      targetType: targetType,
      targetId: _id(json['targetId']),
      visible: visible,
      version: version,
      eventTitle: _string(json['eventTitle']),
      eventDate: _date(json['eventDate']),
      startTime: _time(json['startTime']),
      endTime: json['endTime'] == null ? null : _time(json['endTime']),
      posterImage: _optionalString(json['posterImage']),
      venueId: _id(json['venueId']),
      venueName: _string(json['venueName']),
      performerName: _string(json['performerName']),
    );
  }

  static String _id(Object? value) {
    final id = _string(value);
    if (!isValidId(id)) throw const FormatException('Invalid identity.');
    return id.toLowerCase();
  }

  static String _string(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Expected a nonempty string.');
    }
    return value.trim();
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Expected a string.');
    return value.trim().isEmpty ? null : value.trim();
  }

  static DateTime _date(Object? value) {
    final text = _string(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      throw const FormatException('Invalid event date.');
    }
    final date = DateTime.tryParse(text);
    if (date == null ||
        date.year < 1 ||
        date.year > 9999 ||
        '${date.year.toString().padLeft(4, '0')}-'
                '${date.month.toString().padLeft(2, '0')}-'
                '${date.day.toString().padLeft(2, '0')}' !=
            text) {
      throw const FormatException('Invalid event date.');
    }
    return date;
  }

  static String _time(Object? value) {
    final text = _string(value);
    if (!RegExp(
      r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,9})?)?$',
    ).hasMatch(text)) {
      throw const FormatException('Invalid event time.');
    }
    return text;
  }
}
