import 'support/notification_direct_test_host.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_direct_open.dart';
import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/models/app_notification_model.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/venue_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_plan.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_owner_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_performer_request_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_plan_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_requests_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_plan_performer_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_event_plan_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';

import 'support/event_audience_fakes.dart';
import 'support/event_invitation_navigation_fakes.dart' show InvitationRequests;

part 'venue_notification_event_open_test_register_venue_notification_event_open1.dart';
part 'venue_notification_event_open_test_register_venue_notification_event_open2.dart';
part 'venue_notification_event_open_test_cases.dart';

const _notification = '60000000-0000-4000-8000-000000000001';

const _other = '60000000-0000-4000-8000-000000000002';

const _sibling = '60000000-0000-4000-8000-000000000003';

const _user = '70000000-0000-4000-8000-000000000001';

const _venue = '80000000-0000-4000-8000-000000000001';

const _musician = '90000000-0000-4000-8000-000000000001';

const _event = 'a0000000-0000-4000-8000-000000000001';

const _plan = 'b0000000-0000-4000-8000-000000000001';

const _requested = 'EVENT_PERFORMER_APPROVAL_REQUESTED';

const _approved = 'EVENT_PERFORMER_APPROVED';

const _rejected = 'EVENT_PERFORMER_REJECTED';

const _missing = AppError(code: 'NOT_FOUND', message: 'Unavailable');

const _retry = 'Tekrar dene';

void main() {
  _VenueNotificationEventOpenCases().register();
}

class _Fixture {
  final navigator = GlobalKey<NavigatorState>();
  final sessions = AudienceTestSessions(
    audienceSession(user: _user, role: 'ROLE_VENUE'),
  );
  final notifications = _Notifications();
  final realtime = _Realtime();
  final events = _Events();
  final plans = _Plans();
  final profiles = _Profiles();
  final venues = _Venues();
  final requests = _Requests()
    ..items = [
      const EventPerformerRequest(
        requestId: 'c0000000-0000-4000-8000-000000000003',
        eventId: _event,
        eventTitle: 'Current invitation',
        eventDate: null,
        startTime: null,
        endTime: null,
        venueId: _venue,
        venueName: 'Current venue',
        venueProfilePictureUrl: null,
        targetType: EventPerformerTargetType.musician,
        targetId: _musician,
        musicianProfileId: _musician,
        bandId: null,
        performerName: 'Current performer',
        status: EventPerformerRequestStatus.pending,
        createdAt: null,
        decidedAt: null,
      ),
    ];
  late final api = _Api(notifications);
  late final cubit = NotificationCubit(
    notifications,
    _Tokens(),
    sessions: sessions,
    realtimeClient: realtime,
    onDeliveryStateChanged: () async {
      comparisons++;
    },
  );
  int comparisons = 0;

  Future<void> prepareSecond() async {
    api.dto = {...api.dto, 'id': _other};
    notifications.items.add(
      AppNotificationModel.fromJson({...api.dto, 'id': _sibling}),
    );
    await cubit.refresh();
  }

  void pushSecond() {
    unawaited(
      NotificationDirectOpen.start(
        navigator.currentContext!,
        identity: _other,
        builder: (_) => const VenueNotificationOpenScreen(
          target: PushTarget(
            notificationId: _other,
            recipientId: _user,
            type: _requested,
          ),
        ),
      ),
    );
  }

  void expectSecondUnread() {
    expect(api.acks, [_notification]);
    expect(
      notifications.items.singleWhere((n) => n.id == _other).read,
      isFalse,
    );
    expect(
      notifications.items.singleWhere((n) => n.id == _sibling).read,
      isFalse,
    );
    expect(cubit.state.unreadCount, 2);
    expect(comparisons, 1);
  }

  void expectSecondRead(
    WidgetTester tester, {
    bool plan = false,
    int secondAttempts = 1,
  }) {
    expect(api.acks, [_notification, ...List.filled(secondAttempts, _other)]);
    for (final rows in [notifications.items, cubit.state.items]) {
      expect(rows.singleWhere((n) => n.id == _notification).read, isTrue);
      expect(rows.singleWhere((n) => n.id == _other).read, isTrue);
      expect(rows.singleWhere((n) => n.id == _sibling).read, isFalse);
    }
    expect(cubit.state.unreadCount, 1);
    expect(comparisons, 2);
    if (plan) {
      expect(find.byType(EventPlanPerformerScreen), findsOneWidget);
    } else {
      expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
    }
    expect(notifications.broadMutations, 0);
    expect(tester.takeException(), isNull);
  }

  Future<void> cover(WidgetTester tester, {bool dialog = false}) async {
    if (dialog) {
      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) => const AlertDialog(content: Text('Temporary cover')),
        ),
      );
    } else {
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Temporary cover')),
          ),
        ),
      );
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> mount(
    WidgetTester tester, {
    required String type,
    bool plan = false,
    String purpose = 'PERFORMER_CONSENT',
    String? action,
    AppLifecycleState initialLifecycle = AppLifecycleState.resumed,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(initialLifecycle);
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      final disposing = dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await disposing;
    });
    sessions.replace(
      audienceSession(
        user: _user,
        role: type == _requested ? 'ROLE_MUSICIAN' : 'ROLE_VENUE',
      ),
    );
    api.dto = {
      'id': _notification,
      'recipientId': _user,
      'type': type,
      'title': 'Snapshot title',
      'message': '',
      'read': false,
      'payload': {
        'module': plan ? 'EVENT_PLAN' : 'EVENT_PERFORMER',
        'action':
            action ??
            (type == _requested
                ? 'APPROVAL_REQUESTED'
                : type == _approved
                ? 'APPROVED'
                : 'REJECTED'),
        if (plan) 'planId': _plan else 'eventId': _event,
        if (!plan) 'requestId': 'c0000000-0000-4000-8000-000000000003',
        'requestPurpose': purpose,
        'musicianProfileId': _musician,
        'performerType': 'MUSICIAN',
        'targetType': 'MUSICIAN',
        'targetId': _musician,
        'venueId': _venue,
      },
    };
    notifications.items = [
      AppNotificationModel.fromJson(api.dto),
      AppNotificationModel.fromJson({
        ...api.dto,
        'id': _other,
        'title': 'Unrelated unread',
      }),
    ];
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    serviceLocator.registerSingleton<NotificationTargetRepository>(
      NotificationTargetRepository(api, sessions),
    );
    serviceLocator.registerSingleton<NotificationCubit>(cubit);
    serviceLocator.registerSingleton<VenueEventRepository>(events);
    serviceLocator.registerSingleton<EngagementRepository>(_Engagement());
    serviceLocator.registerSingleton<EventPlanRepository>(plans);
    serviceLocator.registerSingleton<MusicianProfileRepository>(profiles);
    serviceLocator.registerSingleton<VenueProfileRepository>(venues);
    serviceLocator.registerSingleton<EventPerformerRequestRepository>(requests);
    await cubit.ensureStarted();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [notificationTargetRouteObserver],
        home: NotificationDirectTestHost(
          opener: VenueNotificationOpenScreen(
            target: PushTarget(
              notificationId: _notification,
              recipientId: _user,
              type: type,
            ),
          ),
        ),
      ),
    );
  }

  void expectOneRead(WidgetTester tester, {int attempts = 1}) {
    expect(api.acks, List.filled(attempts, _notification));
    expect(
      api.contexts.every(
        (context) => context?.expectedToken == sessions.session.token,
      ),
      isTrue,
    );
    expect(
      notifications.items.singleWhere((row) => row.id == _notification).read,
      isTrue,
    );
    expect(
      notifications.items.singleWhere((row) => row.id == _other).read,
      isFalse,
    );
    expect(
      cubit.state.items.singleWhere((row) => row.id == _notification).read,
      isTrue,
    );
    expect(
      cubit.state.items.singleWhere((row) => row.id == _other).read,
      isFalse,
    );
    expect(cubit.state.unreadCount, 1);
    expect(comparisons, 1);
    expect(find.byType(NotificationScreen), findsNothing);
    expect(notifications.broadMutations, 0);
    expect(tester.takeException(), isNull);
  }

  Future<void> hide(WidgetTester tester, String reason) async {
    switch (reason) {
      case 'background':
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      case 'dialog':
        unawaited(
          showDialog<void>(
            context: navigator.currentContext!,
            builder: (_) => const AlertDialog(content: Text('Other dialog')),
          ),
        );
      case 'removed':
        unawaited(
          navigator.currentState!.pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Other destination')),
            ),
          ),
        );
      case 'token':
        sessions.replace(
          audienceSession(user: _user, role: 'ROLE_VENUE', token: 'new-token'),
        );
      case 'logout':
        sessions.replace(const AuthSession.guest());
      case 'account':
        sessions.replace(audienceSession(user: _other, role: 'ROLE_VENUE'));
    }
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, String reason) async {
    if (reason == 'background') {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    } else {
      navigator.currentState!.pop();
    }
    await tester.pumpAndSettle();
  }

  void expectNoRead(WidgetTester tester) {
    expect(api.acks, isEmpty);
    expect(notifications.items.every((row) => !row.read), isTrue);
    expect(cubit.state.items.every((row) => !row.read), isTrue);
    expect(comparisons, 0);
    expect(find.byType(NotificationScreen), findsNothing);
    expect(notifications.broadMutations, 0);
  }

  Future<void>? _disposing;
  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    await cubit.close();
    await realtime.dispose();
    sessions.dispose();
  }
}

class _Api extends Fake implements ApiClient {
  _Api(this.repository);
  final _Notifications repository;
  Map<String, dynamic> dto = {};
  bool offline = false, failAck = false;
  Completer<void>? ackPending;
  Completer<void>? getPending;
  int gets = 0;
  final acks = <String>[];
  final contexts = <ApiRequestContext?>[];
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    contexts.add(requestContext);
    if (method == ApiHttpMethod.get) {
      gets++;
      expect(path, '/api/v1/user/notifications/${dto['id']}');
      await getPending?.future;
      if (offline) throw StateError('offline');
      return decoder!(dto);
    }
    expect(method, ApiHttpMethod.post);
    final notificationId = path.split('/')[5];
    expect(path, '/api/v1/user/notifications/$notificationId/read');
    expect(repository.items.any((row) => row.id == notificationId), isTrue);
    acks.add(notificationId);
    await ackPending?.future;
    if (failAck) throw StateError('offline');
    repository.items = repository.items
        .map((row) => row.id == notificationId ? row.copyWith(read: true) : row)
        .toList();
    return null as T;
  }
}

class _Notifications extends Fake implements NotificationRepository {
  List<AppNotification> items = [];
  int broadMutations = 0;
  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async => Result.success(Page(items: List.of(items), hasNext: false));
  @override
  Future<Result<int>> getUnreadCount() async =>
      Result.success(items.where((row) => !row.read).length);
  @override
  Future<Result<int>> markAllAsRead() async {
    broadMutations++;
    return const Result.success(0);
  }

  @override
  Future<Result<int>> clearAllNotifications() async {
    broadMutations++;
    return const Result.success(0);
  }
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => null;
}

class _Realtime extends NotificationRealtimeClient {
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({required String userId, required String token}) async {}
  @override
  Future<void> disconnect() async {}
}

class _Events extends Fake implements VenueEventRepository {
  bool missing = false;
  Completer<Result<VenueEventDetail>>? pending;
  final readIds = <String>[];
  final detail = const VenueEventDetail(
    id: _event,
    shareUrl: null,
    posterImage: null,
    performerName: 'Current manual performer',
    musicianProfileId: null,
    title: 'Current event',
    description: 'Current authored description',
    performerType: 'MANUAL',
  );
  @override
  Future<Result<VenueEventDetail>> getDetail(String id) async {
    readIds.add(id);
    return pending?.future ??
        (missing ? const Result.failure(_missing) : Result.success(detail));
  }
}

class _Plans extends Fake implements EventPlanRepository {
  String consent = 'PENDING', target = _musician;
  bool missing = false;
  List<EventPlan>? performerListItems;
  Map<int, List<EventPlan>>? performerPages;
  final performerListPages = <int>[];
  Completer<void>? performerListPending;
  Completer<Result<EventPlan>>? pending;
  Completer<Result<EventPlan>>? destinationPending;
  final ownerReads = <String>[],
      performerReads = <String>[],
      occurrenceReads = <String>[],
      performerLists = <String>[];
  EventPlan get value => valueFor();
  EventPlan valueFor({String id = _plan, String title = 'Current plan'}) =>
      EventPlan(
        id: id,
        version: 7,
        definition: EventPlanDefinition(
          venueId: _venue,
          startDate: DateTime(2027, 1, 1),
          untilDate: DateTime(2027, 1, 2),
          weekdays: [5, 6],
          excludedDates: [],
          template: EventPlanTemplate(
            title: title,
            startTime: '20:00',
            endTime: '21:00',
            musicianProfileId: target,
          ),
        ),
        venueName: 'Current venue',
        performerName: 'Current performer',
        status: 'ACTIVE',
        consentStatus: consent,
        showOnProfile: false,
        serverNow: DateTime.utc(2026, 9, 24),
        decisionAllowed: consent == 'PENDING',
        withdrawAllowed: consent == 'ACCEPTED',
      );
  Future<Result<EventPlan>> read() async =>
      pending?.future ??
      (missing ? const Result.failure(_missing) : Result.success(value));
  @override
  Future<Result<EventPlan>> getOwner(String planId) {
    ownerReads.add(planId);
    if (ownerReads.length > 1 && destinationPending != null) {
      return destinationPending!.future;
    }
    return read();
  }

  @override
  Future<Result<EventPlan>> getPerformer(String planId) {
    performerReads.add(planId);
    return read();
  }

  @override
  Future<Result<EventPlanPage<EventPlan>>> listPerformer(
    EventPerformerTargetType type,
    String targetId, {
    int page = 0,
  }) async {
    performerLists.add(targetId);
    performerListPages.add(page);
    await performerListPending?.future;
    return Result.success(
      EventPlanPage(
        items: performerPages?[page] ?? performerListItems ?? [value],
        page: page,
        hasNext: performerPages?.containsKey(page + 1) == true,
      ),
    );
  }

  @override
  Future<Result<EventPlanPage<EventPlanOccurrence>>> occurrences(
    String planId, {
    int page = 0,
  }) async {
    occurrenceReads.add(planId);
    return const Result.success(
      EventPlanPage(items: [], page: 0, hasNext: false),
    );
  }
}

class _Profiles extends Fake implements MusicianProfileRepository {
  bool reject = false;
  @override
  Future<Result<MusicianProfile>> getMyProfile() async => reject
      ? const Result.failure(_missing)
      : const Result.success(
          MusicianProfile(
            id: _musician,
            userId: _user,
            username: 'Fixture musician',
            stageName: null,
            bio: null,
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
          ),
        );
}

class _Requests extends InvitationRequests {
  Completer<void>? pending;
  @override
  Future<Result<EventPerformerRequestPage>> listMine({
    EventPerformerRequestStatus status = EventPerformerRequestStatus.pending,
    int page = 0,
    int size = 20,
    EventPerformerTargetType? targetType,
    String? targetId,
  }) async {
    final result = await super.listMine(
      status: status,
      page: page,
      size: size,
      targetType: targetType,
      targetId: targetId,
    );
    await pending?.future;
    return result;
  }
}

class _Venues extends Fake implements VenueProfileRepository {
  String owner = _user;
  final readIds = <String?>[];
  @override
  Future<Result<VenueOwnerProfile>> getMyVenueProfileDetail({
    String? venueId,
  }) async {
    readIds.add(venueId);
    return Result.success(
      VenueOwnerProfile(
        venueProfileId: _venue,
        venueId: _venue,
        ownerUserId: owner,
        venueName: 'Current venue',
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
        cityId: null,
        cityName: null,
        districtId: null,
        districtName: null,
        neighborhoodId: null,
        neighborhoodName: null,
        status: 'APPROVED',
        activeMusicians: [],
        activeBands: [],
        weeklyEvents: [],
      ),
    );
  }
}

class _Engagement extends Fake implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));
}
