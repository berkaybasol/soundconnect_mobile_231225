import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/event_profile_publication_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';

Map<String, dynamic> _json() => {
  'eventId': '11111111-1111-4111-8111-111111111111',
  'targetType': 'MUSICIAN',
  'targetId': '33333333-3333-4333-8333-333333333333',
  'visible': false,
  'version': 0,
  'eventTitle': 'Eylül Akşamı',
  'eventDate': '2026-09-06',
  'startTime': '20:00:00',
  'endTime': '22:00:00',
  'posterImage': null,
  'venueId': '55555555-5555-4555-8555-555555555555',
  'venueName': 'soundconnectankara',
  'performerName': 'bugrasahin',
};

void main() {
  test(
    'publication contract parses independent hidden choice without defaults',
    () {
      final item = EventProfilePublicationModel.fromJson(_json());
      expect(item.targetType, EventPerformerTargetType.musician);
      expect(item.visible, isFalse);
      expect(item.version, 0);
      expect(item.eventDate, DateTime(2026, 9, 6));
      expect(item.startTime, '20:00:00');
      expect(item.endTime, '22:00:00');
      expect(item.posterImage, isNull);
      expect(item.eventTitle, 'Eylül Akşamı');
      expect(item.venueName, 'soundconnectankara');
      expect(item.performerName, 'bugrasahin');
    },
  );

  test('band contract and only documented optional fields are supported', () {
    final json = {
      ..._json(),
      'targetType': 'BAND',
      'targetId': 'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA',
      'endTime': null,
      'posterImage': ' https://cdn.example.com/event.jpg ',
    };
    final item = EventProfilePublicationModel.fromJson(json);
    expect(item.targetType, EventPerformerTargetType.band);
    expect(item.targetId, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    expect(item.endTime, isNull);
    expect(item.posterImage, 'https://cdn.example.com/event.jpg');
  });

  for (final field in [
    'eventId',
    'targetType',
    'targetId',
    'visible',
    'version',
    'eventTitle',
    'eventDate',
    'startTime',
    'venueId',
    'venueName',
    'performerName',
  ]) {
    test('missing required $field fails closed', () {
      final json = _json()..remove(field);
      expect(
        () => EventProfilePublicationModel.fromJson(json),
        throwsFormatException,
      );
    });
  }

  final invalid = <String, Object?>{
    'visible': 'false',
    'version': -1,
    'targetType': 'VENUE',
    'eventId': '../other',
    'targetId': 'not-a-uuid',
    'venueId': 42,
    'eventTitle': ' ',
    'venueName': false,
    'performerName': <Object>[],
    'eventDate': '2026-02-30',
    'startTime': '24:00',
    'endTime': '22:60:00',
    'posterImage': 1,
  };
  for (final entry in invalid.entries) {
    test('invalid ${entry.key} fails closed', () {
      expect(
        () => EventProfilePublicationModel.fromJson({
          ..._json(),
          entry.key: entry.value,
        }),
        throwsFormatException,
      );
    });
  }

  for (final version in <Object>['0', 0.0, 9007199254740992]) {
    test('non-exact integer version $version fails closed', () {
      expect(
        () => EventProfilePublicationModel.fromJson({
          ..._json(),
          'version': version,
        }),
        throwsFormatException,
      );
    });
  }

  for (final date in [
    '0000-01-01',
    '2026-13-01',
    '2026-09-06T00:00:00',
    '2026-9-6',
  ]) {
    test('noncanonical date $date is rejected', () {
      expect(
        () => EventProfilePublicationModel.fromJson({
          ..._json(),
          'eventDate': date,
        }),
        throwsFormatException,
      );
    });
  }

  for (final time in ['20:00', '20:00:00', '20:00:00.123456789']) {
    test('backend LocalTime serialization $time is supported', () {
      final item = EventProfilePublicationModel.fromJson({
        ..._json(),
        'startTime': time,
        'endTime': null,
      });
      expect(item.startTime, time);
    });
  }

  test('leap day is preserved and blank optional poster becomes null', () {
    final item = EventProfilePublicationModel.fromJson({
      ..._json(),
      'eventDate': '2028-02-29',
      'posterImage': '  ',
    });
    expect(item.eventDate, DateTime(2028, 2, 29));
    expect(item.posterImage, isNull);
  });
}
