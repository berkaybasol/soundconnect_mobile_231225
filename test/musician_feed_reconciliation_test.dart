import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/band_follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/cubit/musician_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/cubit/musician_feed_state.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/navigation/musician_feed_navigation_coordinator.dart';

import 'support/announcement_fixtures.dart';
import 'support/event_audience_fakes.dart';

void main() {
  test('an unauthenticated first-read failure leaves loading state', () async {
    final sessions = AudienceTestSessions(const AuthSession.guest());
    addTearDown(sessions.dispose);
    final server = _FeedServer()
      ..responses.add(Future.value(const Result.failure(_readFailure)));
    final cubit = _cubit(server, sessions: sessions);
    await cubit.initialize();
    expect(cubit.state.status, MusicianFeedStatus.failure);
    expect(cubit.state.error?.code, _readFailure.code);
  });

  test('a later external unfollow replaces an accepted feed follow', () async {
    final server = _FollowServer();
    final sessions = _sessions();
    final cubit = _cubit(server, sessions: sessions, follow: server);
    await cubit.initialize();
    expect(_profile(cubit).followedByViewer, isFalse);

    expect(await cubit.followProfile('profile-card'), isTrue);
    expect(server.followed, isTrue);
    expect(cubit.state.items, isEmpty);

    // The existing public profile screen successfully unfollows this user.
    await server.unfollow(followerId: 'viewer-id', followingId: 'other-user');
    final fresh = _cubit(server, sessions: sessions, follow: server);
    await fresh.initialize();
    expect(_profile(fresh).followedByViewer, isFalse);

    await cubit.refresh();
    expect(_profile(cubit).followedByViewer, isFalse);
  });

  test('an in-flight refresh cannot roll back a pending follow', () async {
    final server = _FollowServer();
    final read = Completer<Result<MusicianFeedPage>>();
    final write = Completer<Result<void>>();
    final cubit = _cubit(server, follow: server);
    await cubit.initialize();
    server.responses.add(read.future);
    server.followFuture = write.future;

    final refreshing = cubit.refresh();
    final following = cubit.followProfile('profile-card');
    read.complete(Result.success(_page([_profileItem()])));
    await refreshing;
    expect(_profile(cubit).followedByViewer, isTrue);
    expect(cubit.state.pendingItemIds, contains('profile-card'));

    write.complete(const Result.success(null));
    expect(await following, isTrue);
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.pendingItemIds, isEmpty);
  });

  test(
    'a failed follow refresh keeps optimism until a successful read',
    () async {
      final server = _FollowServer();
      final cubit = _cubit(server, follow: server);
      await cubit.initialize();
      server.responses.add(Future.value(const Result.failure(_readFailure)));

      expect(await cubit.followProfile('profile-card'), isTrue);
      expect(_profile(cubit).followedByViewer, isTrue);
      await server.unfollow(followerId: 'viewer-id', followingId: 'other-user');
      await cubit.refresh();
      expect(_profile(cubit).followedByViewer, isFalse);
    },
  );

  test(
    'detail stats preserve 40 loaded cards, cursor and feed session',
    () async {
      final first = List.generate(20, (i) => _mediaItem('item-$i'));
      final second = List.generate(20, (i) => _mediaItem('item-${i + 20}'));
      final server = _FeedServer()
        ..enqueue(_page(first, cursor: 'page-2'))
        ..enqueue(_page(second, cursor: 'page-3'));
      final engagement = _Engagement()
        ..likeCount = 19
        ..commentCount = 8
        ..liked = true;
      final cubit = _cubit(server, engagement: engagement);
      await cubit.initialize();
      await cubit.loadMore();
      final before = cubit.state;

      await cubit.refreshEngagement(first.first);

      expect(
        cubit.state.items.map((item) => item.id),
        before.items.map((item) => item.id),
      );
      expect(cubit.state.items, hasLength(40));
      expect(cubit.state.feedSessionId, before.feedSessionId);
      expect(cubit.state.nextCursor, 'page-3');
      expect(cubit.state.hasMore, isTrue);
      expect(cubit.state.generatedAt, before.generatedAt);
      expect(server.cursors, [null, 'page-2']);
      expect(
        cubit.state.items.map((item) => item.engagement!.likeCount),
        everyElement(19),
      );
      expect(
        cubit.state.items.map((item) => item.engagement!.commentCount),
        everyElement(8),
      );
      expect(
        cubit.state.items.map((item) => item.engagement!.likedByMe),
        everyElement(isTrue),
      );
      expect(engagement.commentReads.single, (type: 'MEDIA', id: 'media-id'));
    },
  );

  test(
    'detail return preserves five active comments across two root threads',
    () async {
      final item = _mediaItem('item').copyWith(
        engagement: _mediaItem('item').engagement!.copyWith(commentCount: 5),
      );
      final server = _FeedServer()..enqueue(_page([item]));
      final engagement = _Engagement()
        ..commentCount = 5
        ..rootCommentCount = 2;
      final cubit = _cubit(server, engagement: engagement);
      await cubit.initialize();
      await cubit.refreshEngagement(item);
      expect(cubit.state.items.single.engagement!.commentCount, 5);
      expect(engagement.commentReads, [(type: 'MEDIA', id: 'media-id')]);
      expect(engagement.rootCommentReads, 0);
    },
  );

  for (final delta in [1, -1]) {
    test('a direct comment delta $delta reaches a late alias page', () async {
      final item = _mediaItem('native');
      final page = Completer<Result<MusicianFeedPage>>();
      final server = _FeedServer()
        ..enqueue(_page([item], cursor: 'page-2'))
        ..responses.add(page.future);
      final cubit = _cubit(server);
      await cubit.initialize();
      final paging = cubit.loadMore();
      cubit.adjustCommentCount(item.id, delta);
      page.complete(Result.success(_page([_mediaItem('activity')])));
      await paging;
      expect(cubit.state.items, hasLength(2));
      expect(
        cubit.state.items.map((item) => item.engagement!.commentCount),
        everyElement(1 + delta),
      );
      expect(
        cubit.state.items.map((item) => item.engagement!.likeCount),
        everyElement(2),
      );
    });
  }

  for (final detailFinishesFirst in [true, false]) {
    for (final refreshSucceeds in [true, false]) {
      test(
        'older detail read stays scoped to the retained page '
        '(detail finishes first=$detailFinishesFirst refresh success=$refreshSucceeds)',
        () async {
          final item = _mediaItem('item');
          final page = Completer<Result<MusicianFeedPage>>();
          final stats = Completer<Result<int>>();
          final server = _FeedServer()
            ..enqueue(_page([item]))
            ..responses.add(page.future);
          final engagement = _Engagement()
            ..liked = true
            ..commentCount = 7
            ..likeCountFuture = stats.future;
          final cubit = _cubit(server, engagement: engagement);
          await cubit.initialize();
          final reading = cubit.refreshEngagement(item);
          final refreshing = cubit.refresh();
          if (detailFinishesFirst) {
            stats.complete(const Result.success(77));
            await reading;
            expect(cubit.state.items.single.engagement!.likeCount, 77);
          }
          page.complete(
            refreshSucceeds
                ? Result.success(
                    _page([
                      item.copyWith(
                        engagement: item.engagement!.copyWith(
                          likeCount: 4,
                          commentCount: 3,
                          likedByMe: false,
                        ),
                      ),
                    ]),
                  )
                : const Result.failure(_readFailure),
          );
          await refreshing;
          if (!detailFinishesFirst) {
            stats.complete(const Result.success(77));
            await reading;
          }
          final current = cubit.state.items.single.engagement!;
          expect(current.likeCount, refreshSucceeds ? 4 : 77);
          expect(current.commentCount, refreshSucceeds ? 3 : 7);
          expect(current.likedByMe, !refreshSucceeds);
        },
      );
    }

    test('newer detail stats supersede a refresh-overlapping like '
        '(detail finishes first=$detailFinishesFirst)', () async {
      final item = _mediaItem('item');
      final page = Completer<Result<MusicianFeedPage>>();
      final stats = Completer<Result<int>>();
      final server = _FeedServer()
        ..enqueue(_page([item]))
        ..responses.add(page.future);
      final engagement = _Engagement()
        ..liked = false
        ..commentCount = 7
        ..likeCountFuture = stats.future;
      final cubit = _cubit(server, engagement: engagement);
      await cubit.initialize();
      final refreshing = cubit.refresh();
      expect(await cubit.toggleLike(item.id), isTrue);
      // The detail screen successfully unlikes before asking for fresh stats.
      final reading = cubit.refreshEngagement(item);
      if (detailFinishesFirst) {
        stats.complete(const Result.success(10));
        await reading;
      }
      page.complete(Result.success(_page([item])));
      await refreshing;
      if (!detailFinishesFirst) {
        stats.complete(const Result.success(10));
        await reading;
      }
      final current = cubit.state.items.single.engagement!;
      expect(current.likedByMe, isFalse);
      expect(current.likeCount, 10);
      expect(current.commentCount, 7);
    });
  }

  test(
    'a failed newer like restores detail stats after the first page arrives',
    () async {
      final item = _mediaItem('item');
      final page = Completer<Result<MusicianFeedPage>>();
      final write = Completer<Result<void>>();
      final server = _FeedServer()
        ..enqueue(_page([item]))
        ..responses.add(page.future);
      final engagement = _Engagement()
        ..likeCount = 10
        ..commentCount = 7;
      final cubit = _cubit(server, engagement: engagement);
      await cubit.initialize();
      final refreshing = cubit.refresh();
      await cubit.refreshEngagement(item);
      engagement.writeFuture = write.future;
      final liking = cubit.toggleLike(item.id);
      cubit.adjustCommentCount(item.id, 1);
      page.complete(Result.success(_page([item, _mediaItem('alias')])));
      await refreshing;
      write.complete(const Result.failure(_readFailure));
      expect(await liking, isFalse);
      expect(
        cubit.state.items.map((item) => item.engagement!.likeCount),
        everyElement(10),
      );
      expect(
        cubit.state.items.map((item) => item.engagement!.likedByMe),
        everyElement(isFalse),
      );
      expect(
        cubit.state.items.map((item) => item.engagement!.commentCount),
        everyElement(8),
      );
    },
  );

  test(
    'failed stats retain known values and successful independent comments',
    () async {
      final item = _mediaItem('item');
      final server = _FeedServer()..enqueue(_page([item]));
      final engagement = _Engagement()
        ..likeCountFuture = Future.value(const Result.failure(_readFailure))
        ..liked = true
        ..commentCount = 8;
      final cubit = _cubit(server, engagement: engagement);
      await cubit.initialize();

      await cubit.refreshEngagement(item);
      final current = cubit.state.items.single.engagement!;
      expect(current.likeCount, 2);
      expect(current.likedByMe, isFalse);
      expect(current.commentCount, 8);
      expect(cubit.state.actionError, isNull);
      expect(server.cursors, [null]);
    },
  );

  test(
    'comment-only stats preserve a completed like for first-page rebasing',
    () async {
      final item = _mediaItem('item');
      final page = Completer<Result<MusicianFeedPage>>();
      final server = _FeedServer()
        ..enqueue(_page([item]))
        ..responses.add(page.future);
      final engagement = _Engagement()
        ..likeCountFuture = Future.value(const Result.failure(_readFailure))
        ..commentCount = 7;
      final cubit = _cubit(server, engagement: engagement);
      await cubit.initialize();
      final refreshing = cubit.refresh();
      expect(await cubit.toggleLike(item.id), isTrue);
      await cubit.refreshEngagement(item);
      page.complete(
        Result.success(
          _page([
            item.copyWith(
              engagement: item.engagement!.copyWith(
                likeCount: 9,
                commentCount: 8,
              ),
            ),
          ]),
        ),
      );
      await refreshing;
      final current = cubit.state.items.single.engagement!;
      expect(current.likedByMe, isTrue);
      expect(current.likeCount, 10);
      expect(current.commentCount, 7);
    },
  );

  test('like-only stats preserve the fresh first-page comment total', () async {
    final item = _mediaItem('item');
    final page = Completer<Result<MusicianFeedPage>>();
    final server = _FeedServer()
      ..enqueue(_page([item]))
      ..responses.add(page.future);
    final engagement = _Engagement()
      ..likeCount = 12
      ..liked = true
      ..commentCountFuture = Future.value(const Result.failure(_readFailure));
    final cubit = _cubit(server, engagement: engagement);
    await cubit.initialize();
    final refreshing = cubit.refresh();
    await cubit.refreshEngagement(item);
    page.complete(
      Result.success(
        _page([
          item.copyWith(
            engagement: item.engagement!.copyWith(
              likeCount: 9,
              commentCount: 8,
            ),
          ),
        ]),
      ),
    );
    await refreshing;
    final current = cubit.state.items.single.engagement!;
    expect(current.likedByMe, isTrue);
    expect(current.likeCount, 12);
    expect(current.commentCount, 8);
  });

  for (final mutation in ['like', 'comment']) {
    test('a late detail read cannot undo a newer $mutation change', () async {
      final item = _mediaItem('item');
      final read = Completer<Result<int>>();
      final server = _FeedServer()..enqueue(_page([item]));
      final engagement = _Engagement()..likeCountFuture = read.future;
      final cubit = _cubit(server, engagement: engagement);
      await cubit.initialize();
      final reading = cubit.refreshEngagement(item);
      if (mutation == 'like') {
        expect(await cubit.toggleLike(item.id), isTrue);
      } else {
        cubit.adjustCommentCount(item.id, 1);
      }
      read.complete(const Result.success(77));
      await reading;

      final current = cubit.state.items.single.engagement!;
      expect(current.likeCount, mutation == 'like' ? 3 : 2);
      expect(current.likedByMe, mutation == 'like');
      expect(current.commentCount, mutation == 'comment' ? 2 : 1);
    });
  }

  test('a detail read waits for an already pending like write', () async {
    final item = _mediaItem('item');
    final write = Completer<Result<void>>();
    final server = _FeedServer()..enqueue(_page([item]));
    final engagement = _Engagement()
      ..writeFuture = write.future
      ..likeCount = 9
      ..liked = true;
    final cubit = _cubit(server, engagement: engagement);
    await cubit.initialize();
    final liking = cubit.toggleLike(item.id);
    final reading = cubit.refreshEngagement(item);
    expect(engagement.likeReads, isEmpty);
    write.complete(const Result.success(null));
    expect(await liking, isTrue);
    await reading;
    expect(cubit.state.items.single.engagement!.likeCount, 9);
    expect(cubit.state.items.single.engagement!.likedByMe, isTrue);
  });

  test('closing the feed releases a detail read waiting for a like', () async {
    final item = _mediaItem('item');
    final write = Completer<Result<void>>();
    final server = _FeedServer()..enqueue(_page([item]));
    final engagement = _Engagement()..writeFuture = write.future;
    final cubit = _cubit(server, engagement: engagement);
    await cubit.initialize();
    final liking = cubit.toggleLike(item.id);
    final reading = cubit.refreshEngagement(item);

    await cubit.close();
    await reading;
    expect(engagement.likeReads, isEmpty);
    write.complete(const Result.success(null));
    expect(await liking, isFalse);
  });

  test(
    'like rollback preserves a concurrent successful comment delta',
    () async {
      final item = _mediaItem('item');
      final write = Completer<Result<void>>();
      final server = _FeedServer()..enqueue(_page([item]));
      final cubit = _cubit(
        server,
        engagement: _Engagement()..writeFuture = write.future,
      );
      await cubit.initialize();
      final liking = cubit.toggleLike(item.id);
      cubit.adjustCommentCount(item.id, 1);
      write.complete(const Result.failure(_readFailure));
      expect(await liking, isFalse);
      expect(cubit.state.items.single.engagement!.likeCount, 2);
      expect(cubit.state.items.single.engagement!.commentCount, 2);
    },
  );

  for (final change in ['account', 'content', 'newer-read']) {
    test('a late detail read is ignored after a $change boundary', () async {
      final item = _mediaItem('item');
      final read = Completer<Result<int>>();
      final sessions = _sessions();
      final server = _FeedServer()..enqueue(_page([item]));
      final engagement = _Engagement()..likeCountFuture = read.future;
      final cubit = _cubit(server, sessions: sessions, engagement: engagement);
      await cubit.initialize();
      final reading = cubit.refreshEngagement(item);
      switch (change) {
        case 'account':
          sessions.replace(
            audienceSession(
              user: 'replacement',
              token: 'new-token',
              role: 'ROLE_MUSICIAN',
            ),
          );
        case 'content':
          server.enqueue(
            _page([
              item.copyWith(
                engagement: item.engagement!.copyWith(likeCount: 4),
              ),
            ]),
          );
          await cubit.refresh();
        case 'newer-read':
          engagement.likeCountFuture = null;
          engagement.likeCount = 5;
          await cubit.refreshEngagement(item);
      }
      read.complete(const Result.success(77));
      await reading;
      expect(cubit.state.items.single.engagement!.likeCount, switch (change) {
        'account' => 2,
        'content' => 4,
        _ => 5,
      });
    });
  }

  test(
    'a late page adopts newer stats without reapplying an older like count',
    () async {
      final item = _mediaItem('native');
      final page = Completer<Result<MusicianFeedPage>>();
      final server = _FeedServer()
        ..enqueue(_page([item], cursor: 'page-2'))
        ..responses.add(page.future);
      final engagement = _Engagement()
        ..likeCount = 12
        ..liked = true
        ..commentCount = 9;
      final cubit = _cubit(server, engagement: engagement);
      await cubit.initialize();
      final paging = cubit.loadMore();
      expect(await cubit.toggleLike(item.id), isTrue);
      await cubit.refreshEngagement(item);
      cubit.adjustCommentCount(item.id, 1);
      page.complete(Result.success(_page([_mediaItem('activity')])));
      await paging;

      expect(
        cubit.state.items.map((item) => item.engagement!.likeCount),
        everyElement(12),
      );
      expect(
        cubit.state.items.map((item) => item.engagement!.commentCount),
        everyElement(10),
      );
      expect(
        cubit.state.items.map((item) => item.engagement!.likedByMe),
        everyElement(isTrue),
      );
    },
  );

  test(
    'a late alias rolls back to synced stats after a newer unlike fails',
    () async {
      final item = _mediaItem('native');
      final page = Completer<Result<MusicianFeedPage>>();
      final write = Completer<Result<void>>();
      final server = _FeedServer()
        ..enqueue(_page([item], cursor: 'page-2'))
        ..responses.add(page.future);
      final engagement = _Engagement()
        ..likeCount = 12
        ..liked = true
        ..commentCount = 9
        ..writeFuture = write.future;
      final cubit = _cubit(server, engagement: engagement);
      await cubit.initialize();
      final paging = cubit.loadMore();
      await cubit.refreshEngagement(item);
      final unliking = cubit.toggleLike(item.id);
      cubit.adjustCommentCount(item.id, 1);
      page.complete(Result.success(_page([_mediaItem('activity')])));
      await paging;
      expect(
        cubit.state.items.map((item) => item.engagement!.likeCount),
        everyElement(11),
      );

      write.complete(const Result.failure(_readFailure));
      expect(await unliking, isFalse);
      expect(
        cubit.state.items.map((item) => item.engagement!.likeCount),
        everyElement(12),
      );
      expect(
        cubit.state.items.map((item) => item.engagement!.likedByMe),
        everyElement(isTrue),
      );
      expect(
        cubit.state.items.map((item) => item.engagement!.commentCount),
        everyElement(10),
      );
    },
  );

  for (final kind in ['media', 'announcement']) {
    for (final outcome in ['unchanged', 'updated', 'account-changed']) {
      final changeAccount = outcome == 'account-changed';
      testWidgets('$kind detail return preserves loaded pages when $outcome', (
        tester,
      ) async {
        final item = kind == 'media' ? _mediaItem('item') : _announcementItem();
        final server = _FeedServer()
          ..enqueue(
            _page([
              item,
              ...List.generate(
                19,
                (i) => _mediaItem('first-$i', targetId: 'different-$i'),
              ),
            ], cursor: 'page-2'),
          )
          ..enqueue(
            _page(
              List.generate(
                20,
                (i) => _mediaItem('second-$i', targetId: 'different-${i + 20}'),
              ),
              cursor: 'page-3',
            ),
          );
        final sessions = _sessions();
        final engagement = _Engagement()
          ..likeCount = outcome == 'unchanged' ? 2 : 6;
        final announcements = _Engagement()
          ..likeCount = outcome == 'unchanged' ? 2 : 7;
        final cubit = _cubit(
          server,
          sessions: sessions,
          engagement: engagement,
          announcementEngagement: announcements,
        );
        await cubit.initialize();
        await cubit.loadMore();
        final before = cubit.state;
        late BuildContext feedContext;
        final observer = _ReturnFromDetailObserver(
          onReturn: () {
            if (changeAccount) {
              sessions.replace(
                audienceSession(
                  user: 'replacement',
                  token: 'new-token',
                  role: 'ROLE_MUSICIAN',
                ),
              );
            }
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [observer],
            home: BlocProvider.value(
              value: cubit,
              child: Builder(
                builder: (context) {
                  feedContext = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        final navigation = MusicianFeedNavigationCoordinator(
          context: feedContext,
          cubit: cubit,
        );
        if (kind == 'media') {
          await navigation.openMedia(
            item,
            title: 'Parça',
            playbackUrl: null,
            durationSeconds: 120,
            mediaId: 'media-id',
            isVideo: false,
            isImage: false,
          );
        } else {
          await navigation.openAnnouncement(
            item,
            item.payload as AnnouncementFeedPayload,
          );
        }

        expect(observer.detailRoutes, 1);
        expect(
          cubit.state.items.map((item) => item.id),
          before.items.map((item) => item.id),
        );
        expect(cubit.state.items, hasLength(40));
        expect(cubit.state.feedSessionId, before.feedSessionId);
        expect(cubit.state.nextCursor, 'page-3');
        expect(server.cursors, [null, 'page-2']);
        expect(
          cubit.state.items.skip(1).map((item) => item.engagement!.likeCount),
          everyElement(2),
        );
        expect(
          cubit.state.items.first.engagement!.likeCount,
          changeAccount || outcome == 'unchanged'
              ? 2
              : kind == 'media'
              ? 6
              : 7,
        );
        final selected = kind == 'media' ? engagement : announcements;
        final other = kind == 'media' ? announcements : engagement;
        expect(selected.likeReads, changeAccount ? isEmpty : hasLength(1));
        expect(other.likeReads, isEmpty);
        await tester.pumpAndSettle();
      });
    }
  }
}

const _readFailure = AppError(code: 'read-failed', message: 'Okunamadı');

MusicianFeedCubit _cubit(
  _FeedServer server, {
  AudienceTestSessions? sessions,
  _Engagement? engagement,
  _Engagement? announcementEngagement,
  FollowRepository? follow,
}) {
  final cubit = MusicianFeedCubit(
    server,
    engagement ?? _Engagement(),
    announcementEngagementRepository: announcementEngagement,
    collabRepository: _Collab(),
    followRepository: follow ?? _Follow(),
    bandFollowRepository: _BandFollow(),
    sessions: sessions ?? _sessions(),
  );
  addTearDown(cubit.close);
  return cubit;
}

AudienceTestSessions _sessions() {
  final sessions = AudienceTestSessions(
    audienceSession(
      user: 'viewer-id',
      token: 'viewer-token',
      role: 'ROLE_MUSICIAN',
    ),
  );
  addTearDown(sessions.dispose);
  return sessions;
}

ProfileFeedPayload _profile(MusicianFeedCubit cubit) =>
    cubit.state.items.single.payload as ProfileFeedPayload;

MusicianFeedPage _page(List<MusicianFeedItem> items, {String? cursor}) =>
    MusicianFeedPage(
      schemaVersion: 1,
      algorithmVersion: 'musician-v1',
      feedSessionId: 'preserved-session',
      generatedAt: DateTime.utc(2026, 9, 14),
      items: items,
      nextCursor: cursor,
      hasMore: cursor != null,
    );

MusicianFeedItem _mediaItem(
  String id, {
  String targetId = 'media-id',
  String targetType = 'MEDIA',
  MusicianFeedItemType type = MusicianFeedItemType.track,
  MusicianFeedPayload? payload,
}) => MusicianFeedItem(
  id: id,
  type: type,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 14),
  position: 0,
  impressionToken: 'delivery-$id',
  reason: const MusicianFeedReason(
    code: 'DISCOVERY',
    actors: [],
    secondaryActorCount: 0,
  ),
  author: null,
  target: MusicianFeedTarget(type: targetType, id: targetId),
  engagement: MusicianFeedEngagement(
    targetType: targetType,
    targetId: targetId,
    likeCount: 2,
    commentCount: 1,
    likedByMe: false,
    likable: true,
    commentable: true,
  ),
  promotion: null,
  feedbackCapabilities: const {},
  payload:
      payload ??
      TrackFeedPayload(
        trackId: id,
        mediaAssetId: targetId,
        title: 'Parça',
        playbackUrl: null,
        durationSeconds: 120,
        bpm: null,
      ),
);

MusicianFeedItem _announcementItem() => _mediaItem(
  'announcement',
  type: MusicianFeedItemType.announcement,
  targetType: 'ANNOUNCEMENT',
  targetId: announcementFixtureId,
  payload: AnnouncementFeedPayload.fromJson(announcementFixture()),
);

MusicianFeedItem _profileItem() => MusicianFeedItem(
  id: 'profile-card',
  type: MusicianFeedItemType.profile,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 14),
  position: 0,
  impressionToken: 'profile-token',
  reason: const MusicianFeedReason(
    code: 'DISCOVERY',
    actors: [],
    secondaryActorCount: 0,
  ),
  author: null,
  target: const MusicianFeedTarget(type: 'PROFILE', id: 'other-profile'),
  engagement: null,
  promotion: null,
  feedbackCapabilities: const {},
  payload: const ProfileFeedPayload(
    profileId: 'other-profile',
    profileType: 'MUSICIAN',
    userId: 'other-user',
    username: 'other',
    displayName: 'Other musician',
    avatarUrl: null,
    bio: null,
    location: null,
    followedByViewer: false,
  ),
);

class _FeedServer extends Fake implements MusicianFeedRepository {
  final responses = Queue<Future<Result<MusicianFeedPage>>>();
  final cursors = <String?>[];
  void enqueue(MusicianFeedPage page) =>
      responses.add(Future.value(Result.success(page)));
  @override
  Future<Result<MusicianFeedPage>> load({required int limit, String? cursor}) {
    cursors.add(cursor);
    return responses.removeFirst();
  }

  @override
  Future<Result<void>> recordEvent({
    required String clientEventId,
    required String impressionToken,
    required MusicianFeedTelemetryEventType eventType,
    DateTime? occurredAt,
  }) async => const Result.success(null);
}

class _FollowServer extends _FeedServer implements FollowRepository {
  bool followed = false;
  Future<Result<void>>? followFuture;
  @override
  Future<Result<MusicianFeedPage>> load({required int limit, String? cursor}) {
    if (responses.isEmpty) enqueue(_page(followed ? [] : [_profileItem()]));
    return super.load(limit: limit, cursor: cursor);
  }

  @override
  Future<Result<void>> follow({
    required String followerId,
    required String followingId,
  }) async {
    final result =
        await (followFuture ?? Future.value(const Result<void>.success(null)));
    if (result.isSuccess) followed = true;
    return result;
  }

  @override
  Future<Result<void>> unfollow({
    required String followerId,
    required String followingId,
  }) async {
    followed = false;
    return const Result.success(null);
  }
}

class _Engagement extends Fake implements EngagementRepository {
  int likeCount = 2;
  int commentCount = 1;
  int rootCommentCount = 1;
  int rootCommentReads = 0;
  bool liked = false;
  Future<Result<int>>? likeCountFuture;
  Future<Result<int>>? commentCountFuture;
  Future<Result<void>>? writeFuture;
  final likeReads = <({String type, String id})>[];
  final commentReads = <({String type, String id})>[];
  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) {
    likeReads.add((type: targetType, id: targetId));
    return likeCountFuture ?? Future.value(Result.success(likeCount));
  }

  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) async => Result.success(liked);
  @override
  Future<Result<int>> getCommentCount({
    required String targetType,
    required String targetId,
  }) async {
    commentReads.add((type: targetType, id: targetId));
    return commentCountFuture ?? Future.value(Result.success(commentCount));
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    rootCommentReads += 1;
    return Result.success(
      CommentPage(
        items: const [],
        totalElements: rootCommentCount,
        page: page,
        size: size,
      ),
    );
  }

  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) => writeFuture ?? Future.value(const Result.success(null));

  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) => writeFuture ?? Future.value(const Result.success(null));
}

// Pop the real route before its first frame. This exercises the production
// navigation return path without initializing an audio engine or remote media.
class _ReturnFromDetailObserver extends NavigatorObserver {
  _ReturnFromDetailObserver({required this.onReturn});
  final VoidCallback onReturn;
  int detailRoutes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return;
    detailRoutes += 1;
    scheduleMicrotask(() {
      onReturn();
      navigator!.pop();
    });
  }
}

class _Collab extends Fake implements CollabRepository {}

class _Follow extends Fake implements FollowRepository {}

class _BandFollow extends Fake implements BandFollowRepository {}
