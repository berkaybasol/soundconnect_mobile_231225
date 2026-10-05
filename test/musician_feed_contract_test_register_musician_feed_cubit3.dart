part of 'musician_feed_contract_test.dart';

void _registerMusicianFeedCubit3() {
  test('records REPORT only after signed feedback succeeds', () async {
    final item = _trackItem(
      'reported',
      feedbackCapabilities: const {MusicianFeedFeedbackAction.report},
    );
    final feed = _FeedRepository()
      ..responses.add(Future.value(Result.success(_itemsPage([item]))));
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

    expect(
      await cubit.dismiss(
        'reported',
        MusicianFeedFeedbackAction.report,
        reason: 'SPAM',
      ),
      isTrue,
    );

    expect(
      feed.feedbackCalls.single.impressionToken,
      'delivery-token-reported',
    );
    expect(feed.eventCalls, [
      (
        token: 'delivery-token-reported',
        type: MusicianFeedTelemetryEventType.report,
      ),
    ]);
  });

  test(
    'keeps a successful user-profile follow optimistic until an authoritative refresh',
    () async {
      final write = Completer<Result<void>>();
      final refresh = Completer<Result<MusicianFeedPage>>();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([
                _profileItem(
                  'profile-card',
                  profileType: 'STUDIO',
                  profileId: 'studio-id',
                  userId: 'studio-owner-id',
                ),
              ]),
            ),
          ),
        )
        ..responses.add(refresh.future);
      final follow = _FollowRepository()..followFuture = write.future;
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: follow,
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      final following = cubit.followProfile('profile-card');
      expect(
        (cubit.state.items.single.payload as ProfileFeedPayload)
            .followedByViewer,
        isTrue,
      );
      expect(feed.eventCalls, isEmpty);
      expect(cubit.state.pendingItemIds, contains('profile-card'));
      expect(follow.followCalls, [('viewer-id', 'studio-owner-id')]);

      write.complete(const Result.success(null));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.refreshing, isTrue);
      expect(cubit.state.pendingItemIds, isNot(contains('profile-card')));
      expect(
        (cubit.state.items.single.payload as ProfileFeedPayload)
            .followedByViewer,
        isTrue,
      );
      expect(feed.eventCalls, [
        (
          token: 'delivery-token-profile-card',
          type: MusicianFeedTelemetryEventType.follow,
        ),
      ]);

      refresh.complete(
        Result.success(
          _itemsPage([
            _profileItem(
              'profile-card',
              profileType: 'STUDIO',
              profileId: 'studio-id',
              userId: 'studio-owner-id',
              followedByViewer: true,
            ),
          ]),
        ),
      );
      expect(await following, isTrue);
      expect(
        (cubit.state.items.single.payload as ProfileFeedPayload)
            .followedByViewer,
        isTrue,
      );
    },
  );

  test('uses the dedicated band follow endpoint', () async {
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(
          Result.success(
            _itemsPage([
              _profileItem(
                'band-card',
                profileType: 'BAND',
                profileId: 'band-id',
                // A band payload user is a representative member, never the
                // identity accepted by the band-follow API.
                userId: 'representative-user-id',
              ),
            ]),
          ),
        ),
      )
      ..responses.add(
        Future.value(
          Result.success(
            _itemsPage([
              _profileItem(
                'band-card',
                profileType: 'BAND',
                profileId: 'band-id',
                userId: 'representative-user-id',
              ),
            ]),
          ),
        ),
      );
    final follow = _FollowRepository();
    final bandFollow = _BandFollowRepository();
    final cubit = MusicianFeedCubit(
      feed,
      _EngagementRepository(),
      collabRepository: _CollabRepository(),
      followRepository: follow,
      bandFollowRepository: bandFollow,
      sessions: _musicianSessions(),
    );
    addTearDown(cubit.close);
    await cubit.initialize();

    expect(await cubit.followProfile('band-card'), isTrue);

    expect(bandFollow.followedBandIds, ['band-id']);
    expect(follow.followCalls, isEmpty);
  });

  test('does not carry an accepted follow into another account', () async {
    final sessions = _musicianSessions();
    final profile = _profileItem(
      'listener-card',
      profileType: 'LISTENER',
      profileId: 'listener-id',
      userId: 'listener-user-id',
    );
    final feed = _FeedRepository()
      ..responses.add(Future.value(Result.success(_itemsPage([profile]))))
      ..responses.add(
        Future.value(
          Result.success(
            _itemsPage([
              profile.copyWith(
                payload: (profile.payload as ProfileFeedPayload).copyWith(
                  followedByViewer: true,
                ),
              ),
            ]),
          ),
        ),
      )
      ..responses.add(Future.value(Result.success(_itemsPage([profile]))));
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

    expect(await cubit.followProfile('listener-card'), isTrue);
    expect(
      (cubit.state.items.single.payload as ProfileFeedPayload).followedByViewer,
      isTrue,
    );

    sessions.replace(
      audienceSession(
        user: 'other-viewer',
        token: 'other-token',
        role: 'ROLE_MUSICIAN',
      ),
    );
    await cubit.refresh();

    expect(
      (cubit.state.items.single.payload as ProfileFeedPayload).followedByViewer,
      isFalse,
    );
  });

  test('rolls back follow when the authenticated session changes', () async {
    final sessions = _musicianSessions();
    final write = Completer<Result<void>>();
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(
          Result.success(
            _itemsPage([
              _profileItem(
                'listener-card',
                profileType: 'LISTENER',
                profileId: 'listener-id',
                userId: 'listener-user-id',
              ),
            ]),
          ),
        ),
      );
    final follow = _FollowRepository()..followFuture = write.future;
    final cubit = MusicianFeedCubit(
      feed,
      _EngagementRepository(),
      collabRepository: _CollabRepository(),
      followRepository: follow,
      bandFollowRepository: _BandFollowRepository(),
      sessions: sessions,
    );
    addTearDown(cubit.close);
    await cubit.initialize();

    final following = cubit.followProfile('listener-card');
    sessions.replace(
      audienceSession(
        user: 'other-viewer',
        token: 'other-token',
        role: 'ROLE_MUSICIAN',
      ),
    );
    write.complete(const Result.success(null));

    expect(await following, isFalse);
    expect(cubit.state.pendingItemIds, isEmpty);
    expect(
      (cubit.state.items.single.payload as ProfileFeedPayload).followedByViewer,
      isFalse,
    );
    expect(
      cubit.state.actionError?.code,
      'musician_feed_action_session_changed',
    );
  });

  test('rolls back an optimistic profile follow after write failure', () async {
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(
          Result.success(
            _itemsPage([
              _profileItem(
                'musician-card',
                profileType: 'MUSICIAN',
                profileId: 'musician-id',
                userId: 'musician-user-id',
              ),
            ]),
          ),
        ),
      );
    final follow = _FollowRepository()
      ..followResult = const Result.failure(
        AppError(code: 'follow-failed', message: 'Takip edilemedi'),
      );
    final cubit = MusicianFeedCubit(
      feed,
      _EngagementRepository(),
      collabRepository: _CollabRepository(),
      followRepository: follow,
      bandFollowRepository: _BandFollowRepository(),
      sessions: _musicianSessions(),
    );
    addTearDown(cubit.close);
    await cubit.initialize();

    expect(await cubit.followProfile('musician-card'), isFalse);

    expect(cubit.state.pendingItemIds, isEmpty);
    expect(
      (cubit.state.items.single.payload as ProfileFeedPayload).followedByViewer,
      isFalse,
    );
    expect(cubit.state.actionError?.code, 'follow-failed');
  });
}
