import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/venue_artist_directory_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_artist_directory_repository.dart';

void main() {
  for (final kind in VenueArtistKind.values) {
    test(
      'requests only $kind with server-side search and session fence',
      () async {
        final api = _Api(response: _page(kind: kind));
        final result = await VenueArtistDirectoryRepositoryImpl(api).list(
          venueId: ' venue/one ',
          kind: kind,
          query: '  Şah_100%  ',
          expectedSessionKey: 'account',
        );
        expect(result.isSuccess, isTrue);
        expect(
          api.path,
          '/api/v1/public/venue-profiles/venue%2Fone/active-artists',
        );
        expect(api.query, {
          'type': kind == VenueArtistKind.band ? 'BAND' : 'MUSICIAN',
          'q': 'Şah_100%',
          'page': 0,
          'size': 20,
        });
        expect(api.context?.expectedSessionKey, 'account');
        expect(result.data!.items.single.kind, kind);
        expect(result.data!.items.single.id, 'artist');
        expect(result.data!.items.single.displayName, 'Şahbaz');
        expect(
          result.data!.items.single.profileImageUrl,
          'https://example.com/a.jpg',
        );
        expect(() => result.data!.items.clear(), throwsUnsupportedError);
      },
    );
  }

  test(
    'blank search is omitted and unfenced public read is supported',
    () async {
      final api = _Api();
      final result = await VenueArtistDirectoryRepositoryImpl(
        api,
      ).list(venueId: 'venue', kind: VenueArtistKind.musician, query: '  ');
      expect(result.isSuccess, isTrue);
      expect(api.query, {'type': 'MUSICIAN', 'page': 0, 'size': 20});
      expect(api.context, isNull);
    },
  );

  for (final image in <String?>[null, '', '  ']) {
    test('nullable or empty avatar $image uses fallback', () async {
      final api = _Api();
      (api.response as Map)['content'][0]['profilePictureUrl'] = image;
      final result = await VenueArtistDirectoryRepositoryImpl(
        api,
      ).list(venueId: 'venue', kind: VenueArtistKind.musician);
      expect(result.isSuccess, isTrue);
      expect(result.data!.items.single.profileImageUrl, isNull);
    });
  }

  test('last partial page decodes bounded pagination metadata', () async {
    final api = _Api(response: _page(page: 2, size: 20, total: 41));
    final result = await VenueArtistDirectoryRepositoryImpl(
      api,
    ).list(venueId: 'venue', kind: VenueArtistKind.musician, page: 2);
    expect(result.isSuccess, isTrue);
    expect(result.data!.page, 2);
    expect(result.data!.size, 20);
    expect(result.data!.totalElements, 41);
    expect(result.data!.totalPages, 3);
    expect(result.data!.last, isTrue);
  });

  for (final page in [0, 5]) {
    test('empty page $page stops pagination', () async {
      final api = _Api(response: _page(page: page, total: 0));
      final result = await VenueArtistDirectoryRepositoryImpl(
        api,
      ).list(venueId: 'venue', kind: VenueArtistKind.musician, page: page);
      expect(result.isSuccess, isTrue);
      expect(result.data!.items, isEmpty);
      expect(result.data!.last, isTrue);
    });
  }

  for (final invalid in [
    'blank venue',
    'long query',
    'negative page',
    'large page',
    'zero size',
    'large size',
  ]) {
    test('invalid $invalid never dispatches a request', () async {
      final api = _Api();
      final result = await VenueArtistDirectoryRepositoryImpl(api).list(
        venueId: invalid == 'blank venue' ? '  ' : 'venue',
        kind: VenueArtistKind.musician,
        query: invalid == 'long query' ? 'a' * 101 : '',
        page: invalid == 'negative page'
            ? -1
            : invalid == 'large page'
            ? 10001
            : 0,
        size: invalid == 'zero size'
            ? 0
            : invalid == 'large size'
            ? 51
            : 20,
      );
      expect(result.error?.code, 'venue_artist_directory_invalid_query');
      expect(api.path, isNull);
    });
  }

  test('maximum trimmed search and page size are accepted', () async {
    final api = _Api(response: _page(size: 50));
    final result = await VenueArtistDirectoryRepositoryImpl(api).list(
      venueId: 'venue',
      kind: VenueArtistKind.musician,
      query: ' ${'a' * 100} ',
      size: 50,
    );
    expect(result.isSuccess, isTrue);
    expect((api.query!['q'] as String).length, 100);
  });

  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'missing content': (json) => json.remove('content'),
    'wrong content type': (json) => json['content'] = {},
    'wrong page type': (json) => json['page'] = '0',
    'negative total': (json) => json['totalElements'] = -1,
    'wrong page count': (json) => json['totalPages'] = 2,
    'wrong last flag': (json) => json['last'] = false,
    'wrong first flag': (json) => json['first'] = false,
    'wrong alias number': (json) => json['number'] = 1,
    'unbounded size': (json) => json['size'] = 51,
    'missing result row': (json) => json['content'] = [],
    'invalid row': (json) => json['content'] = ['invalid'],
    'blank identity': (json) => json['content'][0]['id'] = ' ',
    'invalid identity': (json) => json['content'][0]['id'] = 123,
    'blank name': (json) => json['content'][0]['name'] = ' ',
    'unknown type': (json) => json['content'][0]['type'] = 'VENUE',
    'invalid image': (json) => json['content'][0]['profilePictureUrl'] = 42,
    'duplicate identity': (json) {
      json['content'] = [_row(), _row()];
      json['totalElements'] = 2;
    },
  }.entries) {
    test('malformed response rejects ${mutation.key}', () async {
      final response = _page();
      mutation.value(response);
      final api = _Api(response: response);
      final result = await VenueArtistDirectoryRepositoryImpl(
        api,
      ).list(venueId: 'venue', kind: VenueArtistKind.musician);
      expect(result.error?.code, 'venue_artist_directory_malformed_response');
      expect(result.data, isNull);
    });
  }

  for (final wrong in ['type', 'page', 'size']) {
    test('requested $wrong is validated against returned scope', () async {
      final response = switch (wrong) {
        'type' => _page(kind: VenueArtistKind.band),
        'page' => _page(page: 1, total: 0),
        _ => _page(size: 10),
      };
      final result = await VenueArtistDirectoryRepositoryImpl(
        _Api(response: response),
      ).list(venueId: 'venue', kind: VenueArtistKind.musician);
      expect(result.error?.code, 'venue_artist_directory_malformed_response');
    });
  }

  for (final response in <Object?>[null, [], 'invalid']) {
    test('non-page response $response fails closed', () async {
      final api = _Api()..response = response;
      final result = await VenueArtistDirectoryRepositoryImpl(
        api,
      ).list(venueId: 'venue', kind: VenueArtistKind.musician);
      expect(result.error?.code, 'venue_artist_directory_malformed_response');
    });
  }

  test('API failures preserve status and user-facing error', () async {
    const error = AppError(code: 'not_found', message: 'Mekan bulunamadı.');
    final api = _Api()..failure = ApiException(error);
    final result = await VenueArtistDirectoryRepositoryImpl(
      api,
    ).list(venueId: 'venue', kind: VenueArtistKind.musician);
    expect(result.error, same(error));
  });

  test('unexpected transport failure gives a retryable result', () async {
    final api = _Api()..failure = StateError('offline');
    final result = await VenueArtistDirectoryRepositoryImpl(
      api,
    ).list(venueId: 'venue', kind: VenueArtistKind.musician);
    expect(result.error?.code, 'venue_artist_directory_failed');
  });
}

Map<String, dynamic> _row({VenueArtistKind kind = VenueArtistKind.musician}) =>
    {
      'id': 'artist',
      'name': 'Şahbaz',
      'type': kind == VenueArtistKind.musician ? 'MUSICIAN' : 'BAND',
      'profilePictureUrl': 'https://example.com/a.jpg',
    };

Map<String, dynamic> _page({
  VenueArtistKind kind = VenueArtistKind.musician,
  int page = 0,
  int size = 20,
  int total = 1,
}) => {
  'content': [
    for (var i = 0; i < (total - page * size).clamp(0, size); i++)
      _row(kind: kind)..['id'] = i == 0 ? 'artist' : 'artist-$i',
  ],
  'page': page,
  'number': page,
  'size': size,
  'totalElements': total,
  'totalPages': (total / size).ceil(),
  'first': page == 0,
  'last': page + 1 >= (total / size).ceil(),
};

class _Api extends Fake implements ApiClient {
  _Api({Object? response}) : response = response ?? _page();

  Object? response;
  Object? failure;
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
    if (failure != null) throw failure!;
    return decoder!(response);
  }
}
