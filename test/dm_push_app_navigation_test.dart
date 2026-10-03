import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/inbox_product_notification_open.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_room.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_reservation.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_page.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_room_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_direct_open.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/media_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/follow_notification_open_screen.dart';
import 'support/recording_api_client.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/app/app.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/deep_link/app_deep_link.dart';
import 'package:soundconnect_23_12_25codx/core/deep_link/pending_app_deep_link_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart'
    as pagination;
import 'package:soundconnect_23_12_25codx/core/push/push_coordinator.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_delivered_reconciler.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_delivery_api.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_conversation_preview.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/screens/dm_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';

import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/studio_reservation_notification_open_screen.dart';
import 'support/auth_widget_test_support.dart';

const _user = '10000000-0000-4000-8000-000000000001';
const _notification = '10000000-0000-4000-8000-000000000002';
const _otherNotification = '10000000-0000-4000-8000-000000000003';
const _conversation = '10000000-0000-4000-8000-000000000004';
const _epoch = '10000000-0000-4000-8000-000000000005';

enum _PreviewOutcome { failure, exception, missingConversation }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final type in PushTarget.collabTypes) {
    testWidgets(
      'real app cold $type and warm second Collab preserve unread on target failure',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final fixture = _Fixture(
          _PreviewOutcome.failure,
          target: PushTarget(
            notificationId: _notification,
            recipientId: _user,
            type: type,
          ),
        );
        fixture.repository.firstType = type;
        await fixture.setup();
        addTearDown(fixture.close);
        final api = RecordingApiClient(
          (request) => throw StateError('offline'),
        );
        await _replace<NotificationTargetRepository>(
          NotificationTargetRepository(api, fixture.sessions),
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          SoundConnectApp(
            appLinkSource: _Links(),
            appDeepLinkInbox: AppDeepLinkInbox(
              store: MemoryPendingAppDeepLinkStore(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(fixture.push.consumed, 1);
        expect(
          find.byType(InboxProductNotificationOpen, skipOffstage: false),
          findsOneWidget,
        );
        _expectPreserved(fixture);
        expect(api.requests.single.path.endsWith('$_notification/collab-target'), isTrue);
        fixture.push._pending = PushTarget(
          notificationId: _otherNotification,
          recipientId: _user,
          type: type,
        );
        fixture.push.notifyListeners();
        await tester.pumpAndSettle();
        expect(fixture.push.consumed, 2);
        expect(api.requests.length, 2);
        expect(api.requests.last.path.endsWith('$_otherNotification/collab-target'), isTrue);
        expect(
          find.byType(InboxProductNotificationOpen, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.byType(NotificationScreen), findsNothing);
        _expectPreserved(fixture);
        await tester.tap(find.text('Tekrar dene'));
        await tester.pumpAndSettle();
        expect(api.requests.length, 3);
        _expectPreserved(fixture);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final type in PushTarget.followTypes) {
    testWidgets(
      'real app cold $type and warm second follow preserve unread on target failure',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final fixture = _Fixture(
          _PreviewOutcome.failure,
          target: PushTarget(
            notificationId: _notification,
            recipientId: _user,
            type: type,
          ),
        );
        fixture.repository.firstType = type;
        await fixture.setup();
        addTearDown(fixture.close);
        final api = RecordingApiClient(
          (request) => throw StateError('offline'),
        );
        await _replace<NotificationTargetRepository>(
          NotificationTargetRepository(api, fixture.sessions),
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          SoundConnectApp(
            appLinkSource: _Links(),
            appDeepLinkInbox: AppDeepLinkInbox(
              store: MemoryPendingAppDeepLinkStore(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(fixture.push.consumed, 1);
        expect(
          find.byType(FollowNotificationOpenScreen, skipOffstage: false),
          findsOneWidget,
        );
        _expectPreserved(fixture);
        expect(api.requests.single.path.endsWith(_notification), isTrue);
        fixture.push._pending = PushTarget(
          notificationId: _otherNotification,
          recipientId: _user,
          type: type,
        );
        fixture.push.notifyListeners();
        await tester.pumpAndSettle();
        expect(fixture.push.consumed, 2);
        expect(api.requests.length, 2);
        expect(api.requests.last.path.endsWith(_otherNotification), isTrue);
        expect(
          find.byType(FollowNotificationOpenScreen, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.byType(NotificationScreen), findsNothing);
        _expectPreserved(fixture);
        await tester.tap(find.text('Tekrar dene'));
        await tester.pumpAndSettle();
        expect(api.requests.length, 3);
        _expectPreserved(fixture);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final type in PushTarget.mediaTypes) {
    testWidgets(
      'real app cold $type and warm second MEDIA preserve unread on target failure',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final fixture = _Fixture(
          _PreviewOutcome.failure,
          target: PushTarget(
            notificationId: _notification,
            recipientId: _user,
            type: type,
          ),
        );
        fixture.repository.firstType = type;
        await fixture.setup();
        addTearDown(fixture.close);
        final api = RecordingApiClient(
          (request) => throw StateError('offline'),
        );
        await _replace<NotificationTargetRepository>(
          NotificationTargetRepository(api, fixture.sessions),
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          SoundConnectApp(
            appLinkSource: _Links(),
            appDeepLinkInbox: AppDeepLinkInbox(
              store: MemoryPendingAppDeepLinkStore(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(fixture.push.consumed, 1);
        expect(
          find.byType(MediaNotificationOpenScreen, skipOffstage: false),
          findsOneWidget,
        );
        _expectPreserved(fixture);
        expect(api.requests.single.path.endsWith(_notification), isTrue);
        fixture.push._pending = PushTarget(
          notificationId: _otherNotification,
          recipientId: _user,
          type: type,
        );
        fixture.push.notifyListeners();
        await tester.pumpAndSettle();
        expect(fixture.push.consumed, 2);
        expect(api.requests.length, 2);
        expect(api.requests.last.path.endsWith(_otherNotification), isTrue);
        expect(
          find.byType(MediaNotificationOpenScreen, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.byType(NotificationScreen), findsNothing);
        _expectPreserved(fixture);
        await tester.tap(find.text('Tekrar dene'));
        await tester.pumpAndSettle();
        expect(api.requests.length, 3);
        _expectPreserved(fixture);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final outcome in _PreviewOutcome.values) {
    testWidgets(
      'real app DM push ${outcome.name} preserves unrelated unread and OS cards',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final fixture = _Fixture(outcome);
        await fixture.setup();
        addTearDown(fixture.close);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );

        await tester.pumpWidget(
          SoundConnectApp(
            appLinkSource: _Links(),
            appDeepLinkInbox: AppDeepLinkInbox(
              store: MemoryPendingAppDeepLinkStore(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(fixture.push.restored?.userId, _user);
        expect(fixture.push.consumed, 1);
        expect(
          fixture.dm.previewRequests,
          outcome == _PreviewOutcome.missingConversation
              ? isEmpty
              : [_conversation],
        );
        // Assert the destructive consequence, not only the chosen widget. The
        // old app fallback mounted NotificationScreen and changed both stores.
        _expectPreserved(fixture);
        expect(find.byType(NotificationScreen), findsNothing);
        expect(
          find.byType(DmNotificationOpenScreen, skipOffstage: false),
          findsOneWidget,
        );
        expect(
          NotificationDirectOpen.routeOf(
            tester.element(
              find.byType(DmNotificationOpenScreen, skipOffstage: false),
            ),
          )?.settings.name,
          isNot('/dm-notification'),
        );
        expect(find.text('Tekrar dene'), findsOneWidget);

        await tester.tap(find.text('Tekrar dene'));
        await tester.pumpAndSettle();
        expect(
          fixture.dm.previewRequests.length,
          outcome == _PreviewOutcome.missingConversation ? 0 : 2,
        );
        _expectPreserved(fixture);
        expect(find.byType(NotificationScreen), findsNothing);
        expect(
          find.byType(DmNotificationOpenScreen, skipOffstage: false),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final fail in [false, true]) {
    testWidgets(
      'real app studio push failure=$fail keeps exact route and sibling OS card',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        const target = PushTarget(
          notificationId: _notification,
          recipientId: _user,
          type: 'STUDIO_RESERVATION_APPROVED',
        );
        final fixture = _Fixture(_PreviewOutcome.failure, target: target);
        fixture.repository.firstType = target.type;
        await fixture.setup();
        addTearDown(fixture.close);
        await _replace<StudioRoomRepository>(_NativeStudioRooms());
        final api = _StudioApi(
          fixture.repository,
          fail,
          () => find
              .byKey(const ValueKey('studio-reservation-$_conversation'))
              .evaluate()
              .isNotEmpty,
        );
        await _replace<NotificationTargetRepository>(
          NotificationTargetRepository(api, fixture.sessions),
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          SoundConnectApp(
            appLinkSource: _Links(),
            appDeepLinkInbox: AppDeepLinkInbox(
              store: MemoryPendingAppDeepLinkStore(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(fixture.push.consumed, 1);
        expect(
          find.byType(
            StudioReservationNotificationOpenScreen,
            skipOffstage: false,
          ),
          fail ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(StudioReservationCalendarScreen),
          fail ? findsNothing : findsOneWidget,
        );
        expect(find.byType(NotificationScreen), findsNothing);
        expect(
          find.byType(DmNotificationOpenScreen, skipOffstage: false),
          findsNothing,
        );
        expect(fixture.dm.previewRequests, isEmpty);
        expect(
          api.paths.first,
          '/api/v1/user/notifications/$_notification/studio-reservation',
        );
        if (fail) {
          _expectPreserved(fixture);
          expect(find.text('Tekrar dene'), findsOneWidget);
        } else {
          expect(api.sawDetailAtAck, isTrue);
          expect(fixture.repository.markAllCalls, 0);
          expect(fixture.repository.readIds, [_notification]);
          expect(fixture.repository.unreadIds, {_otherNotification});
          expect(fixture.notifications.state.unreadCount, 1);
          expect(fixture.tray.dismissed, [_notification]);
          expect(fixture.tray.cards, {_otherNotification});
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

void _expectPreserved(_Fixture fixture) {
  expect(fixture.repository.markAllCalls, 0);
  expect(fixture.repository.readIds, isEmpty);
  expect(fixture.repository.unreadIds, {_notification, _otherNotification});
  expect(fixture.notifications.state.initialized, isTrue);
  expect(fixture.notifications.state.unreadCount, 2);
  expect(
    fixture.notifications.state.items
        .where((item) => !item.read)
        .map((item) => item.id),
    unorderedEquals([_notification, _otherNotification]),
  );
  expect(fixture.tray.dismissed, isEmpty);
  expect(fixture.tray.cards, {_notification, _otherNotification});
}

class _Fixture {
  _Fixture(this.outcome, {this.target});
  final PushTarget? target;
  final _PreviewOutcome outcome;
  final tokens = MemoryTokenStore();
  final metadata = MemoryAuthSessionStore();
  late final sessions = AuthSessionManager(
    tokenStore: tokens,
    sessionStore: metadata,
    expiryTimerFactory: (_, _) => _NoTimer(),
  );
  final repository = _Notifications();
  final realtime = _Realtime();
  final tray = _Tray();
  final dmBadge = _DmBadge();
  late final dm = _DmRepository(outcome);
  late final delivery = PushDeliveredReconciler(
    sessions,
    tray,
    _DeliveryApi(repository),
  );
  late final notifications = NotificationCubit(
    repository,
    tokens,
    realtimeClient: realtime,
    sessions: sessions,
    onDeliveryStateChanged: delivery.reconcile,
  );
  late final push = _PendingPush(
    target ??
        PushTarget(
          notificationId: _notification,
          recipientId: _user,
          type: 'DM_NEW_MESSAGE',
          conversationId: outcome == _PreviewOutcome.missingConversation
              ? null
              : _conversation,
        ),
  );

  Future<void> setup() async {
    setupDependencies();
    tokens.token = _token();
    metadata.metadata = const AuthSessionMetadata(
      username: 'test-producer',
      accountStatus: 'ACTIVE',
    );
    await _replace<TokenStore>(tokens);
    await _replace<AuthSessionStore>(metadata);
    await _replace<AuthSessionManager>(sessions);
    await _replace<PushCoordinator>(push);
    await _replace<DmRepository>(dm);
    await _replace<NotificationCubit>(notifications);
    await _replace<DmBadgeCubit>(dmBadge);
    await _replace<ProfileMediaUploadRepository>(_Uploads());
  }

  Future<void> close() async {
    await notifications.close();
    await realtime.dispose();
    await dmBadge.close();
    delivery.dispose();
    push.dispose();
    sessions.dispose();
    await serviceLocator.reset();
  }
}

Future<void> _replace<T extends Object>(T value) async {
  await serviceLocator.unregister<T>();
  serviceLocator.registerSingleton<T>(value);
}

class _PendingPush extends Fake with ChangeNotifier implements PushCoordinator {
  _PendingPush(this.target);
  final PushTarget target;
  PushTarget? _pending;
  AuthSession? restored;
  int consumed = 0;
  @override
  Future<void> start({Future<AuthSession>? initialSession}) async {
    restored = await initialSession;
    _pending = target;
    notifyListeners();
  }

  @override
  PushTarget? consumePending() {
    final result = _pending;
    _pending = null;
    if (result != null) consumed++;
    return result;
  }

  @override
  PushTarget? get pending => _pending;
  @override
  Future<void> reconcile() async {}
}

class _DmRepository extends Fake implements DmRepository {
  _DmRepository(this.outcome);
  final _PreviewOutcome outcome;
  final previewRequests = <String>[];
  @override
  Future<Result<DmConversationPreview>> getConversationPreview({
    required String conversationId,
  }) async {
    previewRequests.add(conversationId);
    if (outcome == _PreviewOutcome.exception) throw StateError('offline');
    return const Result.failure(AppError(code: 'OFFLINE', message: 'offline'));
  }
}

class _Notifications extends Fake implements NotificationRepository {
  final unreadIds = {_notification, _otherNotification};
  String firstType = 'DM_NEW_MESSAGE';
  final readIds = <String>[];
  int markAllCalls = 0;
  List<AppNotification> get items => [_notification, _otherNotification]
      .map(
        (id) => AppNotification(
          id: id,
          recipientId: _user,
          type: id == _notification ? firstType : 'SOCIAL_NEW_FOLLOWER',
          title: 'Unread notification',
          message: 'Must remain unread',
          read: !unreadIds.contains(id),
          createdAt: DateTime.utc(2026, 9, 24),
          payload: const {},
        ),
      )
      .toList();
  @override
  Future<Result<pagination.Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async => Result.success(pagination.Page(items: items, hasNext: false));
  @override
  Future<Result<int>> getUnreadCount() async =>
      Result.success(unreadIds.length);
  @override
  Future<Result<int>> markAllAsRead() async {
    markAllCalls++;
    final count = unreadIds.length;
    unreadIds.clear();
    return Result.success(count);
  }

  @override
  Future<Result<void>> markAsRead({required String notificationId}) async {
    readIds.add(notificationId);
    unreadIds.remove(notificationId);
    return const Result.success(null);
  }
}

class _DeliveryApi implements PushDeliveryApi {
  _DeliveryApi(this.repository);
  final _Notifications repository;
  @override
  Future<Set<String>> dismissedIds(
    AuthSession session,
    List<String> ids,
  ) async => ids.where((id) => !repository.unreadIds.contains(id)).toSet();
}

class _Tray implements PushDeliveredProvider {
  final cards = {_notification, _otherNotification};
  final dismissed = <String>[];
  @override
  Future<PushDeliveredSnapshot?> deliveredSnapshot(String recipientId) async =>
      PushDeliveredSnapshot(
        recipientId: recipientId,
        bindingEpoch: _epoch,
        notificationIds: cards.toList(),
      );
  @override
  Future<void> dismissDelivered(
    PushDeliveredSnapshot snapshot,
    List<String> ids,
  ) async {
    dismissed.addAll(ids);
    cards.removeAll(ids);
  }
}

class _Realtime extends NotificationRealtimeClient {
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({required String userId, required String token}) async {}
  @override
  Future<void> disconnect() async {}
}

class _DmBadge extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _DmBadge() : super(const DmBadgeState.initial());
  @override
  Future<void> ensureStarted() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> reconcileAfterResume() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Uploads extends Fake implements ProfileMediaUploadRepository {
  @override
  Future<void> resumePendingUploads() async {}
}

class _Links implements AppLinkSource {
  @override
  Stream<Uri> get uriLinkStream => const Stream.empty();
}

class _NoTimer implements Timer {
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
  @override
  void cancel() {}
}

String _token() {
  String encode(Map<String, Object> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  // A supported authenticated role without an unrelated feed startup fetch.
  return '${encode({'alg': 'HS256'})}.${encode({
    'sub': _user,
    'roles': ['ROLE_PRODUCER'],
    'exp': DateTime.utc(2035).millisecondsSinceEpoch ~/ 1000,
  })}.signature';
}

class _StudioApi extends Fake implements ApiClient {
  _StudioApi(this.repository, this.fail, this.detailVisible);
  final _Notifications repository;
  final bool fail;
  final bool Function() detailVisible;
  final paths = <String>[];
  bool sawDetailAtAck = false;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    paths.add(path);
    expect(requestContext?.expectedSessionKey, _user);
    if (fail) throw StateError('fixture offline');
    if (method == ApiHttpMethod.post) {
      sawDetailAtAck = detailVisible();
      expect(path, '/api/v1/user/notifications/$_notification/read');
      await repository.markAsRead(notificationId: _notification);
      return null as T;
    }
    return decoder!({
      'notificationId': _notification,
      'recipientId': _user,
      'type': 'STUDIO_RESERVATION_APPROVED',
      'reservationId': _conversation,
      'roomId': _epoch,
      'studioProfileId': _otherNotification,
      'studioName': 'Current studio',
      'roomName': 'Current room',
      'ownerMode': false,
      'status': 'CONFIRMED',
      'roomArchived': false,
      'completed': true,
      'startsAt': '2026-09-24T08:00:00Z',
      'endsAt': '2026-09-24T09:00:00Z',
      'zoneId': 'Europe/Istanbul',
      'localDate': '2026-09-24',
      'localEndDate': '2026-09-24',
      'localStartTime': '11:00',
      'localEndTime': '12:00',
    });
  }
}

class _NativeStudioRooms extends Fake implements StudioRoomRepository {
  DateTime today = DateTime(2026, 9, 24);
  StudioReservationStatus status = StudioReservationStatus.confirmed;
  String reservationId = _conversation;
  Completer<Result<StudioRoom>>? roomPending;
  final roomIds = <String>[],
      customerDates = <DateTime>[],
      ownerDates = <DateTime>[];
  StudioRoom get room => StudioRoom(
    id: _epoch,
    studioProfileId: _otherNotification,
    slotIndex: 2,
    name: 'Current room',
    shortDescription: '',
    capacity: 3,
    hourlyPriceMinor: 10000,
    currency: 'TRY',
    reservationApprovalRequired: true,
    features: const [],
    photos: const [],
    todayLocalDate: today,
    todayReservationCount: 1,
    todayOccupiedHours: 1,
    todayAvailableHours: 13,
    todayAvailabilityStatus: StudioRoomAvailabilityStatus.partiallyAvailable,
    version: 1,
  );
  StudioReservation get reservation => StudioReservation(
    id: reservationId,
    clientRequestId: _conversation,
    roomId: _epoch,
    studioProfileId: _otherNotification,
    roomName: 'Current room',
    requesterId: _user,
    requesterUsername: 'Reservation customer',
    startsAt: DateTime.utc(2026, 9, 24, 8),
    endsAt: DateTime.utc(2026, 9, 24, 9),
    zoneId: 'Europe/Istanbul',
    status: status,
    completed: today.isAfter(DateTime(2026, 9, 24)),
    approvalRequired: true,
    hourlyPriceMinor: 10000,
    totalPriceMinor: 10000,
    currency: 'TRY',
    version: 1,
    localDate: '2026-09-24',
    localStartTime: '11:00',
    localEndTime: '12:00',
  );
  @override
  Future<Result<StudioRoom>> getOwnerRoom(String id) async {
    roomIds.add(id);
    return roomPending?.future ?? Result.success(room);
  }

  @override
  Future<Result<StudioRoom>> getPublicRoom(String profileId, String id) async {
    expect(profileId, _otherNotification);
    roomIds.add(id);
    return roomPending?.future ?? Result.success(room);
  }

  @override
  Future<Result<StudioRoomAvailability>> getPublicAvailability({
    required String studioProfileId,
    required String roomId,
    required DateTime from,
    required DateTime to,
  }) async => Result.success(
    StudioRoomAvailability(
      studioProfileId: studioProfileId,
      roomId: roomId,
      zoneId: 'Europe/Istanbul',
      openingHour: 9,
      closingHour: 23,
      todayLocalDate: today,
      currentLocalTime: '09:00',
      latestBookableLocalDateTime: today.add(const Duration(days: 365)),
      from: from,
      to: to,
      unavailable: const [],
    ),
  );
  @override
  Future<Result<StudioPage<StudioReservation>>>
  listCustomerReservationsForRoomDate({
    required String roomId,
    required DateTime date,
    int page = 0,
    int size = 100,
  }) async {
    expect(roomId, _epoch);
    customerDates.add(date);
    return Result.success(
      _page(date == DateTime(2026, 9, 24) ? [reservation] : []),
    );
  }

  @override
  Future<Result<StudioRoomSchedule>> getOwnerSchedule({
    required String roomId,
    required DateTime from,
    required DateTime to,
    int page = 0,
    int size = 100,
  }) async {
    expect(roomId, _epoch);
    ownerDates.add(from);
    return Result.success(
      StudioRoomSchedule(
        room: room,
        zoneId: 'Europe/Istanbul',
        todayLocalDate: today,
        currentLocalTime: '09:00',
        latestBookableLocalDateTime: today.add(const Duration(days: 365)),
        from: from,
        to: to,
        reservations: _page([reservation]),
        occupancies: const [],
      ),
    );
  }

  StudioPage<StudioReservation> _page(List<StudioReservation> items) =>
      StudioPage(
        items: items,
        pageIndex: 0,
        pageSize: 100,
        totalItems: items.length,
        totalPages: 1,
        isFirst: true,
        isLast: true,
      );
}
