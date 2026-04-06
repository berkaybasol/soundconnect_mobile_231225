import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/musician_profile_save_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/venue_profile_save_request.dart';
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

      expect(item.performerName, 'Sanatci');
      expect(item.eventDate, isA<DateTime>());
    });
  });
}
