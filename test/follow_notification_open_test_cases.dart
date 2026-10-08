part of 'follow_notification_open_test.dart';

class _FollowNotificationOpenCases {
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
  var customProfileUser = follower;
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

  Future<void> prepareCustomProfile() async {
    exact['type'] = 'ADMIN_BROADCAST';
    exact['payload'] = <String, dynamic>{};
    repository.items[0] = const AppNotification(
      id: notificationId,
      recipientId: recipient,
      type: 'ADMIN_BROADCAST',
      title: 'Custom profile',
      message: '',
      read: false,
      createdAt: null,
      payload: {},
    );
    await cubit.refresh();
  }

  Future<void> openCustomProfile(WidgetTester t) async {
    unawaited(
      NotificationDirectOpen.start(
        navigator.currentContext!,
        identity: notificationId,
        builder: (_) => const CustomNotificationOpenScreen(
          target: PushTarget(
            notificationId: notificationId,
            recipientId: recipient,
            type: 'ADMIN_BROADCAST',
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
  }

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

  void register() {
    _registerFollowNotificationOpen1();
    _registerFollowNotificationOpen2();
    _registerOwnProfileCases();
  }
}
