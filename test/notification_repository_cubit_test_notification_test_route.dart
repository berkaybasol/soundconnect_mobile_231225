part of 'notification_repository_cubit_test.dart';

Route<void> _notificationTestRoute(
  RouteSettings settings, {
  bool ready = false,
}) {
  final route = MaterialPageRoute<void>(
    settings: _notificationRouteSettings(settings),
    builder: (_) => ready
        ? const NotificationTargetReady(
            child: Scaffold(body: Text('Verified test destination')),
          )
        : const SizedBox.shrink(),
  );
  final arguments = settings.arguments;
  if (arguments is NotificationReadArguments &&
      settings.name == arguments.routeName) {
    arguments.ticket.attach(route);
  }
  return route;
}

class _DmPreviewRepository extends Fake implements DmRepository {
  final reads = <String>[];

  @override
  Future<Result<DmConversationPreview>> getConversationPreview({
    required String conversationId,
  }) async {
    reads.add(conversationId);
    return Result.success(
      DmConversationPreview(
        conversationId: conversationId,
        otherUserId: 'verified-listener-user',
        otherUsername: 'current-public-ghost-name',
        otherUserProfilePicture: null,
        otherUserVisibilityMode: ListenerVisibilityMode.ghost,
        lastMessageContent: null,
        lastMessageType: null,
        lastMessageSenderId: null,
        lastMessageAt: null,
        lastMessageRead: null,
      ),
    );
  }
}

class _StudioTargetRepository extends Fake
    implements NotificationTargetRepository {
  _StudioTargetRepository({this.archived = false});
  final bool archived;
  bool failLookup = false;
  final lookups = <PushTarget>[];
  final ackIds = <String>[];

  @override
  Future<Result<StudioReservationNotificationTarget>> resolveStudio(
    PushTarget target,
    AuthSession session,
  ) async {
    lookups.add(target);
    if (failLookup) {
      return const Result.failure(NotificationTargetRepository.unavailable);
    }
    return Result.success(
      StudioReservationNotificationTarget(
        notificationId: target.notificationId,
        recipientId: target.recipientId,
        type: target.type,
        reservationId: '90000000-0000-4000-8000-000000000001',
        roomId: '90000000-0000-4000-8000-000000000002',
        studioProfileId: '90000000-0000-4000-8000-000000000003',
        studioName: 'Current verified studio',
        roomName: 'Current verified room',
        ownerMode: !archived,
        status: archived ? 'CANCELLED_BY_STUDIO' : 'CANCELLED_BY_CUSTOMER',
        roomArchived: archived,
        completed: false,
        startsAt: DateTime.utc(2026, 9, 28, 12),
        endsAt: DateTime.utc(2026, 9, 28, 13),
        zoneId: 'Europe/Istanbul',
        localDate: '2026-09-28',
        localEndDate: '2026-09-28',
        localStartTime: '15:00',
        localEndTime: '16:00',
      ),
    );
  }

  @override
  Future<Result<void>> acknowledge(
    AppNotification item,
    AuthSession session,
  ) async {
    ackIds.add(item.id);
    return const Result.success(null);
  }
}

Future<InvitationRequests> _openApprovalNotification(
  WidgetTester tester,
  Map<String, dynamic> target, {
  bool personalVisible = true,
  bool bandVisible = true,
}) async {
  await serviceLocator.reset();
  addTearDown(serviceLocator.reset);
  _registerInvitationAccess(
    personalVisible: personalVisible,
    bandVisible: bandVisible,
  );
  final invitations = InvitationRequests();
  serviceLocator.registerSingleton<EventPerformerRequestRepository>(
    invitations,
  );
  final repository = _NotificationRepositoryFake(
    pages: {
      0: Result.success(
        pagination.Page<AppNotification>(
          items: [
            _notification(
              'scoped-invitation',
              recipientId: 'owner-1',
              type: 'EVENT_PERFORMER_APPROVAL_REQUESTED',
              payload: {
                'module': 'EVENT_PERFORMER',
                'action': 'APPROVAL_REQUESTED',
                ...target,
              },
            ),
          ],
          hasNext: false,
        ),
      ),
    },
  );
  final realtime = NotificationRealtimeClient();
  final cubit = NotificationCubit(
    repository,
    _MemoryTokenStore(),
    realtimeClient: realtime,
  );
  addTearDown(() async {
    await cubit.close();
    await realtime.dispose();
  });
  _registerFreshNotificationTarget(
    cubit,
    repository.pages[0]!.data!.items.single,
  );
  await tester.pumpWidget(
    BlocProvider<NotificationCubit>.value(
      value: cubit,
      child: MaterialApp(
        navigatorObservers: [notificationTargetRouteObserver],
        home: const NotificationScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('scoped-invitation'));
  await tester.pumpAndSettle();
  return invitations;
}

void _registerInvitationAccess({
  bool personalVisible = true,
  bool bandVisible = true,
}) {
  final session = InvitationSession();
  final personal = InvitationCalendar(visible: personalVisible);
  final band = InvitationCalendar(visible: bandVisible);
  serviceLocator.registerSingleton<AuthSessionManager>(session);
  serviceLocator.registerSingleton<MusicianProfileRepository>(
    InvitationProfileRepository(),
  );
  serviceLocator.registerSingleton<BandRepository>(InvitationBands());
  serviceLocator.registerSingleton<MusicianCalendarRepository>(personal);
  serviceLocator.registerSingleton<BandCalendarRepositoryFactory>(
    InvitationBandCalendars(band),
  );
  addTearDown(() async {
    session.dispose();
    await personal.dispose();
    await band.dispose();
  });
}

Future<WeeklyCalendarEvent> _openPerformerEventNotification(
  WidgetTester tester, {
  required String type,
  required String action,
  required VenueEventDetail detail,
}) async {
  await serviceLocator.reset();
  addTearDown(serviceLocator.reset);
  final sessions = AudienceTestSessions(
    audienceSession(user: 'user-1', role: 'ROLE_VENUE'),
  );
  serviceLocator.registerSingleton<AuthSessionManager>(sessions);
  addTearDown(sessions.dispose);
  serviceLocator.registerSingleton<VenueEventRepository>(
    _PerformerNotificationVenueEventRepository(detail),
  );
  serviceLocator.registerSingleton<EngagementRepository>(
    _PerformerNotificationEngagementRepository(),
  );
  serviceLocator.registerSingleton<MusicianProfileRepository>(
    _PerformerNotificationMusicianRepository(),
  );

  final notification = _notification(
    'event-performer-${type.toLowerCase()}',
    type: type,
    payload: <String, dynamic>{
      'module': 'EVENT_PERFORMER',
      'action': action,
      'eventId': detail.id,
      'musicianProfileId': 'musician-stale',
      'bandId': 'band-stale',
      'performerName': 'Eski Sanatçı',
      'venueId': 'stale-unapproved-venue',
    },
  );
  final repository = _NotificationRepositoryFake(
    pages: <int, Result<pagination.Page<AppNotification>>>{
      0: Result.success(
        pagination.Page<AppNotification>(
          items: <AppNotification>[notification],
          hasNext: false,
        ),
      ),
    },
  );
  final realtime = NotificationRealtimeClient();
  final cubit = NotificationCubit(
    repository,
    _MemoryTokenStore(),
    realtimeClient: realtime,
  );
  addTearDown(() async {
    await cubit.close();
    await realtime.dispose();
  });

  _registerFreshNotificationTarget(cubit, notification);
  await tester.pumpWidget(
    BlocProvider<NotificationCubit>.value(
      value: cubit,
      child: MaterialApp(
        navigatorObservers: [notificationTargetRouteObserver],
        home: const NotificationScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(notification.title));
  await tester.pumpAndSettle();

  return tester
      .widget<WeeklyEventDetailScreen>(find.byType(WeeklyEventDetailScreen))
      .event;
}

AppNotification _notification(
  String id, {
  String? title,
  String recipientId = 'user-1',
  String type = 'GENERAL',
  bool read = false,
  Map<String, dynamic> payload = const <String, dynamic>{},
}) {
  return AppNotification(
    id: id,
    recipientId: recipientId,
    type: type,
    title: title ?? id,
    message: 'Message',
    read: read,
    createdAt: null,
    payload: payload,
  );
}

class _NotificationApiClientFake extends ApiClient {
  _NotificationApiClientFake(this.handler);

  final Future<Object?> Function(String path, Map<String, dynamic>? query)
  handler;
  Map<String, dynamic>? lastQuery;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) async {
    lastQuery = query;
    final payload = await handler(path, query);
    return decoder == null ? payload as T : decoder(payload);
  }

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();
}

class _RecordingDmProfileResolver implements DmUserProfileResolver {
  _RecordingDmProfileResolver(this.targets);

  final List<DmProfileTarget> targets;
  int calls = 0;

  @override
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  }) async {
    calls += 1;
    return targets;
  }
}

class _NotificationRepositoryFake implements NotificationRepository {
  _NotificationRepositoryFake({
    required this.pages,
    this.unread = const Result.success(0),
  });

  final Map<int, Result<pagination.Page<AppNotification>>> pages;
  final Result<int> unread;
  final List<int> requestedPages = <int>[];
  Result<void> deleteResult = const Result.success(null);
  Completer<Result<void>>? markReadRequest;
  final markReadIds = <String>[];
  int markAllCalls = 0;

  @override
  Future<Result<pagination.Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    return pages[page] ??
        const Result.success(
          pagination.Page<AppNotification>(items: [], hasNext: false),
        );
  }

  @override
  Future<Result<int>> getUnreadCount() async => unread;

  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async => deleteResult;

  @override
  Future<Result<int>> clearAllNotifications() async => const Result.success(0);

  @override
  Future<Result<List<AppNotification>>> getRecentNotifications() async =>
      const Result.success(<AppNotification>[]);

  @override
  Future<Result<int>> markAllAsRead() async {
    markAllCalls++;
    return const Result.success(0);
  }

  @override
  Future<Result<void>> markAsRead({required String notificationId}) async {
    markReadIds.add(notificationId);
    return markReadRequest?.future ?? const Result.success(null);
  }
}

class _EmptyEventPerformerRequestRepository
    implements EventPerformerRequestRepository {
  @override
  Future<Result<void>> reconsider(
    String requestId, {
    required bool showOnProfile,
  }) => throw UnimplementedError(
    'Unexpected reconsideration in notification test.',
  );

  @override
  Future<Result<EventPerformerRequestPage>> listMine({
    EventPerformerRequestStatus status = EventPerformerRequestStatus.pending,
    int page = 0,
    int size = 20,
    EventPerformerTargetType? targetType,
    String? targetId,
  }) async => Result.success(
    EventPerformerRequestPage(
      items: const <EventPerformerRequest>[],
      page: page,
      size: size,
      totalElements: 0,
      totalPages: 0,
      hasNext: false,
    ),
  );

  @override
  Future<Result<void>> accept(
    String requestId, {
    bool showOnProfile = false,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> reject(String requestId) async =>
      const Result.success(null);
}

class _DeferredEventRepository extends Fake implements VenueEventRepository {
  _DeferredEventRepository(this.pending);
  final Completer<Result<VenueEventDetail>> pending;
  int reads = 0;
  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) {
    reads++;
    return pending.future;
  }
}

class _PerformerNotificationVenueEventRepository
    implements VenueEventRepository {
  final VenueEventDetail detail;

  _PerformerNotificationVenueEventRepository(this.detail);

  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) async =>
      Result.success(detail);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PerformerNotificationEngagementRepository
    implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PerformerNotificationMusicianRepository
    implements MusicianProfileRepository {
  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async => const Result.failure(
    AppError(
      code: 'not_needed',
      message: 'Profile rendering is not under test.',
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControlledNotificationRepository implements NotificationRepository {
  final List<Completer<Result<pagination.Page<AppNotification>>>> listRequests =
      <Completer<Result<pagination.Page<AppNotification>>>>[];
  Result<int> unreadResult = const Result.success(0);
  Completer<Result<int>>? unreadRequest;
  int unreadCalls = 0;
  Completer<Result<int>>? markAllRequest;
  Completer<Result<int>>? clearAllRequest;
  Completer<Result<void>>? markReadRequest;
  Completer<Result<void>>? deleteRequest;

  @override
  Future<Result<pagination.Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) {
    final request = Completer<Result<pagination.Page<AppNotification>>>();
    listRequests.add(request);
    return request.future;
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    unreadCalls += 1;
    return unreadRequest?.future ?? unreadResult;
  }

  @override
  Future<Result<int>> clearAllNotifications() async =>
      clearAllRequest?.future ?? const Result.success(0);

  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async => deleteRequest?.future ?? const Result.success(null);

  @override
  Future<Result<List<AppNotification>>> getRecentNotifications() async =>
      const Result.success(<AppNotification>[]);

  @override
  Future<Result<int>> markAllAsRead() async =>
      markAllRequest?.future ?? const Result.success(0);

  @override
  Future<Result<void>> markAsRead({required String notificationId}) async =>
      markReadRequest?.future ?? const Result.success(null);
}

class _TestNotificationRealtimeClient extends NotificationRealtimeClient {
  final StreamController<AppNotification> _notificationController =
      StreamController<AppNotification>.broadcast();
  final StreamController<int> _badgeController =
      StreamController<int>.broadcast();
  final StreamController<void> _connectionController =
      StreamController<void>.broadcast();
  bool _connected = false;

  @override
  Stream<AppNotification> get notificationStream =>
      _notificationController.stream;

  @override
  Stream<int> get badgeStream => _badgeController.stream;

  @override
  Stream<void> get connectionStream => _connectionController.stream;

  @override
  bool get isConnected => _connected;

  @override
  void retain() {}

  @override
  Future<void> release() async {}

  @override
  Future<void> connect({required String userId, required String token}) async {
    _connected = true;
    _connectionController.add(null);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  void emitNotification(AppNotification notification) {
    _notificationController.add(notification);
  }

  void emitBadge(int count) {
    _badgeController.add(count);
  }

  Future<void> closeStreams() async {
    await super.dispose();
    await _notificationController.close();
    await _badgeController.close();
    await _connectionController.close();
  }
}

class _MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> readToken() async => value;

  @override
  Future<void> writeToken(String token) async => value = token;
}

String _jwt(String subject) {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode(const <String, dynamic>{'alg': 'none'})}.'
      '${encode(<String, dynamic>{'sub': subject})}.signature';
}

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(predicate(), isTrue);
}

// Domain-navigation tests receive an authoritative notification fixture here;
// wire identity, recipient and token validation have their own repository suite.
void _registerFreshNotificationTarget(
  NotificationCubit cubit,
  AppNotification item,
) {
  serviceLocator.registerSingleton<NotificationCubit>(cubit);
  serviceLocator.registerSingleton<NotificationTargetRepository>(
    _FreshNotificationTarget(item),
  );
}

class _FreshNotificationTarget extends Fake
    implements NotificationTargetRepository {
  _FreshNotificationTarget(this.item, {this.lookup});
  final AppNotification item;
  final Completer<Result<AppNotification>>? lookup;
  @override
  Future<Result<AppNotification>> resolve(
    PushTarget target,
    AuthSession session,
  ) async => Result.success(item);
  @override
  Future<Result<AppNotification>> resolveInboxProduct(
    AppNotification selected,
    AuthSession session,
  ) async => lookup == null ? Result.success(item) : lookup!.future;
  @override
  Future<Result<void>> acknowledge(
    AppNotification selected,
    AuthSession session,
  ) async => const Result.success(null);
}
