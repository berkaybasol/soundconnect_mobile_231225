import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/data/artist_venue_connection_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_application_page.dart';

void main() {
  for (final target in ArtistVenueApplicationTarget.values) {
    for (final incoming in [true, false]) {
      test(
        'connections include both directions for $target ($incoming)',
        () async {
          final api = _Api();
          final rows = [
            for (final direction in [
              target == ArtistVenueApplicationTarget.band ? 'BAND' : 'ARTIST',
              'VENUE',
            ])
              _row()
                ..['id'] = 'request-$direction'
                ..['status'] = 'ACCEPTED'
                ..['requestByType'] = direction
                ..['bandId'] = target == ArtistVenueApplicationTarget.band
                    ? 'band'
                    : null
                ..['musicianProfileId'] =
                    target == ArtistVenueApplicationTarget.band
                    ? null
                    : 'musician',
          ];
          api.response['content'] = rows;
          api.response['totalElements'] = rows.length;
          final result = await ArtistVenueConnectionRepositoryImpl(api)
              .listApplicationPage(
                target: target,
                targetId: target.name,
                incoming: incoming,
                connectionsOnly: true,
                expectedSessionKey: 'account',
              );
          expect(result.isSuccess, isTrue);
          expect(result.data!.items, hasLength(2));
          expect(api.query, {'status': 'ACCEPTED', 'page': 0, 'size': 20});
          expect(api.context?.expectedSessionKey, 'account');
        },
      );
    }
  }

  for (final change in ['pending', 'rejected', 'foreign scope']) {
    test('connections fail closed for $change response', () async {
      final api = _Api();
      final row = (api.response['content'] as List).first;
      row['status'] = change == 'pending'
          ? 'PENDING'
          : change == 'rejected'
          ? 'REJECTED'
          : 'ACCEPTED';
      if (change == 'foreign scope') row['venueId'] = 'other';
      final result = await ArtistVenueConnectionRepositoryImpl(api)
          .listApplicationPage(
            target: ArtistVenueApplicationTarget.venue,
            targetId: 'venue',
            incoming: true,
            connectionsOnly: true,
          );
      expect(result.isSuccess, isFalse);
    });
  }

  test('page decodes batch musician identity and nullable band fields', () {
    final page = ArtistVenueApplicationPage.fromJson(_page());
    expect(page.items.single.musicianDisplayName, 'aedrum');
    expect(
      page.items.single.musicianProfilePictureUrl,
      'https://example.com/a.jpg',
    );
    expect(page.items.single.bandId, '');
    expect(page.last, isTrue);
  });

  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'missing content': (json) => json.remove('content'),
    'noninteger page': (json) => json['page'] = 0.5,
    'oversized size': (json) => json['size'] = 101,
    'negative total': (json) => json['totalElements'] = -1,
    'wrong total pages': (json) => json['totalPages'] = 8,
    'wrong last': (json) => json['last'] = false,
    'missing row in page': (json) => json['content'] = [],
    'both identities': (json) =>
        (json['content'] as List).first['bandId'] = 'band',
    'no identities': (json) =>
        (json['content'] as List).first['musicianProfileId'] = null,
    'missing venue': (json) =>
        (json['content'] as List).first['venueId'] = null,
    'unknown direction': (json) =>
        (json['content'] as List).first['requestByType'] = 'ANY',
    'unknown state': (json) =>
        (json['content'] as List).first['status'] = 'ANY',
    'invalid avatar': (json) =>
        (json['content'] as List).first['musicianProfilePictureUrl'] = 42,
  }.entries) {
    test('rejects ${mutation.key}', () {
      final json = _page();
      mutation.value(json);
      expect(
        () => ArtistVenueApplicationPage.fromJson(json),
        throwsFormatException,
      );
    });
  }

  test('rejects duplicate row identities', () {
    final json = _page();
    json['totalElements'] = 2;
    json['content'] = [_row(), _row()];
    expect(
      () => ArtistVenueApplicationPage.fromJson(json),
      throwsFormatException,
    );
  });

  test('empty page beyond last is valid and stops paging', () {
    final json = _page()
      ..['page'] = 5
      ..['content'] = [];
    expect(ArtistVenueApplicationPage.fromJson(json).last, isTrue);
  });

  test(
    'request uses bounded endpoint, incoming filter and session fence',
    () async {
      final api = _Api();
      final result = await ArtistVenueConnectionRepositoryImpl(api)
          .listApplicationPage(
            target: ArtistVenueApplicationTarget.venue,
            targetId: 'venue',
            incoming: true,
            expectedSessionKey: 'account',
          );
      expect(result.isSuccess, isTrue);
      expect(api.path, '/api/v1/artist-venue-connections/venue/venue/page');
      expect(api.query, {'incoming': true, 'page': 0, 'size': 20});
      expect(api.context?.expectedSessionKey, 'account');
    },
  );

  for (final change in ['target', 'direction', 'page', 'size']) {
    test('repository rejects wrong $change response', () async {
      final api = _Api();
      if (change == 'target') {
        (api.response['content'] as List).first['venueId'] = 'other';
      }
      if (change == 'direction') {
        (api.response['content'] as List).first['requestByType'] = 'VENUE';
      }
      if (change == 'page') {
        api.response = _page()
          ..['page'] = 2
          ..['content'] = [];
      }
      if (change == 'size') api.response['size'] = 10;
      final result = await ArtistVenueConnectionRepositoryImpl(api)
          .listApplicationPage(
            target: ArtistVenueApplicationTarget.venue,
            targetId: 'venue',
            incoming: true,
          );
      expect(result.isSuccess, isFalse);
    });
  }

  test('invalid page does not dispatch network call', () async {
    final api = _Api();
    final repository = ArtistVenueConnectionRepositoryImpl(api);
    for (final page in [-1, 10001]) {
      expect(
        (await repository.listApplicationPage(
          target: ArtistVenueApplicationTarget.band,
          targetId: 'band',
          incoming: true,
          page: page,
        )).isSuccess,
        isFalse,
      );
    }
    expect(api.path, isNull);
  });
}

Map<String, dynamic> _row() => {
  'id': 'request',
  'musicianProfileId': 'musician',
  'bandId': null,
  'venueId': 'venue',
  'musicianStageName': null,
  'musicianDisplayName': 'aedrum',
  'musicianProfilePictureUrl': 'https://example.com/a.jpg',
  'bandName': null,
  'venueName': 'SoundConnect',
  'status': 'PENDING',
  'requestByType': 'ARTIST',
  'createdAt': '2026-09-07T12:00:00Z',
};
Map<String, dynamic> _page() => {
  'content': [_row()],
  'page': 0,
  'size': 20,
  'totalElements': 1,
  'totalPages': 1,
  'first': true,
  'last': true,
};

class _Api extends Fake implements ApiClient {
  Map<String, dynamic> response = _page();
  String? path;
  Map<String, dynamic>? query;
  ApiRequestContext? context;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    expect(method, ApiHttpMethod.get);
    this.path = path;
    this.query = query;
    context = requestContext;
    return decoder!(response);
  }
}
