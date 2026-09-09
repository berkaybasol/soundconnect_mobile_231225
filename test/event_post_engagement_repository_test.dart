import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  test(
    'post comments and event comments use separate target namespaces',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final api = RecordingApiClient((_) => _page());
      final repository = EngagementRepositoryImpl(api, sessions: sessions);

      final post = await repository.listComments(
        targetType: 'EVENT_POST',
        targetId: audiencePostId,
      );
      final event = await repository.listComments(
        targetType: 'EVENT',
        targetId: audienceEventId,
      );
      expect(post.isSuccess, isTrue);
      expect(event.isSuccess, isTrue);
      expect(api.requests.map((request) => request.path), [
        '/api/v1/comments/EVENT_POST/$audiencePostId',
        '/api/v1/comments/EVENT/$audienceEventId',
      ]);
      expect(api.requests.first.requestContext!.expectedSessionKey, 'listener');
      expect(api.requests.first.query, {
        'page': 0,
        'size': 20,
        'sort': 'createdAt,desc',
      });
    },
  );

  test(
    'post root, reply, reply read and comment like retain post semantics',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final api = RecordingApiClient((request) {
        if (request.path.startsWith('/api/v1/likes/COMMENT/')) {
          return {'likeCount': 1, 'likedByMe': true};
        }
        if (request.method == RecordedHttpMethod.post) {
          return _comment(
            parentId: (request.body as Map)['parentCommentId'] as String?,
          );
        }
        return _page(parentId: 'root');
      });
      final repository = EngagementRepositoryImpl(api, sessions: sessions);
      final root = await repository.createComment(
        targetType: 'EVENT_POST',
        targetId: audiencePostId,
        text: '  Bu paylaşıma yorum  ',
      );
      final reply = await repository.createComment(
        targetType: 'EVENT_POST',
        targetId: audiencePostId,
        parentCommentId: 'root',
        text: 'Yanıt',
      );
      final replies = await repository.listReplyPage('root');
      final liked = await repository.setCommentLike(
        commentId: 'reply',
        liked: true,
      );
      expect(root.isSuccess, isTrue);
      expect(reply.isSuccess, isTrue);
      expect(replies.isSuccess, isTrue);
      expect(liked.isSuccess, isTrue);
      expect(api.requests.map((request) => request.path), [
        '/api/v1/comments/EVENT_POST/$audiencePostId',
        '/api/v1/comments/EVENT_POST/$audiencePostId',
        '/api/v1/comments/replies/root',
        '/api/v1/likes/COMMENT/reply',
      ]);
      expect(api.requests.first.body, {
        'text': 'Bu paylaşıma yorum',
        'parentCommentId': null,
      });
      expect(api.requests[1].body, {
        'text': 'Yanıt',
        'parentCommentId': 'root',
      });
    },
  );

  test(
    'post target is accepted by like reads and desired-state writes',
    () async {
      final api = RecordingApiClient((request) {
        if (request.path.endsWith('/count')) return 2;
        if (request.path.endsWith('/is-liked')) return true;
        return null;
      });
      final repository = EngagementRepositoryImpl(api);
      expect(
        (await repository.getLikeCount(
          targetType: 'EVENT_POST',
          targetId: audiencePostId,
        )).data,
        2,
      );
      expect(
        (await repository.isLiked(
          targetType: 'EVENT_POST',
          targetId: audiencePostId,
        )).data,
        isTrue,
      );
      expect(
        (await repository.like(
          targetType: 'EVENT_POST',
          targetId: audiencePostId,
        )).isSuccess,
        isTrue,
      );
      expect(
        (await repository.unlike(
          targetType: 'EVENT_POST',
          targetId: audiencePostId,
        )).isSuccess,
        isTrue,
      );
      expect(api.requests.map((request) => request.method), [
        RecordedHttpMethod.get,
        RecordedHttpMethod.get,
        RecordedHttpMethod.post,
        RecordedHttpMethod.delete,
      ]);
      expect(
        api.requests.every(
          (request) => request.path.startsWith(
            '/api/v1/likes/EVENT_POST/$audiencePostId',
          ),
        ),
        isTrue,
      );
    },
  );

  for (final code in ['403', '404']) {
    test(
      'unavailable post comments never fall back to event comments ($code)',
      () async {
        final sessions = AudienceTestSessions(audienceSession());
        addTearDown(sessions.dispose);
        final api = RecordingApiClient(
          (_) =>
              throw ApiException(AppError(code: code, message: 'Unavailable')),
        );
        final result = await EngagementRepositoryImpl(
          api,
          sessions: sessions,
        ).listComments(targetType: 'EVENT_POST', targetId: audiencePostId);
        expect(result.error!.code, code);
        expect(api.requests, hasLength(1));
        expect(
          api.lastRequest.path,
          '/api/v1/comments/EVENT_POST/$audiencePostId',
        );
      },
    );
  }

  test(
    'guest cannot read a post through the anonymous event adapter',
    () async {
      final sessions = AudienceTestSessions(const AuthSession.guest());
      addTearDown(sessions.dispose);
      final api = RecordingApiClient((_) => _page());
      final result = await EngagementRepositoryImpl(
        api,
        sessions: sessions,
      ).listComments(targetType: 'EVENT_POST', targetId: audiencePostId);
      expect(result.isSuccess, isFalse);
      expect(api.requests, isEmpty);
    },
  );

  test('post comment response is discarded after an account switch', () async {
    final sessions = AudienceTestSessions(audienceSession());
    addTearDown(sessions.dispose);
    final pending = Completer<Object?>();
    final api = RecordingApiClient((_) => pending.future);
    final reading = EngagementRepositoryImpl(
      api,
      sessions: sessions,
    ).listComments(targetType: 'EVENT_POST', targetId: audiencePostId);
    sessions.replace(audienceSession(user: 'other'));
    pending.complete(_page());
    final result = await reading;
    expect(result.error!.code, 'engagement_comment_session_changed');
    expect(result.data, isNull);
  });
}

Map<String, Object?> _comment({String? parentId}) => {
  'id': parentId == null ? 'root' : 'reply',
  'text': parentId == null ? 'Bu paylaşıma yorum' : 'Yanıt',
  'parentCommentId': parentId,
  'deleted': false,
  'anonymousAuthor': false,
  'replyCount': 0,
  'user': {'id': 'listener', 'username': 'berna'},
};

Map<String, Object?> _page({String? parentId}) => {
  'content': [_comment(parentId: parentId)],
  'totalElements': 1,
  'number': 0,
  'size': 20,
  'totalPages': 1,
  'first': true,
  'last': true,
};
