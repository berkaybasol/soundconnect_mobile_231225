import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/musician_profile_save_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/venue_profile_save_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/venue_event_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_item.dart';

void main() {
  group('profile save requests', () {
    test(
      'VenueProfileSaveRequest serializes only non-empty trimmed fields',
      () {
        const request = VenueProfileSaveRequest(
          bio: '  Venue bio  ',
          profilePicture: '  ',
          instagramUrl: 'https://instagram.com/venue',
          youtubeUrl: null,
          websiteUrl: ' https://venue.example ',
        );

        final json = request.toJson();
        expect(json['bio'], 'Venue bio');
        expect(json['instagramUrl'], 'https://instagram.com/venue');
        expect(json['websiteUrl'], 'https://venue.example');
        expect(json.containsKey('profilePicture'), isFalse);
        expect(json.containsKey('youtubeUrl'), isFalse);
      },
    );

    test('MusicianProfileSaveRequest keeps list fields and trims strings', () {
      const request = MusicianProfileSaveRequest(
        stageName: '  Artist  ',
        description: '  ',
        spotifyTrackIds: ['a', 'b'],
        spotifyTracks: [
          {'spotifyTrackId': 'a'},
        ],
        instrumentIds: ['guitar'],
      );

      final json = request.toJson();
      expect(json['stageName'], 'Artist');
      expect(json.containsKey('description'), isFalse);
      expect(json['spotifyTrackIds'], ['a', 'b']);
      expect(json['spotifyTracks'], [
        {'spotifyTrackId': 'a'},
      ]);
      expect(json['instrumentIds'], ['guitar']);
    });
  });

  group('venue event format helpers', () {
    test('formatVenueApiDate formats YYYY-MM-DD', () {
      expect(formatVenueApiDate(DateTime(2026, 4, 4)), '2026-04-04');
    });

    test('formatVenueApiTime formats HH:MM:SS', () {
      expect(
        formatVenueApiTime(const TimeOfDay(hour: 9, minute: 7)),
        '09:07:00',
      );
    });

    test(
      'formatVenueDisplayTime normalizes to HH:MM and preserves unknown',
      () {
        expect(formatVenueDisplayTime('9:7:00'), '09:07');
        expect(formatVenueDisplayTime('21:45'), '21:45');
        expect(formatVenueDisplayTime('  '), '');
        expect(formatVenueDisplayTime('invalid'), 'invalid');
      },
    );

    test('classifies events from their effective end time', () {
      final item = VenueOwnerEventItem(
        id: 'evt-1',
        title: 'Gece Sahnesi',
        posterImage: null,
        performerName: 'Luna Echo',
        musicianProfileId: null,
        eventDate: DateTime(2026, 9, 4),
        startTime: '20:00:00',
        endTime: '22:00:00',
        description: null,
      );

      expect(isVenueEventPast(item, now: DateTime(2026, 9, 4, 21)), isFalse);
      expect(isVenueEventPast(item, now: DateTime(2026, 9, 4, 23)), isTrue);
    });

    test('uses a one-hour duration when end time is missing', () {
      final item = VenueOwnerEventItem(
        id: 'evt-2',
        title: 'Akustik Set',
        posterImage: null,
        performerName: 'Luna Echo',
        musicianProfileId: null,
        eventDate: DateTime(2026, 9, 4),
        startTime: '20:00:00',
        endTime: null,
        description: null,
      );

      expect(venueEventTimelineEnd(item), DateTime(2026, 9, 4, 21));
    });

    test('does not turn equal start and end times into a 24-hour event', () {
      final item = VenueOwnerEventItem(
        id: 'evt-3',
        title: 'Kısa Set',
        posterImage: null,
        performerName: 'Luna Echo',
        musicianProfileId: null,
        eventDate: DateTime(2026, 9, 4),
        startTime: '23:00:00',
        endTime: '23:00:00',
        description: null,
      );

      expect(venueEventTimelineEnd(item), DateTime(2026, 9, 4, 23));
    });
  });

  group('VenueOwnerEventItem parsing', () {
    test('fromJson reads fields and applies sane fallbacks', () {
      final item = VenueOwnerEventItem.fromJson({
        'id': 'evt-1',
        'title': 'Acoustic Night',
        'performerName': 'Luna Echo',
        'eventDate': '2026-04-04',
        'startTime': '20:30:00',
      });

      expect(item.id, 'evt-1');
      expect(item.title, 'Acoustic Night');
      expect(item.performerName, 'Luna Echo');
      expect(item.startTime, '20:30:00');
      expect(item.eventDate.year, 2026);
      expect(item.eventDate.month, 4);
      expect(item.eventDate.day, 4);
    });

    test('fromJson defaults performerName when missing', () {
      final item = VenueOwnerEventItem.fromJson({
        'id': 'evt-2',
        'title': 'Untitled',
        'eventDate': 'bad-date',
        'startTime': '',
      });

      expect(item.performerName, 'Sanatçı');
      expect(item.eventDate, isA<DateTime>());
    });

    test(
      'fromJson clears ids that do not match an exclusive performer type',
      () {
        final pendingWithLeakedId = VenueOwnerEventItem.fromJson({
          'id': 'evt-pending',
          'performerType': 'MANUAL',
          'musicianProfileId': 'musician-unapproved',
        });
        final contradictoryBand = VenueOwnerEventItem.fromJson({
          'id': 'evt-band',
          'performerType': 'BAND',
          'bandId': 'band-1',
          'musicianProfileId': 'musician-1',
        });

        expect(pendingWithLeakedId.musicianProfileId, isNull);
        expect(pendingWithLeakedId.bandId, isNull);
        expect(contradictoryBand.musicianProfileId, isNull);
        expect(contradictoryBand.bandId, isNull);
      },
    );
  });

  group('venue event create request', () {
    test(
      'serializes a selected band without another performer field',
      () async {
        final api = _RecordingVenueEventApiClient();
        final repository = VenueEventRepositoryImpl(api);

        final result = await repository.create(
          venueId: 'venue-id',
          draft: VenueEventDraft(
            title: 'Sahbaz Gecesi',
            description: '',
            eventDate: DateTime(2026, 9, 5),
            startTime: const TimeOfDay(hour: 21, minute: 30),
            endTime: const TimeOfDay(hour: 23, minute: 0),
            posterImage: null,
            musicianProfileId: null,
            bandId: 'band-id',
            manualPerformerName: null,
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(api.lastPath, '/api/v1/venue-owner/events');
        final body = api.lastBody as Map<String, dynamic>;
        expect(body['bandId'], 'band-id');
        expect(body['musicianProfileId'], isNull);
        expect(body['manualPerformerName'], isNull);
      },
    );

    test(
      'rejects contradictory performer fields before making a request',
      () async {
        final api = _RecordingVenueEventApiClient();
        final repository = VenueEventRepositoryImpl(api);

        final result = await repository.create(
          venueId: 'venue-id',
          draft: VenueEventDraft(
            title: 'Sahbaz Gecesi',
            description: '',
            eventDate: DateTime(2026, 9, 5),
            startTime: const TimeOfDay(hour: 21, minute: 30),
            endTime: null,
            posterImage: null,
            musicianProfileId: 'musician-id',
            bandId: 'band-id',
            manualPerformerName: null,
          ),
        );

        expect(result.isSuccess, isFalse);
        expect(result.error?.code, 'venue_event_invalid_performer');
        expect(api.lastPath, isNull);
      },
    );
  });

  group('venue event detail consent boundary', () {
    test('retired musician-origin detail is rejected', () async {
      final repository = VenueEventRepositoryImpl(
        _RecordingVenueEventApiClient(
          getPayload: const <String, dynamic>{
            'id': 'event-1',
            'eventOrigin': 'MUSICIAN',
            'performerType': 'MUSICIAN',
            'musicianProfileId': 'musician-id',
          },
        ),
      );
      final result = await repository.getDetail('event-1');
      expect(result.isSuccess, isFalse);
      expect(result.error?.code, 'venue_event_detail_malformed_response');
    });

    test(
      'owner and public lists exclude retired and invalid origins',
      () async {
        final repository = VenueEventRepositoryImpl(
          _RecordingVenueEventApiClient(
            getPayload: const <Map<String, dynamic>>[
              {'id': 'legacy-venue'},
              {'id': 'venue-event', 'eventOrigin': 'VENUE'},
              {'id': 'retired-musician', 'eventOrigin': 'MUSICIAN'},
              {'id': 'invalid', 'eventOrigin': null},
            ],
          ),
        );
        for (final result in [
          await repository.listByVenue('venue'),
          await repository.listPublicByVenue('venue'),
        ]) {
          expect(result.isSuccess, isTrue);
          expect(result.data!.map((e) => e.id), [
            'legacy-venue',
            'venue-event',
          ]);
        }
      },
    );

    test('malformed bodies fail instead of creating an empty detail', () async {
      final repository = VenueEventRepositoryImpl(
        _RecordingVenueEventApiClient(getPayload: const <Object?>[]),
      );

      final result = await repository.getDetail('event-1');

      expect(result.isSuccess, isFalse);
      expect(result.error?.code, 'venue_event_detail_malformed_response');
    });

    test('detail without its requested event id fails closed', () async {
      final repository = VenueEventRepositoryImpl(
        _RecordingVenueEventApiClient(
          getPayload: const <String, dynamic>{
            'performerType': 'MUSICIAN',
            'musicianProfileId': 'musician-id',
          },
        ),
      );

      final result = await repository.getDetail('event-1');

      expect(result.isSuccess, isFalse);
      expect(result.error?.code, 'venue_event_detail_malformed_response');
    });

    test(
      'fresh detail clears a performer id that conflicts with its type',
      () async {
        final repository = VenueEventRepositoryImpl(
          _RecordingVenueEventApiClient(
            getPayload: const <String, dynamic>{
              'id': 'event-1',
              'performerType': 'MANUAL',
              'musicianProfileId': 'musician-unapproved',
            },
          ),
        );

        final result = await repository.getDetail('event-1');

        expect(result.isSuccess, isTrue);
        expect(result.data?.musicianProfileId, isNull);
        expect(result.data?.bandId, isNull);
        expect(result.data?.performerIdentity.hasLinkedProfile, isFalse);
      },
    );
  });
}

class _RecordingVenueEventApiClient extends ApiClient {
  _RecordingVenueEventApiClient({this.getPayload});

  final Object? getPayload;
  String? lastPath;
  Object? lastBody;

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) async {
    lastPath = path;
    lastBody = body;
    return decoder!(null);
  }

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) async {
    lastPath = path;
    return decoder!(getPayload);
  }

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();
}
