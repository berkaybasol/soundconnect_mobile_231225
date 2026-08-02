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
        'spotifyTrackIds': ['track-2', 'track-1'],
        'spotifyTracks': [
          {
            'spotifyTrackId': 'track-2',
            'name': 'Second',
            'durationMs': 120000,
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
      expect(profile.spotifyTrackIds, ['track-2', 'track-1']);
      expect(profile.spotifyTracks.single.id, 'track-2');
      expect(profile.spotifyTracks.single.durationSeconds, 120);
    },
  );

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
