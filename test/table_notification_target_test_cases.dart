part of 'table_notification_target_test.dart';

class _TableNotificationTargetCases {
  late AudienceTestSessions sessions;
  late NotificationCubit cubit;
  late _Inbox inbox;
  late RecordingApiClient api;
  late NotificationTargetRepository targets;
  late Map<String, dynamic> response;
  late GlobalKey<NavigatorState> nav;
  late BuildContext inboxContext;
  late _Routes routes;
  late List<String> acks;
  Completer<Object?>? pendingGet, pendingAck, pendingChat;
  bool failGet = false, failAck = false, failChat = false, failDetail = false;
  var reconciliations = 0;
  Future<void> settle(WidgetTester t) async {
    // The real list's create button deliberately repeats its pulse animation.
    // Allow a bounded set of real frames without waiting for it to stop.
    if (find.byType(TableGroupListScreen).evaluate().isNotEmpty) {
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    } else {
      await t.pumpAndSettle();
    }
  }

  Future<void> mount(
    WidgetTester t, {
    bool paused = false,
    bool realInbox = false,
  }) async {
    t.view.physicalSize = const Size(420, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [notificationTargetRouteObserver, routes],
        home: const Scaffold(body: Text('Home')),
      ),
    );
    unawaited(
      nav.currentState!.push<void>(
        MaterialPageRoute(
          builder: (context) {
            inboxContext = context;
            if (realInbox) {
              return BlocProvider.value(
                value: cubit,
                child: const NotificationScreen(),
              );
            }
            return const Scaffold(body: Text('Inbox'));
          },
        ),
      ),
    );
    await settle(t);
    if (paused) {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    }
  }

  Future<void> open(
    WidgetTester t, {
    AppNotification? selected,
    bool native = false,
  }) async {
    unawaited(
      NotificationDirectOpen.start(
        inboxContext,
        identity: (selected ?? inbox.items.first).id,
        builder: (_) => native
            ? TableNotificationOpenScreen.native(
                target: PushTarget(
                  notificationId: (selected ?? inbox.items.first).id,
                  recipientId: (selected ?? inbox.items.first).recipientId,
                  type: (selected ?? inbox.items.first).type,
                ),
              )
            : TableNotificationOpenScreen(
                notification: selected ?? inbox.items.first,
              ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
  }

  int gets() =>
      api.requests.where((r) => r.path.endsWith('/table-target')).length;

  void unread() {
    expect(cubit.state.items.every((i) => !i.read), isTrue);
    expect(cubit.state.unreadCount, 2);
    expect(reconciliations, 0);
  }

  void onlyTarget() {
    expect(cubit.state.items.first.read, isTrue);
    expect(cubit.state.items.last.read, isFalse);
    expect(cubit.state.unreadCount, 1);
    expect(reconciliations, 1);
  }

  Future<void> detail(
    WidgetTester t, {
    required bool pending,
    bool wrongCycle = false,
  }) async {
    response = targetJson(
      type: pending
          ? 'TABLE_JOIN_REQUEST_RECEIVED'
          : 'TABLE_JOIN_REQUEST_APPROVED',
      kind: pending ? 'PENDING_APPLICATION' : 'CHAT',
    );
    inbox.items = [
      item(notificationId, type: response['type'] as String),
      item(siblingId),
    ];
    await cubit.refresh();
    final target = TableNotificationTarget.fromJson(
      response,
      inbox.items.first,
    );
    final group = TableGroup(
      id: tableId,
      ownerId: pending ? recipient : applicant,
      ownerUsername: 'Owner',
      ownerProfileImageUrl: null,
      venueId: null,
      venueName: null,
      description: 'Görev masası',
      maxPersonCount: 6,
      genderPrefs: const [],
      ageMin: 18,
      ageMax: 99,
      meetingAt: DateTime.utc(2030),
      expiresAt: DateTime.utc(2030, 1, 2),
      status: 'ACTIVE',
      participants: [
        TableGroupParticipant(
          userId: pending ? recipient : applicant,
          joinedAt: DateTime.utc(2026),
          status: TableGroupParticipantStatus.accepted,
          joinNote: null,
          username: 'Owner',
          profilePictureUrl: null,
        ),
        TableGroupParticipant(
          userId: pending ? applicant : recipient,
          applicationId: wrongCycle ? siblingId : cycleId,
          joinedAt: DateTime.utc(2026),
          status: pending
              ? TableGroupParticipantStatus.pending
              : TableGroupParticipantStatus.accepted,
          joinNote: null,
          username: 'Exact applicant',
          profilePictureUrl: null,
        ),
        if (pending)
          TableGroupParticipant(
            userId: siblingId,
            applicationId: siblingId,
            joinedAt: DateTime.utc(2027),
            status: TableGroupParticipantStatus.pending,
            joinNote: null,
            username: 'Other applicant',
            profilePictureUrl: null,
          ),
      ],
      city: const TableGroupLocation(id: 'city', name: 'City'),
      district: null,
      neighborhood: null,
    );
    await mount(t);
    final route = MaterialPageRoute<void>(
      builder: (_) => TableGroupDetailScreen(
        args: TableGroupDetailArgs(
          tableGroupId: tableId,
          notificationTarget: target,
        ),
        repository: _Tables(group),
        gameRepository: _Games(),
        tokenStore: _Tokens(),
        sessions: sessions,
        realtimeClient: _ChatRealtime(),
        now: () => DateTime.utc(2026, 9, 30),
      ),
    );
    NotificationTargetRead.table(
      notification: target.notification,
      cubit: cubit,
      sessions: sessions,
      repository: targets,
      content: target,
    ).attach(route);
    unawaited(nav.currentState!.push(route));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
  }

  void register() {
    _registerTableNotificationTarget1();
    _registerTableNotificationTarget2();
  }
}
