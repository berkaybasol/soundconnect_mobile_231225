import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/profile_media_repository_impl.dart';
import 'support/recording_api_client.dart';
import 'support/event_audience_fakes.dart';

class _TrackedSessions extends AudienceTestSessions {
  _TrackedSessions(super.current);

  bool get hasRegisteredListeners => hasListeners;
}

void main() {
  const primaryMedia = {
    'featuredVideo': null,
    'videos': <Object?>[],
    'audios': [
      {
        'id': 'old-track',
        'mediaAssetId': 'old-asset',
        'title': 'Old account audio',
      },
    ],
  };

  for (final code in ['401', '403', '1307', 'network_error', '500']) {
    test(
      'primary $code failure cannot become successful empty media',
      () async {
        final error = AppError(code: code, message: 'Failed');
        final api = RecordingApiClient((_) => throw ApiException(error));
        final result = await ProfileMediaRepositoryImpl(
          api,
        ).getProfileMedia(profileType: 'MUSICIAN', profileId: 'profile');
        expect(result.error, same(error));
        expect(api.requests.length, 1);
      },
    );
  }

  test('legacy route 404 permits a valid empty compatibility page', () async {
    final api = RecordingApiClient((request) {
      if (!request.path.contains('/public/media/')) {
        throw ApiException(
          const AppError(code: '404', message: 'Route missing'),
        );
      }
      return {'content': <Object?>[]};
    });
    final result = await ProfileMediaRepositoryImpl(
      api,
    ).getProfileMedia(profileType: 'BAND', profileId: 'band');
    expect(result.isSuccess, isTrue);
    expect(api.requests.length, 2);
  });

  for (final primaryMissing in [true, false]) {
    test(
      'malformed fallback page fails instead of pretending media is empty ($primaryMissing)',
      () async {
        final api = RecordingApiClient((request) {
          if (request.path.contains('/public/media/')) {
            return {'content': 'corrupt'};
          }
          if (primaryMissing) {
            throw ApiException(
              const AppError(code: '404', message: 'Route missing'),
            );
          }
          return {'featuredVideo': null, 'videos': [], 'audios': []};
        });
        final result = await ProfileMediaRepositoryImpl(
          api,
        ).getProfileMedia(profileType: 'VENUE', profileId: 'profile');
        expect(result.error?.code, 'profile_media_invalid_response');
      },
    );

    test('fallback session fence is not swallowed ($primaryMissing)', () async {
      final api = RecordingApiClient((request) {
        if (request.path.contains('/public/media/')) {
          throw ApiException(
            const AppError(code: 'api_session_fence', message: 'Changed'),
          );
        }
        if (primaryMissing) {
          throw ApiException(
            const AppError(code: '404', message: 'Legacy route'),
          );
        }
        return primaryMedia;
      });
      final result = await ProfileMediaRepositoryImpl(
        api,
      ).getProfileMedia(profileType: 'MUSICIAN', profileId: 'profile');
      expect(result.error?.code, 'api_session_fence');
      expect(result.data, isNull);
      expect(api.requests, hasLength(2));
    });

    for (final fallbackFails in [true, false]) {
      test(
        'account ABA during fallback revokes the whole media chain ($primaryMissing, $fallbackFails)',
        () async {
          final started = Completer<void>();
          final pending = Completer<Object?>();
          final original = audienceSession(role: 'ROLE_MUSICIAN');
          final sessions = _TrackedSessions(original);
          addTearDown(sessions.dispose);
          final api = RecordingApiClient((request) {
            if (request.path.contains('/public/media/')) {
              started.complete();
              return pending.future;
            }
            if (primaryMissing) {
              throw ApiException(
                const AppError(code: '404', message: 'Legacy route'),
              );
            }
            return primaryMedia;
          });
          final result = ProfileMediaRepositoryImpl(
            api,
            sessions: sessions,
          ).getProfileMedia(profileType: 'MUSICIAN', profileId: 'profile');
          await started.future;
          sessions.replace(audienceSession(user: 'replacement'));
          sessions.replace(original);
          if (fallbackFails) {
            pending.completeError(
              ApiException(
                const AppError(code: 'network_error', message: 'Offline'),
              ),
            );
          } else {
            pending.complete({'content': <Object?>[]});
          }
          expect((await result).error?.code, 'api_session_fence');
          expect((await result).data, isNull);
          expect(sessions.hasRegisteredListeners, isFalse);
        },
      );
    }
  }

  for (final session in [
    const AuthSession.guest(),
    audienceSession(role: 'ROLE_MUSICIAN'),
  ]) {
    test(
      'both media requests keep the initiating ${session.isAuthenticated ? 'authenticated' : 'guest'} context',
      () async {
        final sessions = _TrackedSessions(session);
        addTearDown(sessions.dispose);
        final api = RecordingApiClient(
          (request) => request.path.contains('/public/media/')
              ? {'content': <Object?>[]}
              : primaryMedia,
        );
        final result = await ProfileMediaRepositoryImpl(
          api,
          sessions: sessions,
        ).getProfileMedia(profileType: 'MUSICIAN', profileId: 'profile');
        expect(result.isSuccess, isTrue);
        expect(result.data?.audios.single.id, 'old-track');
        expect(api.requests, hasLength(2));
        expect(
          api.requests.first.requestContext,
          same(api.requests.last.requestContext),
        );
        final scope = api.lastRequest.requestContext!;
        expect(scope.requireGuestSession, !session.isAuthenticated);
        expect(scope.expectedSessionKey, session.userId);
        expect(scope.expectedToken, session.token);
        expect(sessions.hasRegisteredListeners, isFalse);
      },
    );

    test(
      'session replacement before primary completion cannot dispatch video fallback (${session.isAuthenticated})',
      () async {
        final pending = Completer<Object?>();
        final sessions = _TrackedSessions(session);
        addTearDown(sessions.dispose);
        final api = RecordingApiClient((_) => pending.future);
        final result = ProfileMediaRepositoryImpl(
          api,
          sessions: sessions,
        ).getProfileMedia(profileType: 'MUSICIAN', profileId: 'profile');
        sessions.replace(audienceSession(user: 'replacement'));
        sessions.replace(session);
        pending.complete(primaryMedia);
        expect((await result).error?.code, 'api_session_fence');
        expect(api.requests, hasLength(1));
        expect(sessions.hasRegisteredListeners, isFalse);
      },
    );
  }
}
