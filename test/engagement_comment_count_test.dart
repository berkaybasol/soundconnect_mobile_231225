import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/preview/data/preview_scenario_store.dart';
import 'package:soundconnect_23_12_25codx/preview/runtime/preview_session.dart';
import 'package:soundconnect_23_12_25codx/preview/services/preview_api_client.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  for (final role in ['ROLE_MUSICIAN', 'ROLE_LISTENER', 'ROLE_VENUE']) {
    for (final type in ['MEDIA', 'ANNOUNCEMENT']) {
      test(
        '$role reads the active $type comment total in its session',
        () async {
          final sessions = AudienceTestSessions(audienceSession(role: role));
          addTearDown(sessions.dispose);
          final api = RecordingApiClient((_) => 5);
          final result = await EngagementRepositoryImpl(
            api,
            sessions: sessions,
            announcementSource: type == 'ANNOUNCEMENT' ? 'FEED' : null,
          ).getCommentCount(targetType: type, targetId: 'content/id');

          expect(result.data, 5);
          expect(api.requests, hasLength(1));
          expect(api.lastRequest.method, RecordedHttpMethod.get);
          expect(
            api.lastRequest.path,
            '/api/v1/comments/$type/content%2Fid/count',
          );
          expect(api.lastRequest.query, isNull);
          expect(
            api.lastRequest.requestContext!.expectedSessionKey,
            sessions.session.userId,
          );
          expect(
            api.lastRequest.requestContext!.expectedToken,
            sessions.session.token,
          );
          expect(api.lastRequest.requestContext!.requireGuestSession, isFalse);
          expect(
            api.lastRequest.requestContext!.announcementSource,
            type == 'ANNOUNCEMENT' ? 'FEED' : null,
          );
        },
      );
    }
  }

  test(
    'zero is valid but root-page objects and malformed totals are rejected',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      for (final value in <Object?>[
        0,
        null,
        -1,
        1.5,
        '5',
        true,
        9007199254740992,
        {'totalElements': 2, 'content': <Object>[]},
      ]) {
        final api = RecordingApiClient((_) => value);
        final result = await EngagementRepositoryImpl(
          api,
          sessions: sessions,
        ).getCommentCount(targetType: 'MEDIA', targetId: 'media');
        expect(result.isSuccess, value == 0, reason: '$value');
        if (value == 0) {
          expect(result.data, 0);
        } else {
          expect(result.error!.code, 'engagement_comment_count_unknown');
        }
      }
    },
  );

  test(
    'guest, inactive and unfinished listener sessions do not dispatch a count',
    () async {
      for (final session in [
        const AuthSession.guest(),
        audienceSession(status: 'SUSPENDED'),
        audienceSession(user: ''),
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
        final sessions = AudienceTestSessions(session);
        addTearDown(sessions.dispose);
        final api = RecordingApiClient((_) => 5);
        final result = await EngagementRepositoryImpl(
          api,
          sessions: sessions,
        ).getCommentCount(targetType: 'MEDIA', targetId: 'media');
        expect(result.error!.code, 'engagement_comment_session_changed');
        expect(api.requests, isEmpty);
      }
    },
  );

  test(
    'unsupported targets and empty identities fail before dispatch',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      for (final target in [
        ('COMMENT', 'comment'),
        ('STUDIO', 'studio'),
        ('MEDIA', ' '),
      ]) {
        final api = RecordingApiClient((_) => 5);
        final result = await EngagementRepositoryImpl(
          api,
          sessions: sessions,
        ).getCommentCount(targetType: target.$1, targetId: target.$2);
        expect(result.isSuccess, isFalse);
        expect(api.requests, isEmpty);
      }
    },
  );

  for (final code in ['401', '403', '404', '503']) {
    test(
      'count $code does not fall back to a guest or a root-page total',
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
        ).getCommentCount(targetType: 'MEDIA', targetId: 'media');
        expect(result.error!.code, code);
        expect(api.requests, hasLength(1));
      },
    );
  }

  for (final transition in ['account', 'role', 'relogin']) {
    test('pending count is discarded after $transition change', () async {
      final oldSession = audienceSession();
      final sessions = AudienceTestSessions(oldSession);
      addTearDown(sessions.dispose);
      final response = Completer<Object?>();
      final api = RecordingApiClient((_) => response.future);
      final pending = EngagementRepositoryImpl(
        api,
        sessions: sessions,
      ).getCommentCount(targetType: 'MEDIA', targetId: 'media');
      if (transition == 'account') {
        sessions.replace(audienceSession(user: 'other'));
      } else if (transition == 'role') {
        sessions.replace(audienceSession(role: 'ROLE_MUSICIAN'));
      } else {
        sessions.replace(const AuthSession.guest());
        sessions.replace(audienceSession(token: 'new-token'));
      }
      response.complete(5);
      expect((await pending).error!.code, 'engagement_comment_session_changed');
    });
  }

  test(
    'preview count includes replies and excludes deleted roots without changing root paging',
    () async {
      final store = PreviewScenarioStore(now: DateTime.utc(2026, 9, 14));
      final sessions = await createPreviewSession();
      addTearDown(store.dispose);
      addTearDown(sessions.dispose);
      final api = PreviewApiClient(store, sessions);
      final repository = EngagementRepositoryImpl(api, sessions: sessions);
      final item = store.catalogue
          .firstWhere((s) => s.item.type == MusicianFeedItemType.track)
          .item;
      final target = item.engagement!;
      final initial = (await repository.getCommentCount(
        targetType: target.targetType,
        targetId: target.targetId,
      )).data!;
      final root = (await repository.createComment(
        targetType: target.targetType,
        targetId: target.targetId,
        text: 'root',
      )).data!;
      await repository.createComment(
        targetType: target.targetType,
        targetId: target.targetId,
        text: 'reply',
        parentCommentId: root.id,
      );
      await repository.deleteComment(commentId: root.id);
      final count = await repository.getCommentCount(
        targetType: target.targetType,
        targetId: target.targetId,
      );
      expect(count.data, initial + 1);
      final roots = await repository.listComments(
        targetType: target.targetType,
        targetId: target.targetId,
      );
      expect(
        roots.data!.items.any((row) => row.id == root.id && row.deleted),
        isTrue,
      );
      expect(
        roots.data!.items.every((row) => row.parentCommentId == null),
        isTrue,
      );
      expect(api.rejectedPaths, isEmpty);
    },
  );
}
