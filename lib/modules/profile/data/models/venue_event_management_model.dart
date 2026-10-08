import '../../domain/entities/venue_event_item.dart';
import '../../domain/entities/venue_event_management.dart';

/// Strict decoders for the bounded owner-management endpoints. The legacy
/// public event decoder remains compatible with its older wire format.
abstract final class VenueEventManagementModel {
  static const pageSize = 20;
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final _cursor = RegExp(r'^[A-Za-z0-9_-]+={0,2}$');
  static final _time = RegExp(
    r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,9})?)?$',
  );

  static bool isValidVenueId(String value) => _uuid.hasMatch(value);
  static bool isValidCursor(String value) =>
      value.length <= 512 && _cursor.hasMatch(value);

  static VenueEventManagementSnapshot snapshot(Object? raw, String venueId) {
    final json = _object(raw);
    final count = json['pastCount'];
    if (count is! int || count < 0 || count > 9007199254740991) {
      throw const FormatException('Invalid history count.');
    }
    return VenueEventManagementSnapshot(
      upcomingEvents: _items(json['upcomingEvents'], venueId),
      pastCount: count,
      historyAsOf: _instant(json['historyAsOf']),
    );
  }

  static VenueEventHistoryPage history(
    Object? raw,
    String venueId, {
    String? requestedCursor,
  }) {
    final json = _object(raw);
    final items = _items(json['items'], venueId, maxItems: pageSize);
    final hasNext = json['hasNext'];
    final cursor = json['nextCursor'];
    if (hasNext is! bool ||
        (hasNext
            ? cursor is! String ||
                  !isValidCursor(cursor) ||
                  cursor == requestedCursor ||
                  items.length != pageSize
            : cursor != null)) {
      throw const FormatException('Invalid history pagination.');
    }
    return VenueEventHistoryPage(
      items: items,
      nextCursor: cursor as String?,
      hasNext: hasNext,
    );
  }

  static List<VenueOwnerEventItem> _items(
    Object? raw,
    String venueId, {
    int? maxItems,
  }) {
    if (raw is! List || (maxItems != null && raw.length > maxItems)) {
      throw const FormatException('Invalid event list.');
    }
    final ids = <String>{};
    final items = <VenueOwnerEventItem>[];
    for (final value in raw) {
      final json = _object(value);
      final id = _id(json['id']);
      if (!ids.add(id) ||
          _id(json['venueId']) != venueId ||
          json['eventOrigin'] != 'VENUE' ||
          !const [
            'NOT_REQUIRED',
            'PENDING',
            'APPROVED',
            'REJECTED',
          ].contains(json['venueApprovalStatus']) ||
          json['venueCalendarApproved'] is! bool) {
        throw const FormatException('Event identity or venue scope disagrees.');
      }
      _text(json['title']);
      _text(json['performerName']);
      _date(json['eventDate']);
      // Private owner history includes legacy events without a start time;
      // the server classifies these at the end of their calendar day.
      if (json['startTime'] != null) _eventTime(json['startTime']);
      if (json['endTime'] != null) _eventTime(json['endTime']);
      for (final field in [
        'posterImage',
        'description',
        'venueName',
        'venueCity',
        'venueDistrict',
        'venueNeighborhood',
      ]) {
        if (json[field] != null && json[field] is! String) {
          throw const FormatException('Invalid optional event text.');
        }
      }
      final musician = json['musicianProfileId'];
      final band = json['bandId'];
      if (musician != null) _id(musician);
      if (band != null) _id(band);
      final validPerformer = switch (json['performerType']) {
        'MUSICIAN' => musician != null && band == null,
        'BAND' => band != null && musician == null,
        'MANUAL' || null => musician == null && band == null,
        _ => false,
      };
      if (!validPerformer) {
        throw const FormatException('Ambiguous event performer.');
      }
      items.add(
        VenueOwnerEventItem.fromJson({...json, 'id': id, 'venueId': venueId}),
      );
    }
    return List.unmodifiable(items);
  }

  static Map<String, dynamic> _object(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Expected an owner event object.');
    }
    return raw;
  }

  static String _text(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) {
      throw const FormatException('Expected event text.');
    }
    return raw;
  }

  static String _id(Object? raw) {
    final id = _text(raw);
    if (!_uuid.hasMatch(id)) {
      throw const FormatException('Invalid event identity.');
    }
    return id.toLowerCase();
  }

  static DateTime _date(Object? raw) {
    final text = _text(raw);
    final date = DateTime.tryParse(text);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
        date == null ||
        date.year < 1 ||
        formatVenueApiDate(date) != text) {
      throw const FormatException('Invalid event date.');
    }
    return date;
  }

  static void _eventTime(Object? raw) {
    if (!_time.hasMatch(_text(raw))) {
      throw const FormatException('Invalid event time.');
    }
  }

  static DateTime _instant(Object? raw) {
    final text = _text(raw);
    final instant = DateTime.tryParse(text);
    if (!RegExp(
          r'^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d{1,9})?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)$',
        ).hasMatch(text) ||
        instant == null ||
        !instant.isUtc) {
      throw const FormatException('Invalid history boundary.');
    }
    _date(text.substring(0, 10));
    return instant;
  }
}
