import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_text.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  final routingSessions = <String, AuthSession>{
    'listener': audienceSession(),
    'musician': audienceSession(role: 'ROLE_MUSICIAN'),
    'venue': audienceSession(role: 'ROLE_VENUE'),
    'guest': const AuthSession.guest(),
    'inactive': audienceSession(status: 'SUSPENDED'),
    'missing identity': audienceSession(user: ''),
    'pending profile choice': AuthSession.authenticated(
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
  };
  for (final entry in routingSessions.entries) {
    for (final replies in [false, true]) {
      test(
        '${entry.key} uses the correct identity route for event ${replies ? 'replies' : 'roots'}',
        () async {
          final personal = const {
            'listener',
            'musician',
            'venue',
          }.contains(entry.key);
          final sessions = AudienceTestSessions(entry.value);
          addTearDown(sessions.dispose);
          final api = RecordingApiClient(
            (_) => _page(
              comment: {
                ..._comment(),
                'parentCommentId': replies ? 'root/a' : null,
                'likeCount': 3,
                'likedByMe': personal,
              },
            ),
          );
          final repository = EngagementRepositoryImpl(api, sessions: sessions);
          final result = replies
              ? await repository.listReplyPage('root/a', eventId: 'event/a')
              : await repository.listComments(
                  targetType: 'EVENT',
                  targetId: 'event/a',
                );
          expect(result.isSuccess, isTrue, reason: '${result.error}');
          expect(result.data!.items.single.likedByMe, personal);
          expect(api.requests, hasLength(1));
          expect(
            api.lastRequest.path,
            personal
                ? (replies
                      ? '/api/v1/comments/replies/root%2Fa'
                      : '/api/v1/comments/EVENT/event%2Fa')
                : (replies
                      ? '/api/v1/events/event%2Fa/comments/root%2Fa/replies'
                      : '/api/v1/events/event%2Fa/comments'),
          );
          expect(
            api.lastRequest.requestContext!.requireGuestSession,
            !entry.value.isAuthenticated,
          );
          expect(
            api.lastRequest.requestContext!.expectedSessionKey,
            entry.value.isAuthenticated ? entry.value.userId : null,
          );
        },
      );
    }
  }

  test(
    'authenticated event page rejection never retries as an anonymous page',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final api = RecordingApiClient(
        (_) => throw ApiException(
          const AppError(code: '401', message: 'Oturum geçersiz.'),
        ),
      );
      final result = await EngagementRepositoryImpl(
        api,
        sessions: sessions,
      ).listComments(targetType: 'EVENT', targetId: 'event');
      expect(result.error!.code, '401');
      expect(api.requests, hasLength(1));
      expect(api.lastRequest.path, '/api/v1/comments/EVENT/event');
    },
  );

  for (final payload in <Object?>[
    null,
    {},
    {'content': [], 'totalElements': -1},
    {
      'content': ['invalid'],
      'totalElements': 1,
    },
    {
      'content': [_comment(), _comment()],
      'totalElements': 2,
    },
    {
      'content': [
        {..._comment(), 'id': 7},
      ],
      'totalElements': 1,
    },
    {
      'content': [
        {..._comment(), 'text': 7},
      ],
      'totalElements': 1,
    },
    {
      'content': [
        {..._comment(), 'deleted': 'false'},
      ],
      'totalElements': 1,
    },
    {
      'content': [
        {..._comment(), 'replyCount': -1},
      ],
      'totalElements': 1,
    },
    {
      'content': [
        {..._comment(), 'user': 'not-an-author'},
      ],
      'totalElements': 1,
    },
    {
      'content': [
        {..._comment(), 'parentCommentId': 'another-root'},
      ],
      'totalElements': 1,
    },
    {..._page(), 'number': 1},
    {..._page(), 'size': 100},
    {..._page(), 'first': 'true'},
  ]) {
    test(
      'malformed comment page fails instead of showing empty/synthetic data: $payload',
      () async {
        final api = RecordingApiClient((_) => payload);
        final result = await EngagementRepositoryImpl(
          api,
        ).listComments(targetType: 'EVENT', targetId: 'event');
        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
      },
    );
  }

  test(
    'anonymous flag strips even accidentally supplied identifying fields',
    () async {
      final api = RecordingApiClient(
        (_) => _page(
          comment: {
            ..._comment(),
            'anonymousAuthor': true,
            'user': {
              'id': 'private-user',
              'username': 'private-name',
              'avatarUrl': 'https://example.test/private.png',
            },
          },
        ),
      );
      final result = await EngagementRepositoryImpl(
        api,
      ).listComments(targetType: 'EVENT', targetId: 'event');
      final author = result.data!.items.single.user;
      expect(author.id, isEmpty);
      expect(author.username, 'Anonymous Author');
      expect(author.avatarUrl, isNull);
    },
  );

  test(
    'reply page retains metadata and rejects another parent projection',
    () async {
      var wrongParent = false;
      final api = RecordingApiClient(
        (_) => {
          'content': [
            {..._comment(), 'parentCommentId': wrongParent ? 'other' : 'root'},
          ],
          'number': 2,
          'size': 20,
          'totalElements': 41,
          'totalPages': 3,
          'first': false,
          'last': true,
        },
      );
      final repository = EngagementRepositoryImpl(api);
      final result = await repository.listReplyPage(
        'root',
        eventId: 'event',
        page: 2,
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.page, 2);
      expect(result.data!.size, 20);
      expect(result.data!.totalElements, 41);
      expect(result.data!.hasMore, isFalse);
      expect(api.lastRequest.query, {
        'page': 2,
        'size': 20,
        'sort': 'createdAt,asc',
      });
      wrongParent = true;
      expect(
        (await repository.listReplyPage(
          'root',
          eventId: 'event',
          page: 2,
        )).isSuccess,
        isFalse,
      );
    },
  );

  test('all generic comment path components are encoded', () async {
    final api = RecordingApiClient((_) => _comment());
    final repository = EngagementRepositoryImpl(api);
    await repository.createComment(
      targetType: 'MEDIA/x',
      targetId: 'media/x',
      text: 'Merhaba',
    );
    expect(api.lastRequest.path, '/api/v1/comments/MEDIA%2Fx/media%2Fx');
    await repository.deleteComment(commentId: 'comment/x');
    expect(api.lastRequest.path, '/api/v1/comments/comment%2Fx');
    await repository.listReplies('parent/x');
    expect(api.lastRequest.path, '/api/v1/comments/replies/parent%2Fx');
  });

  test(
    'UTF16 limit matches server and invalid request does not dispatch',
    () async {
      expect(CommentText.isValid('😀' * 250), isTrue);
      expect(CommentText.isValid('😀' * 251), isFalse);
      expect(CommentText.length('  😀  '), 2);
      final api = RecordingApiClient((_) => _comment());
      final repository = EngagementRepositoryImpl(api);
      expect(
        (await repository.createComment(
          targetType: 'EVENT',
          targetId: 'event',
          text: '😀' * 251,
        )).isSuccess,
        isFalse,
      );
      expect(
        (await repository.listComments(
          targetType: 'EVENT',
          targetId: 'event',
          page: 1001,
        )).isSuccess,
        isFalse,
      );
      expect(api.requests, isEmpty);
    },
  );

  test(
    'guest can request public event read but cannot write or read private media',
    () async {
      final sessions = AudienceTestSessions(const AuthSession.guest());
      final api = RecordingApiClient((_) => _page());
      final repository = EngagementRepositoryImpl(api, sessions: sessions);
      expect(
        (await repository.listComments(
          targetType: 'EVENT',
          targetId: 'event',
        )).isSuccess,
        isTrue,
      );
      expect(api.lastRequest.requestContext!.requireGuestSession, isTrue);
      expect(
        (await repository.createComment(
          targetType: 'EVENT',
          targetId: 'event',
          text: 'Merhaba',
        )).isSuccess,
        isFalse,
      );
      expect(
        (await repository.listComments(
          targetType: 'MEDIA',
          targetId: 'media',
        )).isSuccess,
        isFalse,
      );
      expect(api.requests, hasLength(1));
    },
  );

  test(
    'account-changing late write is not confirmed and carries transport fence',
    () async {
      final pending = Completer<Object?>();
      final sessions = AudienceTestSessions(audienceSession());
      final api = RecordingApiClient((_) => pending.future);
      final repository = EngagementRepositoryImpl(api, sessions: sessions);
      final write = repository.createComment(
        targetType: 'EVENT',
        targetId: 'event',
        text: 'Merhaba',
      );
      expect(api.lastRequest.requestContext!.expectedSessionKey, 'listener');
      sessions.replace(audienceSession(user: 'other', token: 'other'));
      pending.complete(_comment());
      expect((await write).error!.code, 'engagement_comment_session_changed');
      expect(api.requests, hasLength(1));
    },
  );

  for (final code in ['network', '500', '503']) {
    test(
      'ambiguous $code POST is never retried and asks to review existing comments',
      () async {
        final api = RecordingApiClient(
          (_) => throw ApiException(
            AppError(code: code, message: 'raw transport failure'),
          ),
        );
        final result = await EngagementRepositoryImpl(api).createComment(
          targetType: 'EVENT',
          targetId: 'event',
          text: 'Merhaba',
        );
        expect(
          result.error!.message,
          'Sonuç doğrulanamadı. Tekrar göndermeden yorumları kontrol et.',
        );
        expect(api.requests, hasLength(1));
      },
    );
  }

  for (final replies in [false, true]) {
    for (final page in [0, 1]) {
      test(
        'contradictory empty ${replies ? 'reply' : 'root'} page $page fails instead of advancing blindly',
        () async {
          final api = RecordingApiClient(
            (_) => {
              'content': [],
              'totalElements': 400,
              'number': page,
              'size': 50,
              'totalPages': 8,
              'first': page == 0,
              'last': false,
            },
          );
          final repository = EngagementRepositoryImpl(api);
          final result = replies
              ? await repository.listReplyPage(
                  'root',
                  eventId: 'event',
                  page: page,
                  size: 50,
                )
              : await repository.listComments(
                  targetType: 'EVENT',
                  targetId: 'event',
                  page: page,
                  size: 50,
                );
          expect(result.isSuccess, isFalse);
          expect(result.data, isNull);
          expect(api.requests, hasLength(1));
        },
      );
    }
    test(
      'valid terminal empty ${replies ? 'reply' : 'root'} page remains accepted after total shrinks',
      () async {
        final api = RecordingApiClient(
          (_) => {
            'content': [],
            'totalElements': 50,
            'number': 1,
            'size': 50,
            'totalPages': 1,
            'first': false,
            'last': true,
          },
        );
        final repository = EngagementRepositoryImpl(api);
        final result = replies
            ? await repository.listReplyPage(
                'root',
                eventId: 'event',
                page: 1,
                size: 50,
              )
            : await repository.listComments(
                targetType: 'EVENT',
                targetId: 'event',
                page: 1,
                size: 50,
              );
        expect(result.isSuccess, isTrue);
        expect(result.data!.items, isEmpty);
        expect(result.data!.hasMore, isFalse);
      },
    );
  }

  test(
    '400 server roots decode only fifty per requested page and reject an unbounded response',
    () async {
      var oversized = false;
      final rows = List.generate(
        400,
        (index) => {..._comment(), 'id': 'root-$index'},
      );
      final api = RecordingApiClient((request) {
        final page = request.query!['page'] as int;
        return {
          'content': oversized ? rows : rows.skip(page * 50).take(50).toList(),
          'totalElements': 400,
          'number': page,
          'size': 50,
          'totalPages': 8,
          'first': page == 0,
          'last': page == 7,
        };
      });
      final repository = EngagementRepositoryImpl(api);
      final ids = <String>[];
      for (var page = 0; page < 8; page++) {
        final result = await repository.listComments(
          targetType: 'EVENT',
          targetId: 'event',
          page: page,
          size: 50,
        );
        expect(result.isSuccess, isTrue);
        expect(result.data!.items, hasLength(50));
        expect(result.data!.hasMore, page < 7);
        ids.addAll(result.data!.items.map((item) => item.id));
      }
      expect(ids.toSet(), hasLength(400));
      expect(api.requests, hasLength(8));
      oversized = true;
      final invalid = await repository.listComments(
        targetType: 'EVENT',
        targetId: 'event',
        size: 50,
      );
      expect(invalid.isSuccess, isFalse);
    },
  );

  test(
    'contradictory empty response keeps cached roots and retries the same page through the cubit',
    () async {
      var repaired = false;
      final api = RecordingApiClient((request) {
        final page = request.query!['page'] as int;
        return {
          'content': page == 1 && !repaired
              ? []
              : List.generate(
                  50,
                  (index) => {..._comment(), 'id': 'root-${page * 50 + index}'},
                ),
          'totalElements': 400,
          'number': page,
          'size': 50,
          'totalPages': 8,
          'first': page == 0,
          'last': false,
        };
      });
      final cubit = CommentThreadCubit(EngagementRepositoryImpl(api));
      addTearDown(cubit.close);
      await cubit.load(targetType: 'EVENT', targetId: 'event');
      final original = cubit.state.comments.first;
      await cubit.loadMore();
      expect(cubit.state.comments, hasLength(50));
      expect(cubit.state.comments.first, same(original));
      expect(cubit.state.loadingMore, isFalse);
      expect(cubit.state.hasMore, isTrue);
      expect(cubit.state.error, isNotNull);
      expect(api.requests.map((request) => request.query!['page']), [0, 1]);
      repaired = true;
      await cubit.loadMore();
      expect(api.requests.map((request) => request.query!['page']), [0, 1, 1]);
      expect(cubit.state.comments, hasLength(100));
      expect(cubit.state.error, isNull);
    },
  );
}

Map<String, Object?> _comment() => {
  'id': 'comment',
  'text': 'Merhaba',
  'parentCommentId': null,
  'deleted': false,
  'anonymousAuthor': false,
  'replyCount': 0,
  'user': {
    'id': 'user',
    'username': 'Ada',
    'avatarUrl': 'https://example.test/avatar.png',
  },
};

Map<String, Object?> _page({Map<String, Object?>? comment}) => {
  'content': [comment ?? _comment()],
  'totalElements': 1,
  'number': 0,
  'size': 20,
  'totalPages': 1,
  'first': true,
  'last': true,
};
