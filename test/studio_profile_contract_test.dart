import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/studio_profile_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/studio_profile_repository.dart';

void main() {
  test(
    'Studio profile parses version, timezone and ordered Spotify catalog',
    () {
      final profile = StudioProfileModel.fromJson({
        'id': 'studio-1',
        'userId': 'user-1',
        'name': 'Studio',
        'adress': 'Kadikoy',
        'cityId': 'city-1',
        'cityName': 'İstanbul',
        'districtId': 'district-1',
        'districtName': 'Kadıköy',
        'neighborhoodId': 'neighborhood-1',
        'neighborhoodName': 'Moda',
        'timeZone': 'Europe/Istanbul',
        'version': 7,
        'activeRoomCount': 3,
        'backlineUnitCount': 42,
        'facilities': ['Akustik izolasyon'],
        'spotifyTrackIds': ['track-2', 'track-1'],
        'spotifyTracks': [
          {
            'spotifyTrackId': 'track-2',
            'name': 'Second',
            'durationMs': 120000,
            'artistNames': ['Artist'],
          },
          {
            'spotifyTrackId': 'track-1',
            'name': 'First',
            'durationMs': 180000,
            'artistNames': ['Artist'],
          },
        ],
      });

      expect(profile.address, 'Kadikoy');
      expect(profile.cityName, 'İstanbul');
      expect(profile.districtName, 'Kadıköy');
      expect(profile.neighborhoodName, 'Moda');
      expect(profile.timeZone, 'Europe/Istanbul');
      expect(profile.version, 7);
      expect(profile.activeRoomCount, 3);
      expect(profile.backlineUnitCount, 42);
      expect(profile.facilities, ['Akustik izolasyon']);
      expect(profile.spotifyTrackIds, ['track-2', 'track-1']);
      expect(profile.spotifyTracks, hasLength(2));
      expect(profile.spotifyTracks[0].id, 'track-2');
      expect(profile.spotifyTracks[0].durationSeconds, 120);
      expect(profile.spotifyTracks[1].id, 'track-1');
      expect(profile.spotifyTracks[1].durationSeconds, 180);
    },
  );

  test('Studio profile rejects missing mandatory server metadata', () {
    expect(
      () => StudioProfileModel.fromJson({
        'id': 'studio-1',
        'userId': 'user-1',
        'timeZone': 'Europe/Istanbul',
        'version': 0,
        'activeRoomCount': 0,
        'facilities': const <String>[],
        'spotifyTrackIds': const <String>[],
        'spotifyTracks': const <Object?>[],
      }),
      throwsFormatException,
    );
  });

  test('Studio profile rejects malformed collection elements', () {
    for (final malformed in <Map<String, Object?>>[
      _validProfileJson()..['facilities'] = <Object?>['Akustik', 42],
      _validProfileJson()
        ..['spotifyTrackIds'] = <Object?>[
          {'id': 'track-1'},
        ],
      _validProfileJson()..['spotifyTracks'] = <Object?>['track-1'],
      _validProfileJson()
        ..['spotifyTrackIds'] = <String>['track-1']
        ..['spotifyTracks'] = <Object?>[
          {'spotifyTrackId': '   '},
        ],
      _validProfileJson()
        ..['spotifyTrackIds'] = <String>['42']
        ..['spotifyTracks'] = <Object?>[
          {'spotifyTrackId': 42},
        ],
      _validProfileJson()
        ..['spotifyTrackIds'] = <String>['track-1']
        ..['spotifyTracks'] = <Object?>[
          {
            'spotifyTrackId': 'track-1',
            'artistNames': <Object?>['Artist', 42],
          },
        ],
    ]) {
      expect(
        () => StudioProfileModel.fromJson(malformed),
        throwsFormatException,
      );
    }
  });

  test('Studio profile rejects non-string fields and object keys', () {
    for (final malformed in <Object?>[
      _validProfileJson()..['id'] = 42,
      _validProfileJson()..['name'] = false,
      <Object?, Object?>{..._validProfileJson(), 42: 'non-string JSON key'},
      _validProfileJson()..['version'] = '0',
    ]) {
      expect(
        () => StudioProfileModel.fromJson(malformed),
        throwsFormatException,
      );
    }
  });

  test('Studio profile rejects unsafe contact URLs and phone payloads', () {
    for (final malformed in <Map<String, Object?>>[
      _validProfileJson()..['website'] = 'javascript:alert(1)',
      _validProfileJson()..['instagramUrl'] = 'instagram.com/studio',
      _validProfileJson()..['profilePictureUrl'] = 'file:///tmp/avatar.jpg',
      _validProfileJson()..['phone'] = '555;postd=1234',
    ]) {
      expect(
        () => StudioProfileModel.fromJson(malformed),
        throwsFormatException,
      );
    }
  });

  test(
    'Studio save request preserves optimistic version and Spotify payload',
    () {
      final request = StudioProfileSaveRequest(
        version: 4,
        spotifyTrackIds: const ['track-1'],
        spotifyTracks: const [
          {'spotifyTrackId': 'track-1', 'name': 'Track'},
        ],
      );

      expect(request.toJson(), {
        'version': 4,
        'spotifyTrackIds': ['track-1'],
        'spotifyTracks': [
          {'spotifyTrackId': 'track-1', 'name': 'Track'},
        ],
      });
      expect(request.copyWithVersion(5).version, 5);
    },
  );
}

Map<String, Object?> _validProfileJson() => {
  'id': 'studio-1',
  'userId': 'user-1',
  'timeZone': 'Europe/Istanbul',
  'version': 0,
  'activeRoomCount': 0,
  'backlineUnitCount': 0,
  'facilities': <String>[],
  'spotifyTrackIds': <String>[],
  'spotifyTracks': <Object?>[],
};
