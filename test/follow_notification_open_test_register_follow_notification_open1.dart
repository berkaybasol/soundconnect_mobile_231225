part of 'follow_notification_open_test.dart';

extension _RegisterFollowNotificationOpen1 on _FollowNotificationOpenCases {
  void _registerFollowNotificationOpen1() {
    setUp(() async {
      await serviceLocator.reset();
      sessions = AudienceTestSessions(audienceSession(user: recipient));
      profiles = _ProfileRepository();
      bands = _Bands();
      connections = _ConnectionRepository();
      repository = _Repository();
      realtime = _Realtime();
      badge = _BadgeCubit();
      navigator = GlobalKey<NavigatorState>();
      acks = [];
      reconciliations = 0;
      failExact = false;
      failResolver = false;
      failAck = false;
      pendingExact = null;
      pendingResolver = null;
      pendingAck = null;
      exact = {
        'id': notificationId,
        'recipientId': recipient,
        'type': 'SOCIAL_NEW_FOLLOWER',
        'read': false,
        'payload': {
          'action': 'NEW_FOLLOWER',
          'followerId': follower,
          'followerName': 'UNTRUSTED SNAPSHOT',
        },
      };
      resolved = {
        'userId': follower,
        'profiles': [
          {
            'type': 'MUSICIAN',
            'profileId': profileId,
            'displayName': 'Fresh resolver',
          },
        ],
      };
      api = RecordingApiClient((request) async {
        if (request.path.endsWith('/read')) {
          acks.add(request.path.split('/').reversed.elementAt(1));
          if (pendingAck != null) await pendingAck!.future;
          if (failAck) throw ApiException(fail);
          repository.items = repository.items
              .map(
                (item) =>
                    item.id == acks.last ? item.copyWith(read: true) : item,
              )
              .toList();
          return null;
        }
        if (request.path.contains('/profiles/by-user/')) {
          if (failResolver) throw ApiException(fail);
          return pendingResolver?.future ?? resolved;
        }
        if (failExact) throw ApiException(fail);
        return pendingExact?.future ?? exact;
      });
      resolver = DmUserProfileResolverImpl(apiClient: api, sessions: sessions);
      cubit = NotificationCubit(
        repository,
        _Tokens(),
        sessions: sessions,
        realtimeClient: realtime,
        onDeliveryStateChanged: () async {
          reconciliations++;
        },
      );
      final follow = _FollowRepository();
      final engagement = _EngagementRepository();
      serviceLocator
        ..registerSingleton<AuthSessionManager>(sessions)
        ..registerSingleton<TokenStore>(_Tokens())
        ..registerSingleton<NotificationCubit>(cubit)
        ..registerSingleton<NotificationTargetRepository>(
          NotificationTargetRepository(api, sessions),
        )
        ..registerSingleton<DmUserProfileResolver>(resolver)
        ..registerSingleton<MusicianProfileRepository>(profiles)
        ..registerSingleton<BandRepository>(bands)
        ..registerSingleton<BandFollowRepository>(_BandFollow())
        ..registerSingleton<SpotifyRepository>(_Spotify())
        ..registerSingleton<StudioRoomRepository>(_Rooms())
        ..registerSingleton<StudioEquipmentRepository>(_Equipment())
        ..registerSingleton<BacklineCatalogRepository>(_Catalog())
        ..registerSingleton<ArtistVenueConnectionRepository>(connections)
        ..registerSingleton<EngagementRepository>(engagement)
        ..registerSingleton<AudioHandler>(BaseAudioHandler())
        ..registerSingleton<DmBadgeCubit>(badge)
        ..registerFactory<MusicianProfileCubit>(
          () => MusicianProfileCubit(profiles),
        )
        ..registerFactory<ProfileMediaCubit>(
          () => ProfileMediaCubit(_MediaRepository()),
        )
        ..registerFactory<FollowCountCubit>(() => FollowCountCubit(follow))
        ..registerFactory<FollowActionCubit>(() => FollowActionCubit(follow))
        ..registerFactory<ArtistVenueConnectionsCubit>(
          () => ArtistVenueConnectionsCubit(connections),
        )
        ..registerFactory<InteractionStatsCubit>(
          () => InteractionStatsCubit(engagement),
        );
      await cubit.ensureStarted();
    });

    tearDown(() async {
      await cubit.close();
      await realtime.dispose();
      await badge.close();
      sessions.dispose();
      await serviceLocator.reset();
    });

    for (final type in [
      'BAND_INVITE_ACCEPTED',
      'BAND_INVITE_REJECTED',
      'BAND_MEMBER_LEFT',
    ]) {
      testWidgets(
        '$type native exact lookup then real band profile reads only the target',
        (t) async {
          await prepareNativeBand(t, type);
          bands.pending = Completer<Result<BandProfile>>();
          await mount(t);
          await openNativeBand(t);
          unread();
          expect(bands.publicGets, 1);
          bands.pending!.complete(const Result.success(_band));
          await t.pumpAndSettle();
          expect(find.byType(BandProfileScreen), findsOneWidget);
          expect(find.text('Fresh band'), findsWidgets);
          onlyTarget();
          expect(resolverGets(), 0);
        },
      );
    }

    testWidgets(
      'BAND invite waits for exact current invitation and real band, then sends visible decision ID',
      (t) async {
        await prepareNativeBand(t, 'BAND_INVITE_RECEIVED');
        bands.pending = Completer<Result<BandProfile>>();
        await mount(t);
        await openNativeBand(t);
        unread();
        bands.pending!.complete(const Result.success(_band));
        await t.pumpAndSettle();
        expect(find.byType(BandInviteDecisionScreen), findsOneWidget);
        onlyTarget();
        await t.tap(find.text('Reddet'));
        await t.pumpAndSettle();
        expect(bands.decisionIds, [_bandInvitationId]);
        onlyTarget();
      },
    );

    testWidgets(
      'old native invitation exposes explicit current path without read or silent decision',
      (t) async {
        await prepareNativeBand(t, 'BAND_INVITE_RECEIVED');
        bands.currentInvitationId = siblingId;
        await mount(t);
        await openNativeBand(t);
        await t.pumpAndSettle();
        expect(find.text('Güncel daveti aç'), findsOneWidget);
        unread();
        expect(bands.decisionIds, isEmpty);
        await t.tap(find.text('Güncel daveti aç'));
        await t.pumpAndSettle();
        unread();
        expect(bands.decisionIds, isEmpty);
        await t.tap(find.text('Reddet'));
        await t.pumpAndSettle();
        expect(bands.decisionIds, [siblingId]);
        unread();
      },
    );

    for (final active in [false, true]) {
      testWidgets(
        'native removal fresh MyBands active=$active has exact absence/read barrier',
        (t) async {
          await prepareNativeBand(t, 'BAND_MEMBER_REMOVED');
          bands.activeAgain = active;
          bands.pendingMyBands = Completer<Result<List<BandSummary>>>();
          await mount(t);
          await openNativeBand(t);
          unread();
          bands.pendingMyBands!.complete(
            Result.success(
              active
                  ? [
                      const BandSummary(
                        id: bandId,
                        name: 'Rejoined band',
                        description: null,
                        profilePictureUrl: null,
                        countsTowardCreationLimit: false,
                      ),
                    ]
                  : [],
            ),
          );
          await t.pumpAndSettle();
          expect(find.byType(MyBandsScreen), findsOneWidget);
          if (active) {
            unread();
          } else {
            onlyTarget();
          }
        },
      );
    }

    for (final type in [
      'BAND_INVITE_RECEIVED',
      'BAND_MEMBER_REMOVED',
      'BAND_MEMBER_LEFT',
    ]) {
      testWidgets('$type real destination failure does not read', (t) async {
        await prepareNativeBand(t, type);
        bands.failure = true;
        await mount(t);
        await openNativeBand(t);
        await t.pumpAndSettle();
        unread();
      });
    }

    for (final mutation in [
      'legacy',
      'foreign',
      'wrongType',
      'wrongModule',
      'wrongAction',
      'invalidBand',
      'invalidActor',
      'missingInvitation',
      'extra',
      'selfActor',
    ]) {
      testWidgets(
        'native BAND rejects fresh malformed/foreign notification $mutation before target GET',
        (t) async {
          await prepareNativeBand(t, 'BAND_INVITE_RECEIVED');
          final p = exact['payload'] as Map<String, dynamic>;
          switch (mutation) {
            case 'legacy':
              p['bandIdentityVersion'] = 0;
            case 'foreign':
              exact['recipientId'] = follower;
            case 'wrongType':
              exact['type'] = 'BAND_INVITE_ACCEPTED';
            case 'wrongModule':
              p['module'] = 'SOCIAL';
            case 'wrongAction':
              p['action'] = 'MEMBER_LEFT';
            case 'invalidBand':
              p['bandId'] = '1-1-1-1-1';
            case 'invalidActor':
              p['inviterId'] = 'invalid';
            case 'missingInvitation':
              p.remove('invitationId');
            case 'extra':
              p['bandName'] = 'stale snapshot';
            case 'selfActor':
              p['inviterId'] = recipient;
          }
          await mount(t);
          await openNativeBand(t);
          await t.pumpAndSettle();
          unread();
          expect(bands.publicGets, 0);
          expect(find.text('Tekrar dene'), findsOneWidget);
        },
      );
    }

    testWidgets(
      'BAND GET error retries only explicitly and target loads before one read',
      (t) async {
        await prepareNativeBand(t, 'BAND_INVITE_RECEIVED');
        failExact = true;
        await mount(t);
        await openNativeBand(t);
        await t.pumpAndSettle();
        unread();
        final before = api.requests.length;
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        expect(api.requests.length, before);
        failExact = false;
        await t.tap(find.text('Tekrar dene'));
        await t.pumpAndSettle();
        onlyTarget();
      },
    );

    testWidgets(
      'BAND late exact GET after session change never navigates or reads',
      (t) async {
        await prepareNativeBand(t, 'BAND_INVITE_RECEIVED');
        pendingExact = Completer<Map<String, dynamic>>();
        await mount(t);
        await openNativeBand(t);
        await t.runAsync(() async {
          sessions.replace(
            audienceSession(user: follower, role: 'ROLE_MUSICIAN'),
          );
          pendingExact!.complete(exact);
          await cubit.stop();
        });
        await t.pumpAndSettle();
        expect(acks, isEmpty);
        expect(bands.publicGets, 0);
        expect(find.byType(BandInviteDecisionScreen), findsNothing);
      },
    );

    testWidgets(
      'BAND initial open waits for foreground and never reads a background callback',
      (t) async {
        await prepareNativeBand(t, 'BAND_INVITE_RECEIVED');
        await mount(t, paused: true);
        final before = api.requests.length;
        await openNativeBand(t);
        expect(api.requests.length, before);
        unread();
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        onlyTarget();
      },
    );

    testWidgets(
      'native person follows exact GET fresh resolver real router loading visible profile exact ACK',
      (t) async {
        profiles.pending = Completer<Result<MusicianProfile>>();
        await mount(t);
        await open(t);
        unread();
        expect(profiles.requestedIds, [profileId]);
        expect(resolverGets(), 1);
        profiles.pending!.complete(const Result.success(_profile));
        await t.pumpAndSettle();
        expect(find.byType(MusicianPublicProfileScreen), findsOneWidget);
        expect(find.text('public-artist'), findsOneWidget);
        onlyTarget();
        expect(
          api.requests.every(
            (r) =>
                r.requestContext?.expectedToken == 'token' &&
                r.requestContext?.expectedSessionKey == recipient,
          ),
          isTrue,
        );
        expect(find.text('UNTRUSTED SNAPSHOT'), findsNothing);
      },
    );

    for (final band in [false, true]) {
      testWidgets(
        'inbox ${band ? 'band' : 'person'} uses the same exact fresh content chain',
        (t) async {
          if (band) {
            bandExact();
            repository.items = [
              _item(notificationId, band: true),
              _item(siblingId),
            ];
            await cubit.refresh();
          }
          await mount(t, inbox: true);
          await t.pumpAndSettle();
          await t.tap(find.text('Target fixture').first);
          await t.pumpAndSettle();
          expect(
            find.byType(band ? BandProfileScreen : MusicianPublicProfileScreen),
            findsOneWidget,
          );
          onlyTarget();
        },
      );
    }

    for (final targetExists in [false, true]) {
      testWidgets(
        'artist venue band request requires its fresh visible incoming row, target=$targetExists',
        (t) async {
          await prepareBandVenue(t, targetExists: targetExists);
          openBandVenue();
          await t.pumpAndSettle();
          expect(find.byType(BandManagementPanelScreen), findsOneWidget);
          expect(find.byType(BandProfileScreen), findsNothing);
          expect(find.text('Fresh band'), findsWidgets);
          expect(find.text('Gelen İstekler'), findsOneWidget);
          expect(
            find.text(
              targetExists ? 'Exact venue request' : 'Unrelated venue request',
            ),
            findsOneWidget,
          );
          expect(bands.ownerGets, 2);
          expect(bands.publicGets, 0);
          expect(connections.pageReads, 1);
          expect(connections.target, ArtistVenueApplicationTarget.band);
          expect(connections.targetId, bandId);
          expect(connections.incoming, isTrue);
          expect(connections.sessionKey, recipient);
          expect(
            api.requests
                .where((request) => request.method == RecordedHttpMethod.get)
                .map((request) => request.path),
            ['/api/v1/user/notifications/$notificationId'],
          );
          expect(bands.decisionIds, isEmpty);
          expect(t.takeException(), isNull);
          if (targetExists) {
            onlyTarget();
          } else {
            unread();
          }
        },
      );
    }

    for (final member in [
      (role: 'MANAGER', status: 'ACTIVE'),
      (role: 'MEMBER', status: 'ACTIVE'),
      (role: 'FOUNDER', status: 'REMOVED'),
    ]) {
      testWidgets(
        'artist venue band request denies ${member.role}/${member.status} without widening management access',
        (t) async {
          await prepareBandVenue(t, role: member.role, status: member.status);
          openBandVenue();
          await t.pumpAndSettle();
          expect(find.byType(BandManagementPanelScreen), findsNothing);
          expect(find.byType(BandProfileScreen), findsNothing);
          expect(find.text('Root'), findsOneWidget);
          expect(
            find.textContaining('Bildirim şu anda açılamıyor'),
            findsOneWidget,
          );
          expect(bands.ownerGets, 1);
          expect(connections.pageReads, 0);
          unread();
        },
      );
    }

    testWidgets(
      'artist venue band request rejects a replaced session during fresh membership lookup',
      (t) async {
        await prepareBandVenue(t);
        bands.ownerPending = Completer<Result<BandProfile>>();
        openBandVenue();
        await t.pumpAndSettle();
        expect(bands.ownerGets, 1);
        sessions.replace(
          audienceSession(user: follower, role: 'ROLE_MUSICIAN'),
        );
        bands.ownerPending!.complete(Result.success(bands.ownerProfile!));
        await t.pumpAndSettle();
        expect(find.byType(BandManagementPanelScreen), findsNothing);
        expect(connections.pageReads, 0);
        expect(acks, isEmpty);
        expect(repository.items.every((item) => !item.read), isTrue);
      },
    );

    testWidgets(
      'artist venue band request ACK-only retry never repeats profile or incoming list reads',
      (t) async {
        await prepareBandVenue(t);
        failAck = true;
        openBandVenue();
        await t.pumpAndSettle();
        expect(acks, [notificationId]);
        expect(cubit.state.unreadCount, 2);
        final profileReads = bands.ownerGets;
        final pageReads = connections.pageReads;
        final targetGets = api.requests
            .where((r) => r.method == RecordedHttpMethod.get)
            .length;
        failAck = false;
        pendingAck = Completer<Object?>();
        final retry = t
            .widget<SnackBarAction>(find.byType(SnackBarAction))
            .onPressed;
        retry();
        retry();
        await t.pump();
        expect(acks, [notificationId, notificationId]);
        pendingAck!.complete(null);
        await t.pumpAndSettle();
        expect(cubit.state.unreadCount, 1);
        expect(reconciliations, 1);
        expect(
          repository.items.singleWhere((item) => item.id == siblingId).read,
          isFalse,
        );
        expect(bands.ownerGets, profileReads);
        expect(connections.pageReads, pageReads);
        expect(
          api.requests.where((r) => r.method == RecordedHttpMethod.get).length,
          targetGets,
        );
      },
    );

    testWidgets(
      'band auto real loading public fallback and exact content ACK',
      (t) async {
        bandExact();
        bands.pending = Completer<Result<BandProfile>>();
        await mount(t);
        await open(t, band: true);
        unread();
        expect(bands.ownerGets, 1);
        expect(bands.publicGets, 1);
        bands.pending!.complete(const Result.success(_band));
        await t.pumpAndSettle();
        expect(find.byType(BandProfileScreen), findsOneWidget);
        expect(find.text('Fresh band'), findsWidgets);
        onlyTarget();
        expect(resolverGets(), 0);
      },
    );

    for (final phase in ['exact', 'resolver', 'profile', 'band']) {
      testWidgets('$phase failure explicit retry no resume retry', (t) async {
        failExact = phase == 'exact';
        failResolver = phase == 'resolver';
        profiles.failure = phase == 'profile';
        bands.failure = phase == 'band';
        if (phase == 'band') bandExact();
        await mount(t);
        await open(t, band: phase == 'band');
        await t.pumpAndSettle();
        unread();
        final before = api.requests.length;
        final loads = profiles.requestedIds.length + bands.publicGets;
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        expect(api.requests.length, before);
        expect(profiles.requestedIds.length + bands.publicGets, loads);
        failExact = false;
        failResolver = false;
        profiles.failure = false;
        bands.failure = false;
        await t.tap(find.text('Tekrar dene').first);
        await t.pumpAndSettle();
        onlyTarget();
      });
    }

    testWidgets(
      'ACK failure exposes busy guarded ACK only retry without reopening or rereading target',
      (t) async {
        failAck = true;
        await mount(t);
        await open(t);
        await t.pumpAndSettle();
        expect(acks, [notificationId]);
        expect(cubit.state.unreadCount, 2);
        final gets = api.requests
            .where((r) => r.method == RecordedHttpMethod.get)
            .length;
        final loads = profiles.requestedIds.length;
        final retry = find.text('Tekrar dene');
        expect(retry, findsOneWidget);
        failAck = false;
        pendingAck = Completer<Object?>();
        final action = t
            .widget<SnackBarAction>(find.byType(SnackBarAction))
            .onPressed;
        action();
        action();
        await t.pump();
        expect(acks, [notificationId, notificationId]);
        expect(cubit.state.unreadCount, 2);
        pendingAck!.complete(null);
        await t.pumpAndSettle();
        expect(cubit.state.unreadCount, 1);
        expect(reconciliations, 1);
        expect(
          api.requests.where((r) => r.method == RecordedHttpMethod.get).length,
          gets,
        );
        expect(profiles.requestedIds.length, loads);
      },
    );

    for (final field in [
      'id',
      'recipientId',
      'type',
      'action',
      'followerId',
      'bandId',
    ]) {
      testWidgets('mismatched exact $field never navigates or reads', (
        t,
      ) async {
        if (field == 'bandId') bandExact();
        if (['action', 'followerId', 'bandId'].contains(field)) {
          (exact['payload'] as Map)[field] = 'bad';
        } else {
          exact[field] = 'bad';
        }
        await mount(t);
        await open(t, band: field == 'bandId');
        await t.pumpAndSettle();
        unread();
        expect(resolverGets(), 0);
        expect(profiles.requestedIds, isEmpty);
        expect(find.text('Tekrar dene'), findsOneWidget);
      });
    }

    for (final kind in ['empty', 'unsupported', 'studio-restricted']) {
      testWidgets('$kind resolution remains explicitly unavailable unread', (
        t,
      ) async {
        resolved['profiles'] = kind == 'unsupported'
            ? [
                {
                  'type': 'MANAGER',
                  'profileId': profileId,
                  'displayName': 'Unsupported',
                },
              ]
            : [];
        if (kind == 'studio-restricted') {
          resolved['accessRestriction'] = 'STUDIO_MAINSTAGE_RESTRICTED';
        }
        await mount(t);
        await open(t);
        await t.pumpAndSettle();
        unread();
        expect(find.text('Tekrar dene'), findsOneWidget);
        expect(profiles.requestedIds, isEmpty);
      });
    }

    testWidgets(
      'multiple targets cancellation and stale selection do not ACK',
      (t) async {
        (resolved['profiles'] as List).add({
          'type': 'VENUE',
          'profileId': bandId,
          'displayName': 'Other choice',
        });
        await mount(t);
        await open(t);
        await t.pump(const Duration(milliseconds: 500));
        unread();
        expect(find.text('Açmak istediğin profili seç'), findsOneWidget);
        navigator.currentState!.pop();
        await t.pumpAndSettle();
        unread();
        expect(find.text('Tekrar dene'), findsOneWidget);
        await t.tap(find.text('Tekrar dene'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 500));
        resolved['profiles'] = [];
        await t.tap(find.text('Fresh resolver'));
        await t.pumpAndSettle();
        unread();
        expect(profiles.requestedIds, isEmpty);
        expect(resolverGets(), 3);
      },
    );

    testWidgets(
      'multiple targets chosen current musician uses real successful content',
      (t) async {
        (resolved['profiles'] as List).add({
          'type': 'VENUE',
          'profileId': bandId,
          'displayName': 'Other choice',
        });
        await mount(t);
        await open(t);
        await t.pump(const Duration(milliseconds: 500));
        unread();
        await t.tap(find.text('Fresh resolver'));
        await t.pumpAndSettle();
        onlyTarget();
        expect(resolverGets(), 2);
      },
    );
  }
}
