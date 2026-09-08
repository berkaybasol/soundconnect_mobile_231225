import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/models/comment_item_model.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_like_state.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

enum _Operation { like, unlike, read }

void main() {
  for (final operation in _Operation.values) {
    test(
      '$operation uses desired-state method, encoded identity and session fence',
      () async {
        final sessions = AudienceTestSessions(audienceSession());
        addTearDown(sessions.dispose);
        final api = RecordingApiClient(
          (_) => _likes(count: 7, liked: operation != _Operation.unlike),
        );
        final repository = EngagementRepositoryImpl(api, sessions: sessions);
        final result = await _request(
          repository,
          operation,
          'comment/ç?x=1#tail',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data!.likeCount, 7);
        expect(result.data!.likedByMe, operation != _Operation.unlike);
        expect(api.requests, hasLength(1));
        final request = api.lastRequest;
        expect(request.method, switch (operation) {
          _Operation.like => RecordedHttpMethod.post,
          _Operation.unlike => RecordedHttpMethod.delete,
          _Operation.read => RecordedHttpMethod.get,
        });
        expect(
          request.path,
          '/api/v1/likes/COMMENT/comment%2F%C3%A7%3Fx%3D1%23tail${operation == _Operation.read ? '/state' : ''}',
        );
        expect(request.body, isNull);
        expect(request.query, isNull);
        expect(request.requestContext!.expectedSessionKey, 'listener');
        expect(request.requestContext!.requireGuestSession, isFalse);
      },
    );

    test('$operation rejects invalid identities before dispatch', () async {
      final api = RecordingApiClient((_) => _likes());
      final repository = EngagementRepositoryImpl(api);
      for (final id in ['', ' ', ' leading', 'trailing ', 'x' * 129]) {
        final result = await _request(repository, operation, id);
        expect(result.isSuccess, isFalse, reason: id);
        expect(result.data, isNull);
      }
      expect(api.requests, isEmpty);
    });

    for (final entry in <String, AuthSession>{
      'guest': const AuthSession.guest(),
      'inactive': audienceSession(status: 'SUSPENDED'),
      'pending business': audienceSession(status: 'PENDING_VENUE_REQUEST'),
      'pending listener profile': _pendingProfile(),
      'missing user': audienceSession(user: ' '),
    }.entries) {
      test('$operation rejects ${entry.key} without API calls', () async {
        final sessions = AudienceTestSessions(entry.value);
        addTearDown(sessions.dispose);
        final api = RecordingApiClient((_) => _likes());
        final repository = EngagementRepositoryImpl(api, sessions: sessions);
        final result = await _request(repository, operation);
        expect(result.error!.code, 'engagement_comment_session_changed');
        expect(result.data, isNull);
        expect(api.requests, isEmpty);
      });
    }

    for (final change in [
      'logout',
      'account',
      'same-user token',
      'same-user profile choice',
    ]) {
      test('$operation discards late success after $change', () async {
        final sessions = AudienceTestSessions(audienceSession());
        addTearDown(sessions.dispose);
        final pending = Completer<Object?>();
        final api = RecordingApiClient((_) => pending.future);
        final repository = EngagementRepositoryImpl(api, sessions: sessions);
        final request = _request(repository, operation);
        sessions.replace(switch (change) {
          'logout' => const AuthSession.guest(),
          'account' => audienceSession(user: 'other', token: 'other'),
          'same-user token' => audienceSession(token: 'renewed'),
          _ => _pendingProfile(),
        });
        pending.complete(_likes(count: 3, liked: true));
        final result = await request;
        expect(result.error!.code, 'engagement_comment_session_changed');
        expect(result.data, isNull);
        expect(api.requests, hasLength(1));
      });
    }

    test(
      '$operation stale-session failure wins over transport error',
      () async {
        final sessions = AudienceTestSessions(audienceSession());
        addTearDown(sessions.dispose);
        final pending = Completer<Object?>();
        final api = RecordingApiClient((_) => pending.future);
        final repository = EngagementRepositoryImpl(api, sessions: sessions);
        final request = _request(repository, operation);
        sessions.replace(const AuthSession.guest());
        pending.completeError(
          ApiException(const AppError(code: '503', message: 'server')),
        );
        expect(
          (await request).error!.code,
          'engagement_comment_session_changed',
        );
        expect(api.requests, hasLength(1));
      },
    );

    test(
      '$operation fails closed for all malformed like projections',
      () async {
        for (final raw in _malformed) {
          final api = RecordingApiClient((_) => raw);
          final result = await _request(
            EngagementRepositoryImpl(api),
            operation,
          );
          expect(result.isSuccess, isFalse, reason: '$raw');
          expect(result.data, isNull, reason: '$raw');
          expect(api.requests, hasLength(1));
        }
      },
    );

    test('$operation accepts valid zero and maximum exact count', () async {
      for (final count in [0, 9007199254740991]) {
        final api = RecordingApiClient((_) => _likes(count: count));
        final result = await _request(EngagementRepositoryImpl(api), operation);
        expect(result.data!.likeCount, count);
        expect(result.data!.likedByMe, isFalse);
      }
    });

    test(
      '$operation never retries an uncertain transport result automatically',
      () async {
        final api = RecordingApiClient(
          (_) => throw ApiException(
            const AppError(
              code: 'network',
              message: 'Bağlantı kurulamadı. İnternet bağlantını kontrol et.',
            ),
          ),
        );
        final result = await _request(EngagementRepositoryImpl(api), operation);
        expect(result.isSuccess, isFalse);
        expect(result.error!.code, 'network');
        expect(
          result.error!.message,
          'Bağlantı kurulamadı. İnternet bağlantını kontrol et.',
        );
        await Future<void>.delayed(Duration.zero);
        expect(api.requests, hasLength(1));
      },
    );
  }

  test('repeated desired-state writes do not toggle the local count', () async {
    final api = RecordingApiClient(
      (request) => _likes(
        count: request.method == RecordedHttpMethod.post ? 5 : 4,
        liked: request.method == RecordedHttpMethod.post,
      ),
    );
    final repository = EngagementRepositoryImpl(api);
    for (final liked in [true, true, false, false]) {
      final result = await repository.setCommentLike(
        commentId: 'root',
        liked: liked,
      );
      expect(result.data!.likeCount, liked ? 5 : 4);
      expect(result.data!.likedByMe, liked);
    }
    expect(api.requests.map((request) => request.method), [
      RecordedHttpMethod.post,
      RecordedHttpMethod.post,
      RecordedHttpMethod.delete,
      RecordedHttpMethod.delete,
    ]);
  });

  for (final target in ['EVENT', 'MEDIA', 'OVERTHINKING']) {
    for (final replies in [false, true]) {
      test(
        '$target ${replies ? 'reply' : 'root'} page preserves per-comment likes and legacy defaults',
        () async {
          final api = RecordingApiClient(
            (_) => {
              'content': [
                _comment(
                  'liked',
                  replies: replies,
                  likes: _likes(count: 9, liked: true),
                ),
                _comment('legacy', replies: replies),
                _comment(
                  'deleted',
                  replies: replies,
                  deleted: true,
                  likes: _likes(count: 9, liked: true),
                ),
              ],
              'number': 0,
              'size': 20,
              'totalElements': 3,
              'totalPages': 1,
              'first': true,
              'last': true,
            },
          );
          final repository = EngagementRepositoryImpl(api);
          final result = replies
              ? await repository.listReplyPage(
                  'root',
                  eventId: target == 'EVENT' ? 'event' : null,
                )
              : await repository.listComments(
                  targetType: target,
                  targetId: 'target',
                );
          expect(result.isSuccess, isTrue);
          expect(result.data!.totalElements, 3);
          expect(result.data!.items.map((item) => item.likeCount), [9, 0, 0]);
          expect(result.data!.items.map((item) => item.likedByMe), [
            true,
            false,
            false,
          ]);
          expect(
            result.data!.items.first.parentCommentId,
            replies ? 'root' : null,
          );
          expect(api.requests, hasLength(1));
        },
      );
    }
  }

  for (final replies in [false, true]) {
    test(
      '${replies ? 'reply' : 'root'} page rejects present partial or malformed like metadata',
      () async {
        for (final raw in _malformed.whereType<Map<String, dynamic>>()) {
          if (raw.isEmpty) {
            continue; // Both absent is the supported legacy form.
          }
          final api = RecordingApiClient(
            (_) => {
              'content': [_comment('comment', replies: replies, likes: raw)],
              'number': 0,
              'size': 20,
              'totalElements': 1,
            },
          );
          final repository = EngagementRepositoryImpl(api);
          final result = replies
              ? await repository.listReplyPage('root', eventId: 'event')
              : await repository.listComments(
                  targetType: 'EVENT',
                  targetId: 'event',
                );
          expect(result.isSuccess, isFalse, reason: '$raw');
          expect(result.data, isNull);
        }
      },
    );
  }

  test(
    'direct comment model preserves author privacy alongside like metadata',
    () {
      final item = CommentItemModel.fromJson({
        ..._comment('anonymous', likes: _likes(count: 2, liked: true)),
        'anonymousAuthor': true,
      });
      expect(item.likeCount, 2);
      expect(item.likedByMe, isTrue);
      expect(item.user.id, isEmpty);
      expect(item.user.username, 'Anonymous Author');
      expect(item.user.avatarUrl, isNull);
    },
  );
}

Future<Result<CommentLikeState>> _request(
  EngagementRepositoryImpl repository,
  _Operation operation, [
  String id = 'root',
]) => switch (operation) {
  _Operation.like => repository.setCommentLike(commentId: id, liked: true),
  _Operation.unlike => repository.setCommentLike(commentId: id, liked: false),
  _Operation.read => repository.readCommentLike(commentId: id),
};

Map<String, dynamic> _likes({int count = 0, bool liked = false}) => {
  'likeCount': count,
  'likedByMe': liked,
};

Map<String, dynamic> _comment(
  String id, {
  bool replies = false,
  bool deleted = false,
  Map<String, dynamic>? likes,
}) => {
  'id': id,
  'text': 'Yorum',
  'deleted': deleted,
  'user': {
    'id': 'author',
    'username': 'Yazar',
    'avatarUrl': 'https://example.test/avatar.png',
  },
  'parentCommentId': replies ? 'root' : null,
  'replyCount': 0,
  'createdAt': '2026-09-09T09:00:00Z',
  ...?likes,
};

AuthSession _pendingProfile() => AuthSession.authenticated(
  token: 'token',
  userId: 'listener',
  username: 'listener',
  accountStatus: 'ACTIVE',
  roles: const ['ROLE_LISTENER'],
  permissions: const [],
  expiresAt: DateTime.utc(2100),
  isAdmin: false,
  requiresListenerProfileChoice: true,
);

final _malformed = <Object?>[
  null,
  [],
  'not a state',
  <String, dynamic>{},
  {'likeCount': 1},
  {'likedByMe': false},
  {'likeCount': null, 'likedByMe': false},
  {'likeCount': -1, 'likedByMe': false},
  {'likeCount': 1.0, 'likedByMe': true},
  {'likeCount': '1', 'likedByMe': true},
  {'likeCount': 9007199254740992, 'likedByMe': false},
  {'likeCount': 1, 'likedByMe': null},
  {'likeCount': 1, 'likedByMe': 'true'},
  {'likeCount': 0, 'likedByMe': true},
];
