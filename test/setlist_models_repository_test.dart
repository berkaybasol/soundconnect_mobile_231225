import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/setlist/data/models/setlist_document_model.dart';
import 'package:soundconnect_23_12_25codx/modules/setlist/data/setlist_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/setlist/data/setlist_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/setlist/domain/entities/setlist_key.dart';

void main() {
  group('SetlistDocumentModel', () {
    test('normalizes identifiers and sorts nested sets and items', () {
      final model = SetlistDocumentModel.fromJson(<String, dynamic>{
        'id': ' setlist-1 ',
        'name': ' Friday ',
        'musicianProfile': <String, dynamic>{'id': ' musician-1 '},
        'band': ' band-1 ',
        'sets': <Object?>[
          <String, dynamic>{
            'id': 'set-2',
            'title': 'Second',
            'duration': ' 45m ',
            'orderNumber': '2',
            'items': <Object?>[
              <String, dynamic>{
                'id': 'song-2',
                'artistName': ' Artist B ',
                'songName': ' Song B ',
                'orderNumber': 2.9,
                'key': ' d_min ',
              },
              <String, dynamic>{
                'id': 'song-1',
                'artistName': 'Artist A',
                'songName': 'Song A',
                'orderNumber': '1',
                'key': 'C_MAJ',
              },
              'ignored',
            ],
          },
          <String, dynamic>{
            'id': 'set-1',
            'title': 'First',
            'duration': ' ',
            'orderNumber': 1,
            'items': const <Object?>[],
          },
        ],
      });

      expect(model.id, 'setlist-1');
      expect(model.name, 'Friday');
      expect(model.musicianProfileId, 'musician-1');
      expect(model.bandId, 'band-1');
      expect(model.sets.map((item) => item.id), <String>['set-1', 'set-2']);
      expect(model.sets.first.duration, isNull);
      expect(model.sets.last.items.map((item) => item.id), <String>[
        'song-1',
        'song-2',
      ]);
      expect(model.sets.last.items.first.key, SetlistKey.cMaj);
      expect(model.sets.last.items.last.key, SetlistKey.dMin);
      expect(model.sets.last.items.last.orderNumber, 2);
      expect(model.sets.last.items.last.artistName, 'Artist B');
    });

    test('uses safe defaults for malformed optional data', () {
      final model = SetlistDocumentModel.fromJson(<String, dynamic>{
        'id': 7,
        'musicianProfile': <String, dynamic>{'id': ' '},
        'sets': 'not-a-list',
      });
      final unknownKey = SetlistKey.fromApiValue('not_supported');

      expect(model.id, '7');
      expect(model.name, isEmpty);
      expect(model.musicianProfileId, isNull);
      expect(model.bandId, isNull);
      expect(model.sets, isEmpty);
      expect(unknownKey, SetlistKey.original);
    });
  });

  group('SetlistRepositoryImpl', () {
    test(
      'trims create request and turns blank optional ids into null',
      () async {
        final apiClient = _RecordingApiClient(payload: _emptyDocumentJson());
        final repository = SetlistRepositoryImpl(
          apiClient,
          _MemoryTokenStore(),
        );

        final result = await repository.createSetlist(
          name: '  Friday set  ',
          musicianProfileId: '  ',
          bandId: ' band-9 ',
        );

        expect(result.isSuccess, isTrue);
        expect(apiClient.lastMethod, 'POST');
        expect(apiClient.lastPath, SetlistEndpoints.create);
        expect(apiClient.lastBody, <String, dynamic>{
          'name': 'Friday set',
          'musicianProfileId': null,
          'bandId': 'band-9',
        });
      },
    );

    test('serializes item key using the backend API value', () async {
      final apiClient = _RecordingApiClient(payload: _emptyDocumentJson());
      final repository = SetlistRepositoryImpl(apiClient, _MemoryTokenStore());

      await repository.addItem(
        setId: 'set-3',
        artistName: '  Artist  ',
        songName: '  Song  ',
        key: SetlistKey.fSharpMin,
        orderNumber: 4,
      );

      expect(apiClient.lastMethod, 'POST');
      expect(apiClient.lastPath, SetlistEndpoints.addItem('set-3'));
      expect(apiClient.lastBody, <String, dynamic>{
        'artistName': 'Artist',
        'songName': 'Song',
        'key': 'F_SHARP_MIN',
        'orderNumber': 4,
      });
    });

    test('preserves a typed API error from detail lookup', () async {
      const error = AppError(code: '404', message: 'Missing');
      final repository = SetlistRepositoryImpl(
        _RecordingApiClient(failure: ApiException(error)),
        _MemoryTokenStore(),
      );

      final result = await repository.getSetlistById('missing');

      expect(result.error, same(error));
    });
  });
}

Map<String, dynamic> _emptyDocumentJson() => <String, dynamic>{
  'id': 'setlist-1',
  'name': 'Setlist',
  'sets': const <Object?>[],
};

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient({this.payload, this.failure});

  final Object? payload;
  final Object? failure;
  String? lastMethod;
  String? lastPath;
  Object? lastBody;

  T _decode<T>(T Function(Object? json)? decoder) {
    final error = failure;
    if (error != null) throw error;
    return decoder == null ? payload as T : decoder(payload);
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) async {
    lastMethod = 'GET';
    lastPath = path;
    return _decode(decoder);
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastBody = body;
    return _decode(decoder);
  }

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) async {
    lastMethod = 'DELETE';
    lastPath = path;
    lastBody = body;
    return _decode(decoder);
  }

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) {
    lastMethod = 'PATCH';
    throw UnimplementedError();
  }

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) {
    lastMethod = 'PUT';
    throw UnimplementedError();
  }
}

class _MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> readToken() async => value;

  @override
  Future<void> writeToken(String token) async => value = token;
}
