import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_direct_open.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/backline_catalog.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_equipment.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_room.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_page.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/backline_catalog_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_equipment_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_room_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/studio_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/studio_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/studio_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/venue_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_public_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_listener_info_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_public_profile_screen.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_connection_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_action_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_count_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_media.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/musician_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/profile_media_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_public_profile_screen.dart';

import 'support/event_audience_fakes.dart';

import 'dart:async';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_user_profile_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_user_profile_resolver_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/follow_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/band_follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/domain/spotify_repository.dart';
import 'support/recording_api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/venue_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/artist_venue_application.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_application_page.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_management_panel_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/band_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_received_invitation.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_invite_decision_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/my_bands_screen.dart';

const recipient = '10000000-0000-0000-0000-000000000001';
const follower = '20000000-0000-0000-0000-000000000001';
const profileId = '30000000-0000-0000-0000-000000000001';
const bandId = '40000000-0000-0000-0000-000000000001';
const notificationId = '50000000-0000-0000-0000-000000000001';
const siblingId = '50000000-0000-0000-0000-000000000002';
const fail = AppError(
  code: 'unavailable',
  message: 'Fixture temporarily unavailable',
);

void main() {
  late AudienceTestSessions sessions;
  late _ProfileRepository profiles;
  late _Bands bands;
  late _ConnectionRepository connections;
  late _Repository repository;
  late _Realtime realtime;
  late NotificationCubit cubit;
  late _BadgeCubit badge;
  late RecordingApiClient api;
  late DmUserProfileResolverImpl resolver;
  late GlobalKey<NavigatorState> navigator;
  late Map<String, dynamic> exact;
  late Map<String, dynamic> resolved;
  late List<String> acks;
  var failExact = false, failResolver = false, failAck = false;
  Completer<Object?>? pendingExact, pendingResolver, pendingAck;
  var reconciliations = 0;
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
              (item) => item.id == acks.last ? item.copyWith(read: true) : item,
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
  Future<void> mount(
    WidgetTester t, {
    bool inbox = false,
    bool paused = false,
  }) async {
    t.binding.handleAppLifecycleStateChanged(
      paused ? AppLifecycleState.paused : AppLifecycleState.resumed,
    );
    await t.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: ThemeData.dark(),
          navigatorKey: navigator,
          navigatorObservers: [notificationTargetRouteObserver],
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: inbox
              ? const NotificationScreen()
              : const Scaffold(body: Text('Root')),
        ),
      ),
    );
    await t.pump();
  }

  Future<void> open(
    WidgetTester t, {
    bool band = false,
    String id = notificationId,
  }) async {
    unawaited(
      NotificationDirectOpen.start(
        navigator.currentContext!,
        identity: id,
        builder: (_) => FollowNotificationOpenScreen(
          target: PushTarget(
            notificationId: id,
            recipientId: recipient,
            type: band ? 'SOCIAL_NEW_BAND_FOLLOWER' : 'SOCIAL_NEW_FOLLOWER',
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
  }

  void unread() {
    expect(acks, isEmpty);
    expect(cubit.state.unreadCount, 2);
    expect(cubit.state.items.every((i) => !i.read), isTrue);
    expect(reconciliations, 0);
  }

  void onlyTarget() {
    expect(acks, [notificationId]);
    expect(cubit.state.unreadCount, 1);
    expect(
      cubit.state.items.singleWhere((i) => i.id == notificationId).read,
      isTrue,
    );
    expect(
      cubit.state.items.singleWhere((i) => i.id == siblingId).read,
      isFalse,
    );
    expect(reconciliations, 1);
  }

  void bandExact() {
    exact['type'] = 'SOCIAL_NEW_BAND_FOLLOWER';
    exact['payload'] = {
      'action': 'NEW_BAND_FOLLOWER',
      'followerId': follower,
      'bandId': bandId,
    };
  }

  int resolverGets() =>
      api.requests.where((r) => r.path.contains('/profiles/by-user/')).length;

  Future<void> prepareNativeBand(WidgetTester t, String type) async {
    await t.runAsync(() async {
      sessions.replace(audienceSession(user: recipient, role: 'ROLE_MUSICIAN'));
      exact['type'] = type;
      exact['title'] = 'Fresh band notification';
      exact['message'] = 'Fresh actor projection';
      exact['payload'] = <String, dynamic>{
        'module': 'BAND',
        'bandId': bandId,
        'bandIdentityVersion': 1,
        'action': type.substring(5),
        switch (type) {
          'BAND_INVITE_RECEIVED' => 'inviterId',
          'BAND_MEMBER_REMOVED' => 'requesterId',
          _ => 'memberId',
        }: follower,
        if (type.startsWith('BAND_INVITE_')) 'invitationId': _bandInvitationId,
      };
      await cubit.ensureStarted();
      await cubit.refresh();
      reconciliations = 0;
    });
  }

  Future<void> openNativeBand(WidgetTester t) async {
    unawaited(
      NotificationDirectOpen.start(
        navigator.currentContext!,
        identity: notificationId,
        builder: (_) => BandNotificationOpenScreen(
          target: PushTarget(
            notificationId: notificationId,
            recipientId: recipient,
            type: exact['type'] as String,
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
  }

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
  Future<void> prepareBandVenue(
    WidgetTester t, {
    String role = 'FOUNDER',
    String status = 'ACTIVE',
    bool targetExists = true,
  }) async {
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    });
    sessions.replace(audienceSession(user: recipient, role: 'ROLE_MUSICIAN'));
    bands.ownerProfile = BandProfile(
      id: bandId,
      name: 'Fresh band',
      description: null,
      profilePictureUrl: null,
      instagramUrl: null,
      youtubeUrl: null,
      soundCloudUrl: null,
      spotifyEmbedUrl: null,
      spotifyArtistId: null,
      spotifyTrackIds: [],
      members: [
        BandMemberSummary(
          userId: recipient,
          profileId: profileId,
          username: 'Current member',
          profilePictureUrl: null,
          role: role,
          status: status,
        ),
      ],
    );
    const payload = {
      'module': 'ARTIST_VENUE',
      'action': 'REQUEST_CREATED',
      'requestByType': 'VENUE',
      'requestId': '60000000-0000-4000-8000-000000000009',
      'bandId': bandId,
      'venueId': '70000000-0000-4000-8000-000000000009',
    };
    exact = {
      'id': notificationId,
      'recipientId': recipient,
      'type': 'ARTIST_VENUE_LINK_APPLICATION_REQUEST',
      'read': false,
      'payload': payload,
    };
    repository.items = [
      const AppNotification(
        id: notificationId,
        recipientId: recipient,
        type: 'ARTIST_VENUE_LINK_APPLICATION_REQUEST',
        title: 'Venue band request',
        message: '',
        read: false,
        createdAt: null,
        payload: payload,
      ),
      _item(siblingId),
    ];
    connections.items = [
      ArtistVenueApplication(
        id: targetExists ? payload['requestId']! : siblingId,
        musicianProfileId: '',
        bandId: bandId,
        venueId: payload['venueId']!,
        musicianStageName: '',
        bandName: 'Fresh band',
        bandProfilePictureUrl: null,
        venueProfilePictureUrl: null,
        venueName: targetExists
            ? 'Exact venue request'
            : 'Unrelated venue request',
        message: null,
        status: 'PENDING',
        requestByType: 'VENUE',
        createdAt: '',
      ),
    ];
    await cubit.refresh();
    await mount(t);
  }

  void openBandVenue() {
    unawaited(
      NotificationDirectOpen.start(
        navigator.currentContext!,
        identity: notificationId,
        builder: (_) => const VenueNotificationOpenScreen(
          target: PushTarget(
            notificationId: notificationId,
            recipientId: recipient,
            type: 'ARTIST_VENUE_LINK_APPLICATION_REQUEST',
          ),
        ),
      ),
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
      sessions.replace(audienceSession(user: follower, role: 'ROLE_MUSICIAN'));
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

  testWidgets('band auto real loading public fallback and exact content ACK', (
    t,
  ) async {
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
  });
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
    testWidgets('mismatched exact $field never navigates or reads', (t) async {
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
  testWidgets('multiple targets cancellation and stale selection do not ACK', (
    t,
  ) async {
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
  });
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
          {'type': 'MUSICIAN', 'profileId': profileId, 'displayName': 'Fresh'},
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

const _wrongProfile = MusicianProfile(
  id: bandId,
  userId: follower,
  username: 'public-artist',
  stageName: null,
  bio: 'Public musician biography.',
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  spotifyTracks: [],
  instruments: [],
  activeVenues: [],
  bands: [],
);

const _profile = MusicianProfile(
  id: profileId,
  userId: follower,
  username: 'public-artist',
  stageName: null,
  bio: 'Public musician biography.',
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  spotifyTracks: [],
  instruments: [],
  activeVenues: [],
  bands: [],
);

class _ProfileRepository extends Fake implements MusicianProfileRepository {
  final requestedIds = <String>[];
  Completer<Result<MusicianProfile>>? pending;
  bool failure = false, wrong = false;

  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async {
    requestedIds.add(profileId);
    if (pending != null) return pending!.future;
    if (failure) return const Result.failure(fail);
    if (wrong) return Result.success(_wrongProfile);
    return const Result.success(_profile);
  }
}

class _MediaRepository extends Fake implements ProfileMediaRepository {
  @override
  Future<Result<ProfileMedia>> getProfileMedia({
    required String profileType,
    required String profileId,
  }) async => const Result.success(
    ProfileMedia(featuredVideo: null, videos: [], audios: []),
  );
}

class _ConnectionRepository extends Fake
    implements ArtistVenueConnectionRepository {
  List<ArtistVenueApplication> items = [];
  int pageReads = 0;
  ArtistVenueApplicationTarget? target;
  String? targetId, sessionKey;
  bool? incoming;
  @override
  Future<Result<ArtistVenueApplicationPage>> listApplicationPage({
    required ArtistVenueApplicationTarget target,
    required String targetId,
    required bool incoming,
    bool connectionsOnly = false,
    int page = 0,
    int size = 20,
    String? expectedSessionKey,
  }) async {
    pageReads++;
    this.target = target;
    this.targetId = targetId;
    this.incoming = incoming;
    sessionKey = expectedSessionKey;
    return Result.success(
      ArtistVenueApplicationPage(
        items: items,
        page: page,
        size: size,
        totalElements: items.length,
        totalPages: items.isEmpty ? 0 : 1,
        last: true,
      ),
    );
  }
}

class _FollowRepository extends Fake implements FollowRepository {
  @override
  Future<Result<int>> getFollowersCount(String userId) async =>
      const Result.success(0);

  @override
  Future<Result<int>> getFollowingCount(String userId) async =>
      const Result.success(0);

  @override
  Future<Result<bool>> isFollowing({
    required String followerId,
    required String followingId,
  }) async => const Result.success(false);
}

class _EngagementRepository extends Fake implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));
}

class _BadgeCubit extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _BadgeCubit() : super(const DmBadgeState.initial());

  @override
  Future<void> ensureStarted() async {}

  @override
  Future<void> reconcileAfterResume() async {}

  @override
  Future<void> stop() async {}
}

AppNotification _item(String id, {bool band = false}) => AppNotification(
  id: id,
  recipientId: recipient,
  type: band ? 'SOCIAL_NEW_BAND_FOLLOWER' : 'SOCIAL_NEW_FOLLOWER',
  title: id == notificationId ? 'Target fixture' : 'Sibling fixture',
  message: 'Fixture',
  read: false,
  createdAt: DateTime.utc(2026, 9, 28),
  payload: {
    'action': band ? 'NEW_BAND_FOLLOWER' : 'NEW_FOLLOWER',
    'followerId': follower,
    if (band) 'bandId': bandId,
  },
);

class _Repository extends Fake implements NotificationRepository {
  List<AppNotification> items = [_item(notificationId), _item(siblingId)];
  final readIds = <String>[];
  bool failRead = false;
  Completer<Result<void>>? pendingRead;

  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async => Result.success(Page(items: items, hasNext: false));

  @override
  Future<Result<int>> getUnreadCount() async =>
      Result.success(items.where((item) => !item.read).length);

  @override
  Future<Result<void>> markAsRead({required String notificationId}) async {
    readIds.add(notificationId);
    final result =
        await (pendingRead?.future ??
            Future.value(
              failRead
                  ? const Result<void>.failure(
                      AppError(code: 'unavailable', message: 'ACK unavailable'),
                    )
                  : const Result<void>.success(null),
            ));
    if (result.isSuccess) {
      items = items
          .map(
            (item) =>
                item.id == notificationId ? item.copyWith(read: true) : item,
          )
          .toList();
    }
    return result;
  }
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => null;
}

class _Realtime extends NotificationRealtimeClient {
  @override
  Stream<AppNotification> get notificationStream => const Stream.empty();
  @override
  Stream<int> get badgeStream => const Stream.empty();
  @override
  Stream<void> get connectionStream => const Stream.empty();
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({required String userId, required String token}) async {}
  @override
  Future<void> disconnect() async {}
}

const _band = BandProfile(
  id: bandId,
  name: 'Fresh band',
  description: 'Current band',
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundCloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  members: [],
);

const _bandInvitationId = '60000000-0000-0000-0000-000000000001';

class _Bands extends Fake implements BandRepository {
  BandProfile? ownerProfile;
  Completer<Result<BandProfile>>? ownerPending;
  String currentInvitationId = _bandInvitationId;
  final decisionIds = <String?>[];
  bool activeAgain = false;
  Completer<Result<List<BandSummary>>>? pendingMyBands;
  @override
  Future<Result<BandReceivedInvitation>> getCurrentReceivedInvitation({
    required String bandId,
    required String expectedSessionKey,
  }) async => Result.success(
    BandReceivedInvitation(
      bandId: bandId,
      bandName: 'Fresh band',
      invitationId: currentInvitationId,
    ),
  );
  @override
  Future<Result<void>> rejectInvite({
    required String bandId,
    String? expectedSessionKey,
    String? invitationId,
  }) async {
    decisionIds.add(invitationId);
    return const Result.success(null);
  }

  @override
  Future<Result<List<BandSummary>>> getMyBands() async =>
      pendingMyBands?.future ??
      (failure ? const Result.failure(fail) : const Result.success([]));
  @override
  Future<Result<BandReceivedInvitationPage>> getReceivedInvitations({
    int page = 0,
    int size = 20,
    required String expectedSessionKey,
  }) async => Result.success(
    BandReceivedInvitationPage(
      items: const [],
      page: page,
      size: size,
      totalElements: 0,
      hasNext: false,
    ),
  );
  int ownerGets = 0, publicGets = 0;
  bool failure = false;
  Completer<Result<BandProfile>>? pending;
  @override
  Future<Result<BandProfile>> getBandById(String id) async {
    ownerGets++;
    if (ownerPending != null) return ownerPending!.future;
    if (ownerProfile != null) return Result.success(ownerProfile!);
    return const Result.failure(fail);
  }

  @override
  Future<Result<BandProfile>> getPublicBandById(String id) async {
    publicGets++;
    return pending?.future ??
        (failure ? const Result.failure(fail) : const Result.success(_band));
  }
}

class _BandFollow extends Fake implements BandFollowRepository {
  @override
  Future<Result<int>> getFollowersCount(String id) async =>
      const Result.success(0);
  @override
  Future<Result<bool>> isFollowingBand(String id) async =>
      const Result.success(false);
}

class _Spotify extends Fake implements SpotifyRepository {}

class _Listeners extends Fake implements ListenerProfileRepository {
  _Listeners({required this.ghost});
  final bool ghost;
  int gets = 0;
  @override
  Future<Result<ListenerPublicProfile>> getPublicProfile(String id) async {
    gets++;
    return Result.success(
      ListenerPublicProfile(
        id: id,
        userId: follower,
        username: ghost ? 'Ghost listener' : 'Public listener',
        visibilityMode: ghost
            ? ListenerVisibilityMode.ghost
            : ListenerVisibilityMode.standard,
        bio: null,
        profilePictureMediaId: null,
        profilePictureUrl: null,
        followerCount: ghost ? null : 0,
        followingCount: ghost ? null : 0,
        restricted: ghost,
        canFollow: !ghost,
        canMessage: !ghost,
      ),
    );
  }
}

class _Venues extends Fake implements VenueProfileRepository {
  int gets = 0;
  @override
  Future<Result<VenuePublicProfile>> getPublicVenueProfile({
    String? venueId,
  }) async {
    gets++;
    return Result.success(
      VenuePublicProfile(
        venueProfileId: bandId,
        venueId: venueId!,
        ownerUserId: follower,
        venueName: 'Public venue',
        bio: null,
        profilePictureUrl: null,
        instagramUrl: null,
        youtubeUrl: null,
        websiteUrl: null,
        address: null,
        phone: null,
        website: null,
        description: null,
        musicStartTime: null,
        cityName: null,
        districtName: null,
        neighborhoodName: null,
        activeMusicians: [],
        activeBands: [],
        weeklyEvents: [],
      ),
    );
  }
}

class _Studios extends Fake implements StudioProfileRepository {
  int gets = 0;
  @override
  Future<Result<StudioProfile>> getPublicProfile(String id) async {
    gets++;
    return Result.success(
      StudioProfile(
        id: id,
        userId: follower,
        name: 'Public studio',
        description: null,
        profilePictureMediaId: null,
        profilePictureUrl: null,
        address: null,
        phone: null,
        website: null,
        facilities: [],
        instagramUrl: null,
        youtubeUrl: null,
        timeZone: 'Europe/Istanbul',
        version: 0,
        spotifyTrackIds: [],
        spotifyTracks: [],
        activeRoomCount: 0,
        backlineUnitCount: 0,
      ),
    );
  }
}

StudioPage<T> _emptyPage<T>() => StudioPage(
  items: [],
  pageIndex: 0,
  pageSize: 20,
  totalItems: 0,
  totalPages: 0,
  isFirst: true,
  isLast: true,
);

class _Rooms extends Fake implements StudioRoomRepository {
  @override
  Future<Result<StudioPage<StudioRoom>>> listPublicRooms(
    String id, {
    int page = 0,
    int size = 10,
  }) async => Result.success(_emptyPage());
}

class _Equipment extends Fake implements StudioEquipmentRepository {
  @override
  Future<Result<StudioPage<StudioEquipment>>> listPublicEquipment({
    required String studioProfileId,
    String? query,
    String? categoryId,
    StudioEquipmentAvailabilityBucket? availabilityBucket,
    required int page,
    required int size,
  }) async => Result.success(_emptyPage());
}

class _Catalog extends Fake implements BacklineCatalogRepository {
  @override
  Future<Result<StudioPage<BacklineCatalogCategory>>> listCatalog({
    required int page,
    required int size,
  }) async => Result.success(_emptyPage());
}
