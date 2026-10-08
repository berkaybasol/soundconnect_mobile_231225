part of 'musician_feed_contract_test.dart';

void _registerMusicianFeedCubit2() {
  test(
    'settings events ignore other logins and closed feed instances',
    () async {
      final sessions = _musicianSessions();
      final changes = MusicianFeedMuteChanges();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(Result.success(_itemsPage([_trackItem('first')]))),
        );
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: sessions,
        muteChanges: changes,
      );
      addTearDown(changes.close);
      addTearDown(sessions.dispose);
      await cubit.initialize();
      for (final identity in [
        (userId: 'other-viewer', token: sessions.session.token!),
        (userId: sessions.session.userId!, token: 'old-token'),
      ]) {
        changes.notifyUnmuted(
          userId: identity.userId,
          token: identity.token,
          author: (profileType: 'MUSICIAN', profileId: 'profile-author-a'),
        );
      }
      expect(feed.loadCursors, [null]);
      await cubit.close();
      changes.notifyUnmuted(
        userId: sessions.session.userId!,
        token: sessions.session.token!,
        author: (profileType: 'MUSICIAN', profileId: 'profile-author-a'),
      );
      expect(feed.loadCursors, [null]);
    },
  );

  test(
    'pending mute from another account does not suppress a newly loaded page',
    () async {
      final mute = Completer<Result<void>>();
      final sessions = _musicianSessions();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([_trackItem('first', authorUserId: 'same-author')]),
            ),
          ),
        )
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([_trackItem('second', authorUserId: 'same-author')]),
            ),
          ),
        )
        ..muteFuture = mute.future;
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: sessions,
      );
      addTearDown(sessions.dispose);
      addTearDown(cubit.close);
      await cubit.initialize();
      final muting = cubit.muteAuthor(
        sourceItemId: 'first',
        profileType: 'MUSICIAN',
        profileId: 'profile-same-author',
      );
      sessions.replace(
        audienceSession(
          user: 'other-viewer',
          token: 'other-token',
          role: 'ROLE_MUSICIAN',
        ),
      );
      await cubit.refresh();
      expect(cubit.state.items.map((item) => item.id), ['second']);
      mute.complete(const Result.success(null));
      expect(await muting, isFalse);
      expect(cubit.state.items.map((item) => item.id), ['second']);
    },
  );

  test('does not carry an accepted mute into another account', () async {
    final sessions = _musicianSessions();
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(
          Result.success(
            _itemsPage([_trackItem('first', authorUserId: 'same-author')]),
          ),
        ),
      )
      ..responses.add(
        Future.value(
          Result.success(
            _itemsPage([_trackItem('second', authorUserId: 'same-author')]),
          ),
        ),
      );
    final cubit = MusicianFeedCubit(
      feed,
      _EngagementRepository(),
      collabRepository: _CollabRepository(),
      followRepository: _FollowRepository(),
      bandFollowRepository: _BandFollowRepository(),
      sessions: sessions,
    );
    addTearDown(cubit.close);
    addTearDown(sessions.dispose);
    await cubit.initialize();

    expect(
      await cubit.muteAuthor(
        sourceItemId: 'first',
        profileType: 'MUSICIAN',
        profileId: 'profile-same-author',
      ),
      isTrue,
    );
    expect(cubit.state.items, isEmpty);

    sessions.replace(
      audienceSession(
        user: 'other-viewer',
        token: 'other-token',
        role: 'ROLE_MUSICIAN',
      ),
    );
    await cubit.refresh();

    expect(cubit.state.items.map((item) => item.id), ['second']);
  });

  test(
    'synchronizes an optimistic like across every card for its target',
    () async {
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([_trackItem('native'), _trackItem('activity')]),
            ),
          ),
        );
      final write = Completer<Result<void>>();
      final engagement = _EngagementRepository()..likeFuture = write.future;
      final cubit = MusicianFeedCubit(
        feed,
        engagement,
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      final pending = cubit.toggleLike('native');

      expect(
        cubit.state.items.map((item) => item.engagement?.likedByMe),
        everyElement(isTrue),
      );
      expect(
        cubit.state.items.map((item) => item.engagement?.likeCount),
        everyElement(3),
      );
      expect(cubit.state.pendingItemIds, {'native', 'activity'});

      write.complete(const Result.success(null));
      expect(await pending, isTrue);
      expect(cubit.state.pendingItemIds, isEmpty);
      expect(engagement.likeCalls, [('MEDIA', 'media-id')]);
    },
  );

  test(
    'rolls back every shared-target card after a failed optimistic like',
    () async {
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([_trackItem('native'), _trackItem('activity')]),
            ),
          ),
        );
      final engagement = _EngagementRepository()
        ..likeResult = const Result.failure(
          AppError(code: 'like-failed', message: 'Olmadı'),
        );
      final cubit = MusicianFeedCubit(
        feed,
        engagement,
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      final success = await cubit.toggleLike('activity');

      expect(success, isFalse);
      expect(
        cubit.state.items.map((item) => item.engagement?.likedByMe),
        everyElement(isFalse),
      );
      expect(
        cubit.state.items.map((item) => item.engagement?.likeCount),
        everyElement(2),
      );
      expect(cubit.state.pendingItemIds, isEmpty);
    },
  );

  for (final initiallyLiked in [false, true]) {
    for (final succeeds in [false, true]) {
      test(
        'paging aliases share a pending ${initiallyLiked ? 'unlike' : 'like'} '
        'and its ${succeeds ? 'success' : 'rollback'}',
        () async {
          final native = _trackItem('native').copyWith(
            engagement: _trackItem(
              'native',
            ).engagement!.copyWith(likedByMe: initiallyLiked),
          );
          final alias = _commentActivityItem('activity-comment', native);
          final write = Completer<Result<void>>();
          final feed = _FeedRepository()
            ..responses.add(
              Future.value(
                Result.success(
                  _itemsPage([native], hasMore: true, nextCursor: 'page-2'),
                ),
              ),
            )
            ..responses.add(Future.value(Result.success(_itemsPage([alias]))));
          final engagement = _EngagementRepository()
            ..likeFuture = write.future
            ..unlikeFuture = write.future;
          final sessions = _musicianSessions();
          final cubit = MusicianFeedCubit(
            feed,
            engagement,
            collabRepository: _CollabRepository(),
            followRepository: _FollowRepository(),
            bandFollowRepository: _BandFollowRepository(),
            sessions: sessions,
          );
          addTearDown(cubit.close);
          addTearDown(sessions.dispose);
          await cubit.initialize();

          final pending = cubit.toggleLike(native.id);
          await cubit.loadMore();

          expect(cubit.state.pendingItemIds, {native.id, alias.id});
          expect(
            cubit.state.items.map((item) => item.engagement!.likedByMe),
            everyElement(!initiallyLiked),
          );
          expect(
            cubit.state.items.map((item) => item.engagement!.likeCount),
            everyElement(initiallyLiked ? 1 : 3),
          );
          expect(await cubit.toggleLike(alias.id), isFalse);

          write.complete(
            succeeds
                ? const Result.success(null)
                : const Result.failure(
                    AppError(code: 'like-failed', message: 'Olmadı'),
                  ),
          );
          expect(await pending, succeeds);
          expect(cubit.state.pendingItemIds, isEmpty);
          expect(
            cubit.state.items.map((item) => item.engagement!.likedByMe),
            everyElement(succeeds ? !initiallyLiked : initiallyLiked),
          );
          expect(
            cubit.state.items.map((item) => item.engagement!.likeCount),
            everyElement(succeeds ? (initiallyLiked ? 1 : 3) : 2),
          );
        },
      );
    }
  }

  test(
    'a page already in flight retains a like completed before its response',
    () async {
      final native = _trackItem('native');
      final alias = _commentActivityItem('activity-comment', native);
      final page = Completer<Result<MusicianFeedPage>>();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([native], hasMore: true, nextCursor: 'page-2'),
            ),
          ),
        )
        ..responses.add(page.future);
      final sessions = _musicianSessions();
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      addTearDown(sessions.dispose);
      await cubit.initialize();

      final paging = cubit.loadMore();
      expect(await cubit.toggleLike(native.id), isTrue);
      page.complete(Result.success(_itemsPage([alias])));
      await paging;

      expect(cubit.state.pendingItemIds, isEmpty);
      expect(
        cubit.state.items.map((item) => item.engagement!.likedByMe),
        everyElement(isTrue),
      );
      expect(
        cubit.state.items.map((item) => item.engagement!.likeCount),
        everyElement(3),
      );
    },
  );

  test(
    'a successful overlapping like rebases onto the refreshed page and its aliases',
    () async {
      final native = _trackItem('native');
      final fresh = native.copyWith(
        engagement: native.engagement!.copyWith(likeCount: 18),
      );
      final alias = _commentActivityItem('activity-comment', fresh);
      final write = Completer<Result<void>>();
      final feed = _FeedRepository()
        ..responses.add(Future.value(Result.success(_itemsPage([native]))))
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([fresh], hasMore: true, nextCursor: 'fresh-page-2'),
            ),
          ),
        )
        ..responses.add(Future.value(Result.success(_itemsPage([alias]))));
      final sessions = _musicianSessions();
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository()..likeFuture = write.future,
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      addTearDown(sessions.dispose);
      await cubit.initialize();

      final pending = cubit.toggleLike(native.id);
      await cubit.refresh();
      await cubit.loadMore();
      write.complete(const Result.success(null));
      expect(await pending, isTrue);

      expect(cubit.state.pendingItemIds, isEmpty);
      expect(
        cubit.state.items.map((item) => item.engagement!.likedByMe),
        everyElement(isTrue),
      );
      expect(
        cubit.state.items.map((item) => item.engagement!.likeCount),
        everyElement(19),
      );
    },
  );

  test(
    'rolls back a like result that crosses an account session boundary',
    () async {
      final sessions = _musicianSessions();
      final write = Completer<Result<void>>();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([_trackItem('native'), _trackItem('activity')]),
            ),
          ),
        );
      final engagement = _EngagementRepository()..likeFuture = write.future;
      final cubit = MusicianFeedCubit(
        feed,
        engagement,
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      addTearDown(sessions.dispose);
      await cubit.initialize();

      final pending = cubit.toggleLike('native');
      sessions.replace(
        audienceSession(
          user: 'replacement-user',
          token: 'replacement-token',
          role: 'ROLE_MUSICIAN',
        ),
      );
      write.complete(const Result.success(null));

      expect(await pending, isFalse);
      expect(
        cubit.state.items.map((item) => item.engagement?.likedByMe),
        everyElement(isFalse),
      );
      expect(cubit.state.pendingItemIds, isEmpty);
      expect(
        cubit.state.actionError?.code,
        'musician_feed_action_session_changed',
      );
    },
  );

  test(
    'a late like failure cannot roll back a refreshed feed generation',
    () async {
      const refreshedEngagement = MusicianFeedEngagement(
        targetType: 'MEDIA',
        targetId: 'media-id',
        likeCount: 18,
        commentCount: 7,
        likedByMe: true,
        likable: true,
        commentable: true,
      );
      final write = Completer<Result<void>>();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(Result.success(_itemsPage([_trackItem('old')]))),
        )
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([
                _trackItem('fresh').copyWith(engagement: refreshedEngagement),
              ]),
            ),
          ),
        );
      final engagement = _EngagementRepository()..likeFuture = write.future;
      final cubit = MusicianFeedCubit(
        feed,
        engagement,
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      final pending = cubit.toggleLike('old');
      await cubit.refresh();
      write.complete(
        const Result.failure(AppError(code: 'late-failure', message: 'late')),
      );

      expect(await pending, isFalse);
      expect(cubit.state.items.single.id, 'fresh');
      expect(cubit.state.items.single.engagement?.likeCount, 18);
      expect(cubit.state.items.single.engagement?.likedByMe, isTrue);
      expect(cubit.state.actionError, isNull);
    },
  );

  test('a failed refresh cannot strand a failed optimistic like', () async {
    final write = Completer<Result<void>>();
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(Result.success(_itemsPage([_trackItem('item')]))),
      )
      ..responses.add(
        Future.value(
          const Result.failure(
            AppError(code: 'refresh-failed', message: 'refresh failed'),
          ),
        ),
      );
    final engagement = _EngagementRepository()..likeFuture = write.future;
    final cubit = MusicianFeedCubit(
      feed,
      engagement,
      collabRepository: _CollabRepository(),
      followRepository: _FollowRepository(),
      bandFollowRepository: _BandFollowRepository(),
      sessions: _musicianSessions(),
    );
    addTearDown(cubit.close);
    await cubit.initialize();

    final pending = cubit.toggleLike('item');
    await cubit.refresh();
    expect(cubit.state.items.single.engagement?.likedByMe, isTrue);
    write.complete(
      const Result.failure(
        AppError(code: 'like-failed', message: 'like failed'),
      ),
    );

    expect(await pending, isFalse);
    expect(cubit.state.items.single.engagement?.likedByMe, isFalse);
    expect(cubit.state.items.single.engagement?.likeCount, 2);
    expect(cubit.state.actionError?.code, 'like-failed');
  });

  test(
    'synchronizes comment deltas across cards for the same target',
    () async {
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([_trackItem('native'), _trackItem('activity')]),
            ),
          ),
        );
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      cubit.adjustCommentCount('activity', 1);

      expect(
        cubit.state.items.map((item) => item.engagement?.commentCount),
        everyElement(2),
      );
    },
  );

  test(
    'uses the existing Collab repository and rolls back save failure',
    () async {
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(Result.success(_page('collab', collab: true))),
        );
      final collab = _CollabRepository()
        ..saveResult = const Result.failure(
          AppError(code: 'save-failed', message: 'Olmadı'),
        );
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: collab,
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      final success = await cubit.toggleCollabSaved('collab', true);

      expect(success, isFalse);
      expect(collab.savedIds, ['listing-id']);
      final payload = cubit.state.items.single.payload as CollabFeedPayload;
      expect(payload.listing['savedByMe'], isFalse);
      expect(feed.eventCalls, isEmpty);
    },
  );

  test(
    'an account switch fences and rolls back an in-flight Collab save',
    () async {
      final sessions = _musicianSessions();
      final write = Completer<Result<void>>();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(Result.success(_page('collab', collab: true))),
        );
      final collab = _CollabRepository()..saveFuture = write.future;
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: collab,
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      addTearDown(sessions.dispose);
      await cubit.initialize();

      final pending = cubit.toggleCollabSaved('collab', true);
      expect(
        (cubit.state.items.single.payload as CollabFeedPayload)
            .listing['savedByMe'],
        isTrue,
      );
      sessions.replace(
        audienceSession(
          user: 'replacement-user',
          token: 'replacement-token',
          role: 'ROLE_MUSICIAN',
        ),
      );
      write.complete(const Result.success(null));

      expect(await pending, isFalse);
      expect(
        (cubit.state.items.single.payload as CollabFeedPayload)
            .listing['savedByMe'],
        isFalse,
      );
      expect(cubit.state.pendingItemIds, isEmpty);
      expect(
        cubit.state.actionError?.code,
        'musician_feed_action_session_changed',
      );
      expect(feed.eventCalls, isEmpty);
    },
  );

  test(
    'a failed refresh cannot strand a failed optimistic Collab save',
    () async {
      final write = Completer<Result<void>>();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(Result.success(_page('collab', collab: true))),
        )
        ..responses.add(
          Future.value(
            const Result.failure(
              AppError(code: 'refresh-failed', message: 'refresh failed'),
            ),
          ),
        );
      final collab = _CollabRepository()..saveFuture = write.future;
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: collab,
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      final pending = cubit.toggleCollabSaved('collab', true);
      await cubit.refresh();
      expect(
        (cubit.state.items.single.payload as CollabFeedPayload)
            .listing['savedByMe'],
        isTrue,
      );
      write.complete(
        const Result.failure(
          AppError(code: 'save-failed', message: 'save failed'),
        ),
      );

      expect(await pending, isFalse);
      expect(
        (cubit.state.items.single.payload as CollabFeedPayload)
            .listing['savedByMe'],
        isFalse,
      );
      expect(cubit.state.actionError?.code, 'save-failed');
    },
  );

  test('records SAVE only after the Collab save succeeds', () async {
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(Result.success(_page('collab', collab: true))),
      );
    final cubit = MusicianFeedCubit(
      feed,
      _EngagementRepository(),
      collabRepository: _CollabRepository(),
      followRepository: _FollowRepository(),
      bandFollowRepository: _BandFollowRepository(),
      sessions: _musicianSessions(),
    );
    addTearDown(cubit.close);
    await cubit.initialize();

    expect(await cubit.toggleCollabSaved('collab', true), isTrue);

    expect(feed.eventCalls, [
      (
        token: 'delivery-token-collab',
        type: MusicianFeedTelemetryEventType.save,
      ),
    ]);
  });
}
