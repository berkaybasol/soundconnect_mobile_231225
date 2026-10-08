part of 'follow_notification_open_test.dart';

extension _RegisterFollowNotificationOpen2 on _FollowNotificationOpenCases {
  void _registerFollowNotificationOpen2() {
    for (final change in [
      'cover',
      'pop',
      'background',
      'token',
      'account',
      'logout',
    ]) {
      testWidgets(
        'late real profile completion after $change cannot ACK or retry automatically',
        (t) async {
          profiles.pending = Completer<Result<MusicianProfile>>();
          await mount(t);
          await open(t);
          unread();
          if (change == 'cover') {
            unawaited(
              navigator.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Cover')),
                ),
              ),
            );
            await t.pump(const Duration(milliseconds: 400));
          }
          if (change == 'pop') {
            navigator.currentState!.pop();
            await t.pump(const Duration(milliseconds: 400));
          }
          if (change == 'background') {
            t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          }
          if (['token', 'account', 'logout'].contains(change)) {
            await t.runAsync(() async {
              sessions.replace(
                change == 'logout'
                    ? const AuthSession.guest()
                    : audienceSession(
                        user: change == 'account' ? follower : recipient,
                        token: 'replacement',
                      ),
              );
              await cubit.stop();
            });
          }
          profiles.pending!.complete(const Result.success(_profile));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          expect(acks, isEmpty);
          if (change == 'cover') navigator.currentState!.pop();
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await t.pumpAndSettle();
          expect(acks, isEmpty);
          expect(profiles.requestedIds, [profileId]);
        },
      );
    }

    testWidgets(
      'wrong profile identity from actual target GET never yields success read',
      (t) async {
        profiles.wrong = true;
        await mount(t);
        await open(t);
        await t.pumpAndSettle();
        unread();
        expect(find.text('Tekrar dene'), findsOneWidget);
      },
    );

    testWidgets(
      'initial paused entry waits for resume once and another notification can enter',
      (t) async {
        await mount(t, paused: true);
        await open(t);
        expect(api.requests, isEmpty);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        onlyTarget();
        exact['id'] = siblingId;
        await open(t, id: siblingId);
        await t.pumpAndSettle();
        expect(acks, [notificationId, siblingId]);
        expect(cubit.state.unreadCount, 0);
        expect(resolverGets(), 2);
        expect(profiles.requestedIds, [profileId, profileId]);
      },
    );

    for (final type in ['VENUE', 'LISTENER', 'GHOST', 'STUDIO']) {
      testWidgets(
        '$type loads real public profile and acknowledges only visible current content',
        (t) async {
          if (type != 'VENUE') {
            await t.runAsync(() async {
              sessions.replace(
                audienceSession(user: recipient, role: 'ROLE_MUSICIAN'),
              );
              await cubit.stop();
              await cubit.ensureStarted();
            });
          }
          resolved['profiles'] = [
            {
              'type': type == 'GHOST' ? 'LISTENER' : type,
              'profileId': profileId,
              'displayName': 'Fresh resolver',
              'visibilityMode': type == 'GHOST' ? 'GHOST' : 'STANDARD',
            },
          ];
          final listeners = _Listeners(ghost: type == 'GHOST');
          final studios = _Studios();
          final venues = _Venues();
          serviceLocator
            ..registerSingleton<ListenerProfileRepository>(listeners)
            ..registerSingleton<StudioProfileRepository>(studios)
            ..registerSingleton<VenueProfileRepository>(venues)
            ..registerFactory<ListenerProfileCubit>(
              () => ListenerProfileCubit(listeners, sessions: sessions),
            )
            ..registerFactory<StudioProfileCubit>(
              () => StudioProfileCubit(studios),
            )
            ..registerFactory<VenueProfileCubit>(
              () => VenueProfileCubit(venues, sessions: sessions),
            );
          await mount(t);
          await open(t);
          await t.pumpAndSettle();
          expect(
            find.byType(
              type == 'VENUE'
                  ? VenuePublicProfileScreen
                  : type == 'STUDIO'
                  ? StudioPublicProfileScreen
                  : ListenerPublicProfileScreen,
            ),
            findsOneWidget,
          );
          expect(listeners.gets + studios.gets + venues.gets, 1);
          onlyTarget();
          if (type == 'GHOST') {
            expect(find.text('Takip Et'), findsNothing);
            expect(find.text('UNTRUSTED SNAPSHOT'), findsNothing);
          }
        },
      );
    }

    testWidgets(
      'listener encountering current studio access restriction never reads',
      (t) async {
        resolved['profiles'] = [
          {
            'type': 'STUDIO',
            'profileId': profileId,
            'displayName': 'Fresh studio',
          },
        ];
        await mount(t);
        await open(t);
        await t.pumpAndSettle();
        expect(find.byType(StudioListenerInfoScreen), findsOneWidget);
        unread();
      },
    );

    for (final code in ['403', '404', 'offline']) {
      testWidgets(
        'exact $code failure stays unread and explicit retry performs a fresh GET',
        (t) async {
          pendingExact = Completer<Object?>();
          await mount(t);
          await open(t);
          unread();
          pendingExact!.completeError(
            ApiException(
              AppError(code: code, message: 'Current target unavailable'),
            ),
          );
          await t.pumpAndSettle();
          unread();
          final gets = api.requests.length;
          pendingExact = null;
          await t.tap(find.text('Tekrar dene'));
          await t.pumpAndSettle();
          onlyTarget();
          expect(api.requests.length, greaterThan(gets));
        },
      );
    }

    test(
      'expired token blocks exact lookup fresh resolver and ACK before HTTP',
      () async {
        final expired = AuthSession.authenticated(
          token: 'expired',
          userId: recipient,
          username: 'fixture',
          accountStatus: 'ACTIVE',
          roles: const ['ROLE_LISTENER'],
          permissions: const [],
          expiresAt: DateTime.utc(2020),
          isAdmin: false,
        );
        sessions.replace(expired);
        await cubit.stop();
        final repo = serviceLocator<NotificationTargetRepository>();
        expect(
          (await repo.resolveFollow(
            const PushTarget(
              notificationId: notificationId,
              recipientId: recipient,
              type: 'SOCIAL_NEW_FOLLOWER',
            ),
            expired,
          )).isSuccess,
          isFalse,
        );
        expect(
          (await resolver.resolveFreshForFollow(
            userId: follower,
            session: expired,
          )).isSuccess,
          isFalse,
        );
        expect(
          (await repo.acknowledge(_item(notificationId), expired)).isSuccess,
          isFalse,
        );
        expect(api.requests, isEmpty);
      },
    );

    test(
      'closed follow target parsing rejects identity extras malformed versions and expired wire',
      () {
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final type in PushTarget.followTypes) {
          final minimal = <String, dynamic>{
            'notificationId': notificationId,
            'recipientId': recipient,
            'type': type,
          };
          final wire = <String, dynamic>{
            ...minimal,
            'presentationVersion': 'ANDROID_FOLLOW_V1',
            'displayVariant': 'DEFAULT',
            'sentAt': '$now',
            'expiresAt': '${now + 60000}',
          };
          expect(PushTarget.parse(minimal)?.isFollow, isTrue);
          expect(PushTarget.parse(wire)?.isFollow, isTrue);
          for (final key in [
            'followerId',
            'bandId',
            'profileId',
            'username',
            'body',
            'avatarUrl',
            'conversationId',
            'route',
            'deeplink',
          ]) {
            expect(PushTarget.parse({...wire, key: profileId}), isNull);
          }
          for (final key in wire.keys) {
            expect(PushTarget.parse({...wire}..remove(key)), isNull);
          }
          for (final patch in [
            {'presentationVersion': 'ANDROID_NATIVE_V5'},
            {'presentationVersion': 'ANDROID_FOLLOW_V2'},
            {'displayVariant': 'OTHER'},
            {'sentAt': '${now + 30000}'},
            {'expiresAt': '${now - 1}'},
            {'notificationId': 'bad'},
            {'recipientId': 'bad'},
          ]) {
            expect(PushTarget.parse({...wire, ...patch}), isNull);
          }
        }
      },
    );

    for (final cache in ['positive', 'negative']) {
      test(
        'follow resolver bypasses $cache cache and distinguishes failure from empty',
        () async {
          failResolver = cache == 'negative';
          await resolver.resolveByUserId(userId: follower);
          final prior = resolverGets();
          failResolver = false;
          resolved['profiles'] = [];
          final fresh = await resolver.resolveFreshForFollow(
            userId: follower,
            session: sessions.session,
          );
          expect(fresh.isSuccess, isTrue);
          expect(fresh.data, isEmpty);
          expect(resolverGets(), prior + 1);
          failResolver = true;
          final failed = await resolver.resolveFreshForFollow(
            userId: follower,
            session: sessions.session,
          );
          expect(failed.isSuccess, isFalse);
          failResolver = false;
          resolved['profiles'] = [
            {
              'type': 'MUSICIAN',
              'profileId': profileId,
              'displayName': 'Fresh',
            },
          ];
          expect(
            (await resolver.resolveFreshForFollow(
              userId: follower,
              session: sessions.session,
            )).data!.single.id,
            profileId,
          );
        },
      );
    }
  }
}
