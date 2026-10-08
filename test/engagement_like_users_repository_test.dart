import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  for (final target in [
    'MEDIA',
    'EVENT',
    'EVENT_POST',
    'TABLE_GROUP_POST',
    'OVERTHINKING_PROFILE_SHARE',
    'OVERTHINKING',
    'COMMENT',
  ]) {
    test(
      '$target reads the exact target with the current session fence',
      () async {
        final sessions = AudienceTestSessions(audienceSession());
        addTearDown(sessions.dispose);
        final api = RecordingApiClient((_) => _page());
        final result = await EngagementRepositoryImpl(
          api,
          sessions: sessions,
        ).listLikeUsers(targetType: target, targetId: 'content/identity');

        expect(result.isSuccess, isTrue);
        expect(result.data!.items.single.id, 'liker');
        expect(result.data!.items.single.username, 'leylasaman');
        expect(result.data!.items.single.isGhost, isFalse);
        expect(result.data!.nextCursor, isNull);
        expect(result.data!.hasMore, isFalse);
        expect(api.requests, hasLength(1));
        final request = api.lastRequest;
        expect(request.method, RecordedHttpMethod.get);
        expect(request.path, '/api/v1/likes/$target/content%2Fidentity/users');
        expect(request.query, {'size': 20});
        expect(request.requestContext!.expectedSessionKey, 'listener');
        expect(request.requestContext!.expectedToken, 'token');
        expect(request.requestContext!.requireGuestSession, isFalse);
      },
    );
  }

  test(
    'cursor pages preserve visibility, avatar and immutable identities',
    () async {
      final api = RecordingApiClient(
        (_) => _page(
          items: [
            _user(),
            _user(
              id: 'ghost-liker',
              username: 'sessizdinleyici',
              visibilityMode: 'GHOST',
              avatarUrl: 'https://soundconnect.test/avatar.jpg',
            ),
          ],
          nextCursor: 'next_cursor',
          hasMore: true,
        ),
      );
      final result = await EngagementRepositoryImpl(api).listLikeUsers(
        targetType: 'MEDIA',
        targetId: 'media',
        cursor: 'previous_cursor',
        size: 50,
      );

      expect(result.isSuccess, isTrue);
      final page = result.data!;
      expect(page.items, hasLength(2));
      expect(page.items.last.isGhost, isTrue);
      expect(page.items.last.avatarUrl, 'https://soundconnect.test/avatar.jpg');
      expect(page.nextCursor, 'next_cursor');
      expect(page.hasMore, isTrue);
      expect(api.lastRequest.query, {'size': 50, 'cursor': 'previous_cursor'});
      expect(() => page.items.clear(), throwsUnsupportedError);
    },
  );

  test('an empty terminal page is valid', () async {
    final api = RecordingApiClient((_) => _page(items: []));
    final result = await EngagementRepositoryImpl(
      api,
    ).listLikeUsers(targetType: 'MEDIA', targetId: 'media');
    expect(result.isSuccess, isTrue);
    expect(result.data!.items, isEmpty);
    expect(result.data!.hasMore, isFalse);
  });

  final malformedPages = <String, Object?>{
    'null response': null,
    'legacy array': [_user()],
    'missing items': {'hasMore': false, 'nextCursor': null},
    'non-list items': _page(items: 'users'),
    'invalid hasMore': {..._page(), 'hasMore': 'false'},
    'missing hasMore': {
      'items': [_user()],
      'nextCursor': null,
    },
    'missing next cursor': _page(hasMore: true),
    'empty next cursor': _page(hasMore: true, nextCursor: ''),
    'non-string next cursor': _page(hasMore: true, nextCursor: 4),
    'oversized next cursor': _page(hasMore: true, nextCursor: 'a' * 1025),
    'same next cursor': _page(hasMore: true, nextCursor: 'current_cursor'),
    'empty nonterminal page': _page(
      items: [],
      hasMore: true,
      nextCursor: 'next',
    ),
    'cursor on terminal page': _page(nextCursor: 'next'),
    'duplicate identity': _page(items: [_user(), _user()]),
    'too many users': _page(
      items: List.generate(21, (index) => _user(id: 'liker-$index')),
    ),
    'not a user object': _page(items: ['leylasaman']),
    'missing user id': _page(
      items: [
        {'username': 'leylasaman'},
      ],
    ),
    'empty user id': _page(items: [_user(id: ' ')]),
    'padded user id': _page(items: [_user(id: ' liker ')]),
    'numeric user id': _page(
      items: [
        {..._user(), 'id': 7},
      ],
    ),
    'missing username': _page(
      items: [
        {'id': 'liker'},
      ],
    ),
    'empty username': _page(items: [_user(username: ' ')]),
    'numeric username': _page(
      items: [
        {..._user(), 'username': 7},
      ],
    ),
    'non-string avatar': _page(
      items: [
        {..._user(), 'avatarUrl': 7},
      ],
    ),
    'invalid visibility': _page(items: [_user(visibilityMode: 'PRIVATE')]),
    'non-string visibility': _page(
      items: [
        {..._user(), 'visibilityMode': 7},
      ],
    ),
  };
  for (final entry in malformedPages.entries) {
    test('${entry.key} rejects the complete malformed page', () async {
      final api = RecordingApiClient((_) => entry.value);
      final result = await EngagementRepositoryImpl(api).listLikeUsers(
        targetType: 'MEDIA',
        targetId: 'media',
        cursor: 'current_cursor',
      );
      expect(result.data, isNull);
      expect(result.error?.code, 'engagement_like_users_invalid_response');
    });
  }

  for (final arguments
      in <({String type, String id, String? cursor, int size})>[
        (type: 'UNKNOWN', id: 'media', cursor: null, size: 20),
        (type: 'MEDIA', id: '', cursor: null, size: 20),
        (type: 'MEDIA', id: ' media ', cursor: null, size: 20),
        (type: 'MEDIA', id: 'a' * 129, cursor: null, size: 20),
        (type: 'MEDIA', id: 'media', cursor: null, size: 0),
        (type: 'MEDIA', id: 'media', cursor: null, size: 51),
        (type: 'MEDIA', id: 'media', cursor: '', size: 20),
        (type: 'MEDIA', id: 'media', cursor: ' padded ', size: 20),
        (type: 'MEDIA', id: 'media', cursor: 'a' * 1025, size: 20),
      ]) {
    test('invalid request never dispatches: ${arguments.type}, size '
        '${arguments.size}, id length ${arguments.id.length}, cursor length '
        '${arguments.cursor?.length}', () async {
      final api = RecordingApiClient((_) => _page());
      final result = await EngagementRepositoryImpl(api).listLikeUsers(
        targetType: arguments.type,
        targetId: arguments.id,
        cursor: arguments.cursor,
        size: arguments.size,
      );
      expect(result.isSuccess, isFalse);
      expect(api.requests, isEmpty);
    });
  }

  for (final code in ['401', '403', '404', 'network']) {
    test('$code is retained without substituting another target', () async {
      final api = RecordingApiClient(
        (_) => throw ApiException(AppError(code: code, message: 'Unavailable')),
      );
      final result = await EngagementRepositoryImpl(
        api,
      ).listLikeUsers(targetType: 'EVENT_POST', targetId: 'post');
      expect(result.error?.code, code);
      expect(result.data, isNull);
      expect(api.requests, hasLength(1));
      expect(api.lastRequest.path, '/api/v1/likes/EVENT_POST/post/users');
    });
  }

  for (final initial in [
    const AuthSession.guest(),
    audienceSession(status: 'PENDING_STUDIO_REQUEST'),
    AuthSession.authenticated(
      token: 'token',
      userId: 'listener',
      username: 'listener',
      accountStatus: 'ACTIVE',
      roles: const ['ROLE_LISTENER'],
      permissions: const [],
      expiresAt: DateTime.utc(2100),
      isAdmin: false,
      requiresListenerProfileChoice: true,
    ),
  ]) {
    test('ineligible session cannot dispatch a like-users read', () async {
      final sessions = AudienceTestSessions(initial);
      addTearDown(sessions.dispose);
      final api = RecordingApiClient((_) => _page());
      final result = await EngagementRepositoryImpl(
        api,
        sessions: sessions,
      ).listLikeUsers(targetType: 'EVENT', targetId: 'event');
      expect(result.error?.code, 'engagement_comment_session_changed');
      expect(api.requests, isEmpty);
    });
  }

  for (final nextSession in [
    const AuthSession.guest(),
    audienceSession(user: 'other'),
    audienceSession(token: 'replacement-token'),
  ]) {
    for (final fails in [false, true]) {
      test(
        'changed session discards ${fails ? 'failure' : 'identity data'}',
        () async {
          final sessions = AudienceTestSessions(audienceSession());
          addTearDown(sessions.dispose);
          final pending = Completer<Object?>();
          final api = RecordingApiClient((_) => pending.future);
          final reading = EngagementRepositoryImpl(
            api,
            sessions: sessions,
          ).listLikeUsers(targetType: 'MEDIA', targetId: 'media');
          sessions.replace(nextSession);
          if (fails) {
            pending.completeError(
              ApiException(const AppError(code: '403', message: 'Forbidden')),
            );
          } else {
            pending.complete(_page());
          }
          final result = await reading;
          expect(result.error?.code, 'engagement_comment_session_changed');
          expect(result.data, isNull);
        },
      );
    }
  }
}

Map<String, Object?> _user({
  String id = 'liker',
  String username = 'leylasaman',
  String? avatarUrl,
  String? visibilityMode,
}) => {
  'id': id,
  'username': username,
  'avatarUrl': avatarUrl,
  if (visibilityMode != null) 'visibilityMode': visibilityMode,
};

Map<String, Object?> _page({
  Object? items,
  Object? nextCursor,
  bool hasMore = false,
}) => {
  'items': items ?? [_user()],
  'nextCursor': nextCursor,
  'hasMore': hasMore,
};
