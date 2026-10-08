part of 'musician_feed_contract_test.dart';

void _registerMusicianFeedCubit1() {
  test(
    'initial endpoint feature-off becomes a non-error fallback state',
    () async {
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            const Result.failure(
              AppError(
                code: musicianFeedFeatureUnavailableCode,
                message: 'rollout off',
              ),
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

      expect(cubit.state.status, MusicianFeedStatus.featureUnavailable);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.error, isNull);
      expect(cubit.state.actionError, isNull);
    },
  );

  test('feature-off fallback can recover through a clean refresh', () async {
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(
          const Result.failure(
            AppError(
              code: musicianFeedFeatureUnavailableCode,
              message: 'rollout off',
            ),
          ),
        ),
      )
      ..responses.add(Future.value(Result.success(_page('available'))));
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
    await cubit.refresh();

    expect(cubit.state.status, MusicianFeedStatus.ready);
    expect(cubit.state.items.single.id, 'available');
    expect(feed.loadCursors, [null, null]);
  });

  test('initial transient failure retains the error state', () async {
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(
          const Result.failure(AppError(code: '503', message: 'Geçici hata')),
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

    expect(cubit.state.status, MusicianFeedStatus.failure);
    expect(cubit.state.error?.code, '503');
  });

  test('a late refresh cannot replace a newer feed generation', () async {
    final feed = _FeedRepository();
    feed.responses.add(Future.value(Result.success(_page('initial'))));
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
    final older = Completer<Result<MusicianFeedPage>>();
    final newer = Completer<Result<MusicianFeedPage>>();
    feed.responses
      ..add(older.future)
      ..add(newer.future);

    final olderRefresh = cubit.refresh();
    final newerRefresh = cubit.refresh();
    newer.complete(Result.success(_page('newer')));
    await newerRefresh;
    older.complete(Result.success(_page('older')));
    await olderRefresh;

    expect(cubit.state.items.single.id, 'newer');
  });

  test('rejects a non-advancing pagination cursor', () async {
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(
          Result.success(
            _itemsPage(
              [_trackItem('first')],
              hasMore: true,
              nextCursor: 'cursor-1',
            ),
          ),
        ),
      )
      ..responses.add(
        Future.value(
          Result.success(
            _itemsPage(
              [_trackItem('second')],
              hasMore: true,
              nextCursor: 'cursor-1',
            ),
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

    await cubit.loadMore();

    expect(cubit.state.items.map((item) => item.id), ['first']);
    expect(
      cubit.state.loadMoreError?.code,
      'musician_feed_page_identity_mismatch',
    );
  });

  test(
    'cursor-invalid paging starts a clean first-page feed session',
    () async {
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage(
                [_trackItem('old')],
                hasMore: true,
                nextCursor: 'stale-cursor',
              ),
            ),
          ),
        )
        ..responses.add(
          Future.value(
            const Result.failure(
              AppError(code: musicianFeedCursorInvalidCode, message: 'stale'),
            ),
          ),
        )
        ..responses.add(
          Future.value(Result.success(_itemsPage([_trackItem('fresh')]))),
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

      await cubit.loadMore();

      expect(feed.loadCursors, [null, 'stale-cursor', null]);
      expect(cubit.state.items.map((item) => item.id), ['fresh']);
      expect(cubit.state.loadMoreError, isNull);
      expect(cubit.state.status, MusicianFeedStatus.ready);
    },
  );

  test('generic paging errors keep the explicit footer retry state', () async {
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(
          Result.success(
            _itemsPage(
              [_trackItem('first')],
              hasMore: true,
              nextCursor: 'cursor-1',
            ),
          ),
        ),
      )
      ..responses.add(
        Future.value(
          const Result.failure(
            AppError(code: '400', message: 'Geçersiz istek'),
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

    await cubit.loadMore();

    expect(feed.loadCursors, [null, 'cursor-1']);
    expect(cubit.state.items.map((item) => item.id), ['first']);
    expect(cubit.state.loadMoreError?.code, '400');
  });

  test('restores an optimistically hidden item when feedback fails', () async {
    final feed = _FeedRepository()
      ..responses.add(Future.value(Result.success(_page('item'))))
      ..feedbackResult = const Result.failure(
        AppError(code: 'offline', message: 'Çevrimdışı'),
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

    final success = await cubit.dismiss(
      'item',
      MusicianFeedFeedbackAction.hide,
    );

    expect(success, isFalse);
    expect(cubit.state.items.single.id, 'item');
    expect(cubit.state.actionError?.code, 'offline');
  });

  test('keeps an accepted hide suppressed across a stale refresh', () async {
    final refresh = Completer<Result<MusicianFeedPage>>();
    final feedback = Completer<Result<void>>();
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(Result.success(_itemsPage([_trackItem('item')]))),
      )
      ..responses.add(refresh.future)
      ..feedbackFuture = feedback.future;
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

    final refreshing = cubit.refresh();
    final hiding = cubit.dismiss('item', MusicianFeedFeedbackAction.hide);
    expect(cubit.state.items, isEmpty);

    refresh.complete(Result.success(_itemsPage([_trackItem('item')])));
    await refreshing;
    expect(cubit.state.items, isEmpty);

    feedback.complete(const Result.success(null));
    expect(await hiding, isTrue);
    expect(feed.eventCalls, [
      (token: 'delivery-token-item', type: MusicianFeedTelemetryEventType.hide),
    ]);
    feed.responses.add(
      Future.value(Result.success(_itemsPage([_trackItem('item')]))),
    );
    await cubit.refresh();

    expect(cubit.state.items, isEmpty);
  });

  test('does not carry an accepted hide into another account', () async {
    final sessions = _musicianSessions();
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(Result.success(_itemsPage([_trackItem('same-item')]))),
      )
      ..responses.add(
        Future.value(Result.success(_itemsPage([_trackItem('same-item')]))),
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
      await cubit.dismiss('same-item', MusicianFeedFeedbackAction.hide),
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

    expect(cubit.state.items.map((item) => item.id), ['same-item']);
  });

  test(
    'SHOW_LESS invalidates the old cursor and wins a concurrent load-more',
    () async {
      final paging = Completer<Result<MusicianFeedPage>>();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage(
                [_trackItem('less'), _trackItem('kept')],
                hasMore: true,
                nextCursor: 'old-cursor',
              ),
            ),
          ),
        )
        ..responses.add(paging.future)
        ..responses.add(
          Future.value(Result.success(_itemsPage([_trackItem('fresh')]))),
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

      final loadingMore = cubit.loadMore();
      final showingLess = cubit.dismiss(
        'less',
        MusicianFeedFeedbackAction.showLess,
      );
      expect(await showingLess, isTrue);
      expect(cubit.state.items.map((item) => item.id), ['fresh']);
      expect(cubit.state.nextCursor, isNull);
      expect(cubit.state.hasMore, isFalse);
      expect(feed.loadCursors, [null, 'old-cursor', null]);
      expect(feed.eventCalls, isEmpty);

      paging.complete(Result.success(_itemsPage([_trackItem('stale-page')])));
      await loadingMore;
      expect(cubit.state.items.map((item) => item.id), ['fresh']);
    },
  );

  test('restores every author item when mute fails during refresh', () async {
    final refresh = Completer<Result<MusicianFeedPage>>();
    final mute = Completer<Result<void>>();
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(
          Result.success(
            _itemsPage([_trackItem('first', authorUserId: 'author-a')]),
          ),
        ),
      )
      ..responses.add(refresh.future)
      ..muteFuture = mute.future;
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

    final refreshing = cubit.refresh();
    final muting = cubit.muteAuthor(
      sourceItemId: 'first',
      profileType: 'MUSICIAN',
      profileId: 'profile-author-a',
    );
    refresh.complete(
      Result.success(
        _itemsPage([
          _trackItem('first', authorUserId: 'author-a'),
          _trackItem('older', authorUserId: 'author-a'),
          _trackItem('other', authorUserId: 'author-b'),
        ]),
      ),
    );
    await refreshing;
    expect(cubit.state.items.map((item) => item.id), ['other']);

    mute.complete(
      const Result.failure(AppError(code: 'mute-failed', message: 'Olmadı')),
    );
    expect(await muting, isFalse);

    expect(cubit.state.items.map((item) => item.id), [
      'first',
      'older',
      'other',
    ]);
    expect(cubit.state.actionError?.code, 'mute-failed');
    expect(feed.eventCalls, isEmpty);
  });

  test('mutes only the matching profile when one user owns several', () async {
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(
          Result.success(
            _itemsPage([
              _trackItem(
                'studio',
                authorUserId: 'owner-a',
                authorProfileType: 'STUDIO',
                authorProfileId: 'studio-a',
              ),
              _trackItem(
                'musician',
                authorUserId: 'owner-a',
                authorProfileType: 'MUSICIAN',
                authorProfileId: 'musician-a',
              ),
            ]),
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

    final success = await cubit.muteAuthor(
      sourceItemId: 'studio',
      profileType: 'STUDIO',
      profileId: 'studio-a',
    );

    expect(success, isTrue);
    expect(cubit.state.items.map((item) => item.id), ['musician']);
    expect(feed.muteCalls, [(profileType: 'STUDIO', profileId: 'studio-a')]);
    expect(feed.eventCalls, [
      (
        token: 'delivery-token-studio',
        type: MusicianFeedTelemetryEventType.mute,
      ),
    ]);
  });

  test('rolls back a pending mute after the account changes', () async {
    final mute = Completer<Result<void>>();
    final sessions = _musicianSessions();
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(
          Result.success(
            _itemsPage([
              _trackItem('first', authorUserId: 'author-a'),
              _trackItem('other', authorUserId: 'author-b'),
            ]),
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
    addTearDown(cubit.close);
    addTearDown(sessions.dispose);
    await cubit.initialize();

    final muting = cubit.muteAuthor(
      sourceItemId: 'first',
      profileType: 'MUSICIAN',
      profileId: 'profile-author-a',
    );
    expect(cubit.state.items.map((item) => item.id), ['other']);
    sessions.replace(
      audienceSession(
        user: 'other-viewer',
        token: 'other-token',
        role: 'ROLE_MUSICIAN',
      ),
    );
    mute.complete(const Result.success(null));

    expect(await muting, isFalse);
    expect(cubit.state.items.map((item) => item.id), ['first', 'other']);
    expect(
      cubit.state.actionError?.code,
      'musician_feed_action_session_changed',
    );
  });

  test(
    'reapplies accepted mute to load-more and refresh until unmute succeeds',
    () async {
      final loadMore = Completer<Result<MusicianFeedPage>>();
      final mute = Completer<Result<void>>();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage(
                [
                  _trackItem('first', authorUserId: 'author-a'),
                  _trackItem('other', authorUserId: 'author-b'),
                ],
                hasMore: true,
                nextCursor: 'cursor-1',
              ),
            ),
          ),
        )
        ..responses.add(loadMore.future)
        ..muteFuture = mute.future;
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

      final paging = cubit.loadMore();
      final muting = cubit.muteAuthor(
        sourceItemId: 'first',
        profileType: 'MUSICIAN',
        profileId: 'profile-author-a',
      );
      loadMore.complete(
        Result.success(
          _itemsPage([
            _trackItem('older-a', authorUserId: 'author-a'),
            _trackItem('older-b', authorUserId: 'author-b'),
          ]),
        ),
      );
      await paging;
      expect(cubit.state.items.map((item) => item.id), ['other', 'older-b']);

      mute.complete(const Result.success(null));
      expect(await muting, isTrue);
      feed.responses.add(
        Future.value(
          Result.success(
            _itemsPage([
              _trackItem('new-a', authorUserId: 'author-a'),
              _trackItem('new-b', authorUserId: 'author-b'),
            ]),
          ),
        ),
      );
      await cubit.refresh();
      expect(cubit.state.items.map((item) => item.id), ['new-b']);

      feed.responses.add(
        Future.value(
          Result.success(
            _itemsPage([
              _trackItem('new-a', authorUserId: 'author-a'),
              _trackItem('new-b', authorUserId: 'author-b'),
            ]),
          ),
        ),
      );
      expect(
        await cubit.unmuteAuthor(
          profileType: 'MUSICIAN',
          profileId: 'profile-author-a',
        ),
        isTrue,
      );
      expect(cubit.state.items.map((item) => item.id), ['new-a', 'new-b']);
    },
  );

  for (final delayedMuteResponse in [false, true]) {
    test(
      'settings unmute supersedes feed mute (delayed response: $delayedMuteResponse)',
      () async {
        final sessions = _musicianSessions();
        final changes = MusicianFeedMuteChanges();
        final mute = Completer<Result<void>>();
        final items = [_trackItem('first', authorUserId: 'author-a')];
        final feed = _FeedRepository()
          ..responses.add(Future.value(Result.success(_itemsPage(items))))
          ..muteFuture = delayedMuteResponse ? mute.future : null;
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
        addTearDown(cubit.close);
        await cubit.initialize();
        final muting = cubit.muteAuthor(
          sourceItemId: 'first',
          profileType: 'MUSICIAN',
          profileId: 'profile-author-a',
        );
        if (!delayedMuteResponse) expect(await muting, isTrue);
        expect(cubit.state.items, isEmpty);
        feed.responses.add(Future.value(Result.success(_itemsPage(items))));
        final restored = cubit.stream.firstWhere(
          (state) => state.items.isNotEmpty && !state.refreshing,
        );
        changes.notifyUnmuted(
          userId: sessions.session.userId!,
          token: sessions.session.token!,
          author: (profileType: 'MUSICIAN', profileId: 'profile-author-a'),
        );
        await restored;
        if (delayedMuteResponse) {
          mute.complete(const Result.success(null));
          expect(await muting, isFalse);
        }
        expect(cubit.state.items.map((item) => item.id), ['first']);
        expect(cubit.state.pendingItemIds, isEmpty);
        // A late old PUT must not silently reintroduce suppression on refresh.
        feed.responses.add(Future.value(Result.success(_itemsPage(items))));
        await cubit.refresh();
        expect(cubit.state.items.map((item) => item.id), ['first']);
        expect(feed.unmuteCalls, isEmpty);
      },
    );
  }
}
