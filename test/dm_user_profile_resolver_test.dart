import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_user_profile_resolver_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_profile_target.dart';

void main() {
  group('DmUserProfileResolverImpl', () {
    test(
      'uses only the canonical endpoint and de-duplicates targets',
      () async {
        final apiClient = _FakeApiClient((_) async {
          return <String, dynamic>{
            'profiles': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'MUSICIAN',
                'profileId': 'musician-1',
                'displayName': 'Ada',
                'profilePictureUrl': 'https://example.test/ada.jpg',
              },
              <String, dynamic>{
                'type': 'MUSICIAN',
                'profileId': 'musician-1',
                'displayName': 'Ada duplicate',
              },
              <String, dynamic>{
                'type': 'VENUE',
                'profileId': 'venue-1',
                'displayName': 'Salon',
              },
              <String, dynamic>{
                'type': 'LISTENER',
                'profileId': 'listener-1',
                'displayName': 'Dinleyici',
              },
              <String, dynamic>{
                'type': 'STUDIO',
                'profileId': 'studio-1',
                'displayName': 'Stüdyo',
              },
            ],
          };
        });
        final resolver = DmUserProfileResolverImpl(apiClient: apiClient);

        final result = await resolver.resolveByUserId(userId: 'user/42');

        expect(apiClient.paths, <String>[
          '/api/v1/public/profiles/by-user/user%2F42',
        ]);
        expect(result, hasLength(4));
        expect(result.first.type, DmProfileTargetType.musician);
        expect(result.map((target) => target.type), <DmProfileTargetType>[
          DmProfileTargetType.musician,
          DmProfileTargetType.venue,
          DmProfileTargetType.listener,
          DmProfileTargetType.studio,
        ]);
      },
    );

    test('de-duplicates concurrent requests for the same user', () async {
      final response = Completer<Object?>();
      final apiClient = _FakeApiClient((_) => response.future);
      final resolver = DmUserProfileResolverImpl(apiClient: apiClient);

      final first = resolver.resolveByUserId(userId: 'u1');
      final second = resolver.resolveByUserId(userId: 'u1');

      expect(identical(first, second), isTrue);
      expect(apiClient.paths, hasLength(1));
      response.complete(<String, dynamic>{'profiles': <Object>[]});
      expect(await first, isEmpty);
      expect(await second, isEmpty);
    });

    test('keeps a bounded least-recently-used cache', () async {
      final apiClient = _FakeApiClient((path) async {
        return <String, dynamic>{'profiles': <Object>[]};
      });
      final resolver = DmUserProfileResolverImpl(
        apiClient: apiClient,
        maxCacheEntries: 2,
      );

      await resolver.resolveByUserId(userId: 'u1');
      await resolver.resolveByUserId(userId: 'u2');
      await resolver.resolveByUserId(userId: 'u1'); // refresh u1 recency
      await resolver.resolveByUserId(userId: 'u3'); // evicts u2
      await resolver.resolveByUserId(userId: 'u2');

      expect(apiClient.paths.where((path) => path.endsWith('/u1')).length, 1);
      expect(apiClient.paths.where((path) => path.endsWith('/u2')).length, 2);
    });

    test('expires successes and briefly negative-caches failures', () async {
      var now = DateTime.utc(2026, 7, 13);
      var shouldFail = false;
      final apiClient = _FakeApiClient((_) async {
        if (shouldFail) throw StateError('network unavailable');
        return <String, dynamic>{'profiles': <Object>[]};
      });
      final resolver = DmUserProfileResolverImpl(
        apiClient: apiClient,
        cacheTtl: const Duration(minutes: 5),
        failureCacheTtl: const Duration(seconds: 15),
        clock: () => now,
      );

      await resolver.resolveByUserId(userId: 'success');
      now = now.add(const Duration(minutes: 6));
      await resolver.resolveByUserId(userId: 'success');
      expect(
        apiClient.paths.where((p) => p.endsWith('/success')),
        hasLength(2),
      );

      shouldFail = true;
      expect(await resolver.resolveByUserId(userId: 'failure'), isEmpty);
      expect(await resolver.resolveByUserId(userId: 'failure'), isEmpty);
      expect(
        apiClient.paths.where((p) => p.endsWith('/failure')),
        hasLength(1),
      );

      now = now.add(const Duration(seconds: 16));
      expect(await resolver.resolveByUserId(userId: 'failure'), isEmpty);
      expect(
        apiClient.paths.where((p) => p.endsWith('/failure')),
        hasLength(2),
      );
    });
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this._handler);

  final Future<Object?> Function(String path) _handler;
  final List<String> paths = <String>[];

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) async {
    paths.add(path);
    final payload = await _handler(path);
    return decoder == null ? payload as T : decoder(payload);
  }

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> post<T>(
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
