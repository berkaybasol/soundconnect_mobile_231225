import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/data/instrument_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/data/instrument_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/data/models/instrument_model.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/entities/instrument.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/instrument_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/presentation/cubit/instrument_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/presentation/cubit/instrument_state.dart';
import 'package:soundconnect_23_12_25codx/modules/location/data/location_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/location/data/location_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/location/data/models/city_model.dart';
import 'package:soundconnect_23_12_25codx/modules/location/data/models/district_model.dart';
import 'package:soundconnect_23_12_25codx/modules/location/data/models/neighborhood_model.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/district.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/neighborhood.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/location/presentation/cubit/location_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/data/models/spotify_track_preview_model.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/data/spotify_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/data/spotify_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/domain/entities/spotify_track_preview.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/domain/spotify_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/presentation/cubit/spotify_preview_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/presentation/cubit/spotify_preview_state.dart';

import 'support/recording_api_client.dart';

void main() {
  group('location models and repository', () {
    test('models use safe defaults and map cleanly to domain entities', () {
      final city = CityModel.fromJson(<String, dynamic>{});
      final district = DistrictModel.fromJson(<String, dynamic>{
        'id': 'district-1',
        'name': 'Kadikoy',
        'cityId': 'city-1',
      });
      final neighborhood = NeighborhoodModel.fromJson(<String, dynamic>{
        'id': 'neighborhood-1',
        'name': 'Moda',
        'districtId': 'district-1',
      });

      expect(city.toEntity().id, isEmpty);
      expect(city.toEntity().name, isEmpty);
      expect(district.toEntity().cityId, 'city-1');
      expect(neighborhood.toEntity().districtId, 'district-1');
    });

    test('decodes the city hierarchy and uses each parent endpoint', () async {
      final client = RecordingApiClient((request) {
        return switch (request.path) {
          LocationEndpoints.getAllCities => <Map<String, dynamic>>[
            <String, dynamic>{'id': 'city-1', 'name': 'Istanbul'},
          ],
          '/api/v1/districts/get-by-city/city-1' => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'district-1',
              'name': 'Kadikoy',
              'cityId': 'city-1',
            },
          ],
          '/api/v1/neighborhoods/get-by-district/district-1' =>
            <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'neighborhood-1',
                'name': 'Moda',
                'districtId': 'district-1',
              },
            ],
          _ => throw StateError('Unexpected path: ${request.path}'),
        };
      });
      final repository = LocationRepositoryImpl(client);

      final cities = await repository.getCities();
      final districts = await repository.getDistricts('city-1');
      final neighborhoods = await repository.getNeighborhoods('district-1');

      expect(cities.data?.single.name, 'Istanbul');
      expect(districts.data?.single.cityId, 'city-1');
      expect(neighborhoods.data?.single.districtId, 'district-1');
      expect(client.requests.map((request) => request.path), <String>[
        LocationEndpoints.getAllCities,
        LocationEndpoints.getDistrictsByCity('city-1'),
        LocationEndpoints.getNeighborhoodsByDistrict('district-1'),
      ]);
    });

    test(
      'sorts every location level with Turkish alphabetical rules',
      () async {
        final client = RecordingApiClient((request) {
          return switch (request.path) {
            LocationEndpoints.getAllCities => <Map<String, dynamic>>[
              <String, dynamic>{'id': 'city-5', 'name': 'Üsküdar'},
              <String, dynamic>{'id': 'city-4', 'name': 'İstanbul'},
              <String, dynamic>{'id': 'city-3', 'name': 'Iğdır'},
              <String, dynamic>{'id': 'city-2', 'name': 'Çankaya'},
              <String, dynamic>{'id': 'city-1', 'name': 'Ceyhan'},
            ],
            '/api/v1/districts/get-by-city/city-1' => <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'district-5',
                'name': 'Şişli',
                'cityId': 'city-1',
              },
              <String, dynamic>{
                'id': 'district-4',
                'name': 'İstanbul',
                'cityId': 'city-1',
              },
              <String, dynamic>{
                'id': 'district-3',
                'name': 'Iğdır',
                'cityId': 'city-1',
              },
              <String, dynamic>{
                'id': 'district-2',
                'name': 'Çankaya',
                'cityId': 'city-1',
              },
              <String, dynamic>{
                'id': 'district-1',
                'name': 'Ceyhan',
                'cityId': 'city-1',
              },
            ],
            '/api/v1/neighborhoods/get-by-district/district-1' =>
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'neighborhood-5',
                  'name': 'Ödemiş',
                  'districtId': 'district-1',
                },
                <String, dynamic>{
                  'id': 'neighborhood-4',
                  'name': 'Osmangazi',
                  'districtId': 'district-1',
                },
                <String, dynamic>{
                  'id': 'neighborhood-3',
                  'name': '100. Yıl',
                  'districtId': 'district-1',
                },
                <String, dynamic>{
                  'id': 'neighborhood-2',
                  'name': '10 Ekim',
                  'districtId': 'district-1',
                },
                <String, dynamic>{
                  'id': 'neighborhood-1',
                  'name': '2 Eylül',
                  'districtId': 'district-1',
                },
              ],
            _ => throw StateError('Unexpected path: ${request.path}'),
          };
        });
        final repository = LocationRepositoryImpl(client);

        final cities = await repository.getCities();
        final districts = await repository.getDistricts('city-1');
        final neighborhoods = await repository.getNeighborhoods('district-1');

        expect(cities.data!.map((city) => city.name), <String>[
          'Ceyhan',
          'Çankaya',
          'Iğdır',
          'İstanbul',
          'Üsküdar',
        ]);
        expect(districts.data!.map((district) => district.name), <String>[
          'Ceyhan',
          'Çankaya',
          'Iğdır',
          'İstanbul',
          'Şişli',
        ]);
        expect(
          neighborhoods.data!.map((neighborhood) => neighborhood.name),
          <String>['2 Eylül', '10 Ekim', '100. Yıl', 'Osmangazi', 'Ödemiş'],
        );
      },
    );

    test(
      'LocationCubit clears dependent selections and stale errors',
      () async {
        const failure = AppError(code: 'cities_failed', message: 'Unavailable');
        final repository = _LocationRepositoryFake();
        final cubit = LocationCubit(repository);

        await cubit.loadDistricts('city-1');
        await cubit.loadNeighborhoods('district-1');
        repository.citiesResult = const Result.failure(failure);
        await cubit.loadCities();
        expect(cubit.state.error, same(failure));

        cubit.resetDistricts();

        expect(cubit.state.districts, isEmpty);
        expect(cubit.state.neighborhoods, isEmpty);
        expect(cubit.state.error, isNull);
        await cubit.close();
      },
    );
  });

  group('instrument boundaries', () {
    test('model coerces identifiers and names from scalar JSON values', () {
      final model = InstrumentModel.fromJson(<String, dynamic>{
        'id': 17,
        'name': 808,
      });

      expect(model.id, '17');
      expect(model.name, '808');
    });

    test(
      'repository preserves typed errors and cubit exposes failure state',
      () async {
        const error = AppError(code: '403', message: 'Forbidden');
        final repository = InstrumentRepositoryImpl(
          RecordingApiClient((request) {
            expect(request.path, InstrumentEndpoints.list);
            throw ApiException(error);
          }),
        );
        final result = await repository.getAll();
        expect(result.error, same(error));

        final cubit = InstrumentCubit(
          _InstrumentRepositoryFake(const Result.failure(error)),
        );
        final expectation = expectLater(
          cubit.stream,
          emitsInOrder(<Matcher>[
            isA<InstrumentState>().having(
              (state) => state.status,
              'loading status',
              InstrumentStatus.loading,
            ),
            isA<InstrumentState>()
                .having(
                  (state) => state.status,
                  'failure status',
                  InstrumentStatus.failure,
                )
                .having((state) => state.error, 'typed error', same(error)),
          ]),
        );
        await cubit.loadAll();
        await expectation;

        expect(cubit.state.error, same(error));
        await cubit.close();
      },
    );
  });

  group('Spotify JSON, repository, and cubit boundaries', () {
    test('track model normalizes duration and nested artist objects', () {
      final track = SpotifyTrackPreviewModel.fromJson(<String, dynamic>{
        'spotifyTrackId': 123,
        'name': 'Night Drive',
        'durationMs': 245600,
        'artists': <Map<String, dynamic>>[
          <String, dynamic>{'id': 9, 'name': 'Ada'},
          <String, dynamic>{'spotifyArtistId': 'artist-2', 'name': 'Bora'},
        ],
      });

      expect(track.id, '123');
      expect(track.durationSeconds, 246);
      expect(track.artistNames, <String>['Ada', 'Bora']);
      expect(track.artistIds, <String>['9', 'artist-2']);
      expect(track.toJson()['durationMs'], 246000);
    });

    test('distinguishes millisecond and second duration fields exactly', () {
      final fromMilliseconds = SpotifyTrackPreviewModel.fromJson(
        <String, dynamic>{'id': 'track-ms', 'durationMs': 1000},
      );
      final fromSeconds = SpotifyTrackPreviewModel.fromJson(<String, dynamic>{
        'id': 'track-seconds',
        'durationSeconds': 1000,
      });

      expect(fromMilliseconds.durationSeconds, 1);
      expect(fromSeconds.durationSeconds, 1000);
    });

    test(
      'search accepts nested items and by-ids sends an explicit ID body',
      () async {
        final client = RecordingApiClient((request) {
          if (request.method == RecordedHttpMethod.get) {
            return <String, dynamic>{
              'tracks': <String, dynamic>{
                'items': <Object?>[
                  <String, dynamic>{
                    'id': 'track-1',
                    'name': 'One',
                    'durationSeconds': 30,
                    'artistNames': <String>['Ada'],
                  },
                  'bad-row',
                ],
              },
            };
          }
          return <Map<String, dynamic>>[
            <String, dynamic>{
              'spotifyTrackId': 'track-2',
              'name': 'Two',
              'durationMs': 120000,
            },
          ];
        });
        final repository = SpotifyRepositoryImpl(client);

        final search = await repository.searchTracks('night', limit: 7);
        final byIds = await repository.getTracksByIds(<String>['track-2']);

        expect(search.data?.single.id, 'track-1');
        expect(client.requests.first.path, SpotifyEndpoints.searchTracks);
        expect(client.requests.first.query, <String, dynamic>{
          'q': 'night',
          'limit': 7,
        });
        expect(byIds.data?.single.durationSeconds, 120);
        expect(client.lastRequest.path, SpotifyEndpoints.tracksByIds);
        expect(client.lastRequest.body, <String, dynamic>{
          'ids': <String>['track-2'],
        });
      },
    );

    test(
      'SpotifyPreviewCubit replaces stale error on a successful search',
      () async {
        const failure = AppError(code: 'spotify_down', message: 'Unavailable');
        final repository = _SpotifyRepositoryFake();
        final cubit = SpotifyPreviewCubit(repository);

        repository.byIdsResult = const Result.failure(failure);
        await cubit.loadByIds(<String>['track-1']);
        expect(cubit.state.status, SpotifyPreviewStatus.failure);
        expect(cubit.state.error, same(failure));

        await cubit.search('night');
        expect(cubit.state.status, SpotifyPreviewStatus.success);
        expect(cubit.state.tracks.single.id, 'track-1');
        expect(cubit.state.error, isNull);
        await cubit.close();
      },
    );
  });
}

class _LocationRepositoryFake implements LocationRepository {
  Result<List<City>> citiesResult = const Result.success(<City>[
    City(id: 'city-1', name: 'Istanbul'),
  ]);
  Result<List<District>> districtsResult = const Result.success(<District>[
    District(id: 'district-1', name: 'Kadikoy', cityId: 'city-1'),
  ]);
  Result<List<Neighborhood>> neighborhoodsResult = const Result.success(
    <Neighborhood>[
      Neighborhood(
        id: 'neighborhood-1',
        name: 'Moda',
        districtId: 'district-1',
      ),
    ],
  );

  @override
  Future<Result<List<City>>> getCities() async => citiesResult;

  @override
  Future<Result<List<District>>> getDistricts(String cityId) async =>
      districtsResult;

  @override
  Future<Result<List<Neighborhood>>> getNeighborhoods(
    String districtId,
  ) async => neighborhoodsResult;
}

class _InstrumentRepositoryFake implements InstrumentRepository {
  const _InstrumentRepositoryFake(this.result);

  final Result<List<Instrument>> result;

  @override
  Future<Result<List<Instrument>>> getAll() async => result;
}

class _SpotifyRepositoryFake implements SpotifyRepository {
  Result<List<SpotifyTrackPreview>> searchResult = const Result.success(
    <SpotifyTrackPreview>[
      SpotifyTrackPreview(
        id: 'track-1',
        name: 'One',
        previewUrl: null,
        durationSeconds: 30,
        spotifyUrl: null,
        albumImageUrl: null,
        artistNames: <String>['Ada'],
      ),
    ],
  );
  Result<List<SpotifyTrackPreview>> byIdsResult = const Result.success(
    <SpotifyTrackPreview>[],
  );

  @override
  Future<Result<List<SpotifyTrackPreview>>> getTracksByIds(
    List<String> ids,
  ) async => byIdsResult;

  @override
  Future<Result<List<SpotifyTrackPreview>>> searchTracks(
    String query, {
    int limit = 5,
  }) async => searchResult;
}
