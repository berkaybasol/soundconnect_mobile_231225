import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/data/artist_venue_connection_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/data/artist_venue_connection_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/data/models/artist_venue_connection_response.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/presentation/cubit/artist_venue_connections_state.dart';
import 'package:soundconnect_23_12_25codx/modules/event/data/event_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/event/data/event_discovery_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/event/data/models/discovery_event_model.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/data/models/promotion_item_model.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/data/promotion_repository_impl.dart';

import 'support/recording_api_client.dart';

void main() {
  group('artist-venue connection boundaries', () {
    test('response model coerces IDs and accepts legacy image aliases', () {
      final response = ArtistVenueConnectionResponse.fromJson(<String, dynamic>{
        'id': 101,
        'musicianProfileId': 202,
        'bandId': null,
        'venueId': 303,
        'venueProfilePicture': 'https://cdn/venue.jpg',
        'status': 1,
      });

      expect(response.id, '101');
      expect(response.musicianProfileId, '202');
      expect(response.bandId, isEmpty);
      expect(response.venueId, '303');
      expect(response.venueProfilePictureUrl, 'https://cdn/venue.jpg');
      expect(response.status, '1');
    });

    test(
      'status list filters unusable rows and preserves the status endpoint',
      () async {
        final client = RecordingApiClient((request) {
          return <Object?>[
            <String, dynamic>{
              'id': 'request-1',
              'venueId': 'venue-1',
              'venueName': 'Salon',
              'venueImageUrl': 'https://cdn/venue.jpg',
            },
            <String, dynamic>{'id': '', 'venueId': 'venue-2'},
            'malformed-row',
          ];
        });
        final repository = ArtistVenueConnectionRepositoryImpl(client);

        final result = await repository.getVenueConnectionsByStatus(
          'musician-1',
          status: 'ACCEPTED',
        );

        expect(result.data, hasLength(1));
        expect(result.data?.single.requestId, 'request-1');
        expect(result.data?.single.profileImageUrl, 'https://cdn/venue.jpg');
        expect(
          client.lastRequest.path,
          ArtistVenueConnectionEndpoints.byMusician(
            'musician-1',
            status: 'ACCEPTED',
          ),
        );
      },
    );

    test(
      'applications are newest-first and receive stable API defaults',
      () async {
        final repository = ArtistVenueConnectionRepositoryImpl(
          RecordingApiClient(
            (_) => <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'older',
                'venueId': 'venue-1',
                'createdAt': '2026-07-01T10:00:00Z',
              },
              <String, dynamic>{
                'id': 'newer',
                'venueId': 'venue-1',
                'createdAt': '2026-07-13T10:00:00Z',
              },
            ],
          ),
        );

        final result = await repository.listVenueApplications('venue-1');

        expect(result.data?.map((item) => item.id), <String>['newer', 'older']);
        expect(result.data?.first.status, 'PENDING');
        expect(result.data?.first.requestByType, 'ARTIST');
        expect(result.data?.first.venueName, 'Mekan');
      },
    );

    test('createBandRequest records request type and canonical body', () async {
      final client = RecordingApiClient((_) => null);
      final repository = ArtistVenueConnectionRepositoryImpl(client);

      final result = await repository.createBandRequest(
        bandId: 'band-1',
        venueId: 'venue-1',
        message: 'Birlikte calisalim',
      );

      expect(result.isSuccess, isTrue);
      expect(
        client.lastRequest.path,
        ArtistVenueConnectionEndpoints.request('BAND'),
      );
      expect(client.lastRequest.method, RecordedHttpMethod.post);
      expect(client.lastRequest.body, <String, dynamic>{
        'bandId': 'band-1',
        'venueId': 'venue-1',
        'message': 'Birlikte calisalim',
      });
    });

    test('band applications use the unfiltered band endpoint', () async {
      final client = RecordingApiClient(
        (_) => <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'incoming',
            'bandId': 'band-1',
            'venueId': 'venue-1',
            'requestByType': 'VENUE',
          },
          <String, dynamic>{
            'id': 'outgoing',
            'bandId': 'band-1',
            'venueId': 'venue-2',
            'requestByType': 'BAND',
          },
        ],
      );
      final repository = ArtistVenueConnectionRepositoryImpl(client);

      final result = await repository.listBandVenueApplications('band-1');

      expect(result.isSuccess, isTrue);
      expect(result.data?.map((item) => item.requestByType), <String>[
        'VENUE',
        'BAND',
      ]);
      expect(
        client.lastRequest.path,
        ArtistVenueConnectionEndpoints.byBand('band-1'),
      );
    });

    test('venue can target a band with the venue request contract', () async {
      final client = RecordingApiClient((_) => null);
      final repository = ArtistVenueConnectionRepositoryImpl(client);

      final result = await repository.createVenueBandRequest(
        bandId: 'band-7',
        venueId: 'venue-3',
        message: 'Sahnede bulusalim',
      );

      expect(result.isSuccess, isTrue);
      expect(
        client.lastRequest.path,
        ArtistVenueConnectionEndpoints.request('VENUE'),
      );
      expect(client.lastRequest.method, RecordedHttpMethod.post);
      expect(client.lastRequest.body, <String, dynamic>{
        'bandId': 'band-7',
        'venueId': 'venue-3',
        'message': 'Sahnede bulusalim',
      });
    });

    test('cubit emits success and preserves typed API failures', () async {
      final successCubit = ArtistVenueConnectionsCubit(
        ArtistVenueConnectionRepositoryImpl(
          RecordingApiClient(
            (_) => <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'request-1',
                'venueId': 'venue-1',
                'venueName': 'Salon',
              },
            ],
          ),
        ),
      );
      await successCubit.loadAcceptedVenues('musician-1');
      expect(successCubit.state.status, ArtistVenueConnectionsStatus.success);
      expect(successCubit.state.venues.single.venueName, 'Salon');
      await successCubit.close();

      const error = AppError(code: '403', message: 'Forbidden');
      final failureCubit = ArtistVenueConnectionsCubit(
        ArtistVenueConnectionRepositoryImpl(
          RecordingApiClient((_) => throw ApiException(error)),
        ),
      );
      await failureCubit.loadAcceptedVenues('musician-1');
      expect(failureCubit.state.status, ArtistVenueConnectionsStatus.failure);
      expect(failureCubit.state.error, same(error));
      await failureCubit.close();
    });
  });

  group('event discovery boundaries', () {
    test(
      'model parses aliases, times, dates, and heterogeneous member IDs',
      () {
        final event = DiscoveryEventModel.fromJson(<String, dynamic>{
          'id': 99,
          'title': null,
          'performerName': 'Ada',
          'performerProfilePicture': ' https://cdn/artist.jpg ',
          'bandMembers': <Object?>['Ada', 7, ''],
          'venueName': 'Salon',
          'venueProfilePictureUrl': 'https://cdn/venue.jpg',
          'eventDate': '2026-07-13',
          'startTime': '21:05:00',
          'endTime': 'invalid',
          'imageUrl': 'https://cdn/poster.jpg',
          'description': 123,
        });

        expect(event.id, '99');
        expect(event.title, 'Etkinlik');
        expect(event.performerImageUrl, 'https://cdn/artist.jpg');
        expect(event.bandMembers, <String>['Ada', '7']);
        expect(event.venueImageUrl, 'https://cdn/venue.jpg');
        expect(event.eventDate, DateTime(2026, 7, 13));
        expect(event.startTime?.hour, 21);
        expect(event.startTime?.minute, 5);
        expect(event.endTime, isNull);
        expect(event.posterImageUrl, 'https://cdn/poster.jpg');
        expect(event.description, '123');
      },
    );

    test(
      'repository selects the neighborhood path and drops malformed rows',
      () async {
        final client = RecordingApiClient(
          (_) => <Object?>[
            <String, dynamic>{'id': 'event-1', 'title': 'Konser'},
            7,
          ],
        );
        final repository = EventDiscoveryRepositoryImpl(client);

        final result = await repository.getEventsByNeighborhood('hood-1');

        expect(result.data?.single.id, 'event-1');
        expect(
          client.lastRequest.path,
          EventEndpoints.byNeighborhood('hood-1'),
        );
      },
    );

    test(
      'typed and unknown failures retain distinct error contracts',
      () async {
        const typedError = AppError(code: '503', message: 'Unavailable');
        final typed = await EventDiscoveryRepositoryImpl(
          RecordingApiClient((_) => throw ApiException(typedError)),
        ).getTodayEvents();
        final unknown = await EventDiscoveryRepositoryImpl(
          RecordingApiClient((_) => throw StateError('broken')),
        ).getEventsByCity('city-1');

        expect(typed.error, same(typedError));
        expect(unknown.error?.code, 'event_city_unknown');
      },
    );
  });

  group('promotion boundaries', () {
    test('model coerces numeric priority and supplies safe defaults', () {
      final model = PromotionItemModel.fromJson(<String, dynamic>{
        'id': 7,
        'title': 99,
        'priority': 4.8,
      });

      expect(model.id, '7');
      expect(model.title, '99');
      expect(model.priority, 4);
      expect(model.type, isEmpty);
      expect(model.mediaAssetId, isEmpty);
    });

    test('repository filters empty IDs and preserves API errors', () async {
      final client = RecordingApiClient(
        (_) => <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'promotion-1',
            'title': 'Featured',
            'priority': 10,
          },
          <String, dynamic>{'id': '', 'title': 'Invalid'},
        ],
      );
      final repository = PromotionRepositoryImpl(client);

      final result = await repository.getDisplayableByPlacement('HOME_HERO');

      expect(result.data?.single.id, 'promotion-1');
      expect(
        client.lastRequest.path,
        '/api/v1/promotions/displayable/HOME_HERO',
      );

      const error = AppError(code: '401', message: 'Unauthorized');
      final failed = await PromotionRepositoryImpl(
        RecordingApiClient((_) => throw ApiException(error)),
      ).getDisplayableByPlacement('HOME_HERO');
      expect(failed.error, same(error));
    });
  });
}
