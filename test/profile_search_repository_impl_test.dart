import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/profile_search_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_search_result.dart';

import 'support/recording_api_client.dart';

void main() {
  test(
    'performer search sends a deterministic musician and band scope',
    () async {
      final client = RecordingApiClient(
        (_) => [
          {
            'type': 'BAND',
            'targetId': 'band-id',
            'title': 'Şahbaz',
            'subtitle': 'Band',
          },
        ],
      );
      final repository = ProfileSearchRepositoryImpl(client);

      final result = await repository.searchProfiles(
        'sah',
        types: const {
          ProfileSearchResultType.musician,
          ProfileSearchResultType.band,
        },
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.single.title, 'Şahbaz');
      expect(client.lastRequest.path, '/api/v1/public/search/profiles');
      expect(client.lastRequest.query, {
        'q': 'sah',
        'limit': 20,
        'types': 'BAND,MUSICIAN',
      });
    },
  );

  test('global search leaves the type filter absent', () async {
    final client = RecordingApiClient((_) => const <Object?>[]);
    final repository = ProfileSearchRepositoryImpl(client);

    await repository.searchProfiles('ankara');

    expect(client.lastRequest.query, {'q': 'ankara', 'limit': 20});
  });

  test(
    'malformed search payload is a failure instead of an empty result',
    () async {
      final client = RecordingApiClient(
        (_) => <String, dynamic>{'content': const <Object?>[]},
      );
      final repository = ProfileSearchRepositoryImpl(client);

      final result = await repository.searchProfiles('sah');

      expect(result.isSuccess, isFalse);
      expect(result.error?.code, 'profile_search_malformed_response');
    },
  );

  test(
    'typed performer search trims ids and ignores out-of-scope profiles',
    () async {
      final client = RecordingApiClient(
        (_) => <Object?>[
          <String, dynamic>{
            'type': 'VENUE',
            'targetId': 'venue-id',
            'title': 'Mekan',
          },
          <String, dynamic>{
            'type': 'BAND',
            'targetId': ' band-id ',
            'title': ' Şahbaz ',
          },
        ],
      );
      final repository = ProfileSearchRepositoryImpl(client);

      final result = await repository.searchProfiles(
        ' sah ',
        types: const {
          ProfileSearchResultType.musician,
          ProfileSearchResultType.band,
        },
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, hasLength(1));
      expect(result.data!.single.targetId, 'band-id');
      expect(result.data!.single.title, 'Şahbaz');
      expect(client.lastRequest.query?['q'], 'sah');
    },
  );

  test(
    'performer search fails closed on an item without a trusted identity',
    () async {
      final client = RecordingApiClient(
        (_) => <Object?>[
          <String, dynamic>{'type': 'BAND', 'targetId': ' ', 'title': 'Şahbaz'},
        ],
      );
      final repository = ProfileSearchRepositoryImpl(client);

      final result = await repository.searchProfiles(
        'sah',
        types: const {ProfileSearchResultType.band},
      );

      expect(result.isSuccess, isFalse);
      expect(result.error?.code, 'profile_search_malformed_response');
    },
  );
}
