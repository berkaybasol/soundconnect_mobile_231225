import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_direct_open.dart';
import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_conversation_preview.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/screens/dm_chat_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/screens/dm_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';

import 'support/event_audience_fakes.dart';

const _user = '70000000-0000-4000-8000-000000000001';
const _otherUser = '70000000-0000-4000-8000-000000000002';
const _conversation = '60000000-0000-4000-8000-000000000001';
const _notification = '50000000-0000-4000-8000-000000000001';
const _socialSibling = '50000000-0000-4000-8000-000000000002';
const _eventSibling = '50000000-0000-4000-8000-000000000003';
const _backendDetail = 'private server diagnostic must never be rendered';

void main() {
  late _Fixture f;

  setUp(() async {
    await serviceLocator.reset();
    f = _Fixture();
  });
  tearDown(() async {
    await f.dispose();
    await serviceLocator.reset();
  });

  for (final failure in [
    'failure',
    'exception',
    'null-preview',
    'different-conversation',
    'empty-other-user',
  ]) {
    testWidgets(
      '$failure preserves DM and sibling unread rows without inbox fallback',
      (tester) async {
        f.dm.onPreview = () async => switch (failure) {
          'failure' => const Result.failure(
            AppError(code: 'OFFLINE', message: _backendDetail),
          ),
          'exception' => throw StateError(_backendDetail),
          'null-preview' => const Result.success(null),
          'different-conversation' => Result.success(
            _preview(conversation: '60000000-0000-4000-8000-000000000002'),
          ),
          'empty-other-user' => Result.success(_preview(otherUser: '  ')),
          _ => throw StateError('Unexpected fixture'),
        };
        await f.mount(tester);
        await tester.pumpAndSettle();

        expect(f.dm.previewIds, [_conversation]);
        expect(
          find.byType(DmNotificationOpenScreen, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('Tekrar dene'), findsOneWidget);
        expect(find.textContaining(_backendDetail), findsNothing);
        f.expectNoNavigationOrMutations(tester);
        f.expectVisibleUnreadRows();
      },
    );
  }

  testWidgets(
    'retry replaces only the opener with current chat arguments and no eager reads',
    (tester) async {
      f.dm.onPreview = () async => const Result.failure(
        AppError(code: 'OFFLINE', message: _backendDetail),
      );
      await f.mount(tester);
      await tester.pumpAndSettle();
      final pending = Completer<Result<DmConversationPreview>>();
      f.dm.onPreview = () => pending.future;

      // Two taps before the next frame must still dispatch one retry request.
      await tester.tap(find.text('Tekrar dene'));
      await tester.tap(find.text('Tekrar dene'));
      await tester.pump();
      expect(f.dm.previewIds, [_conversation, _conversation]);
      f.expectNoNavigationOrMutations(tester);
      pending.complete(Result.success(_preview()));
      await tester.pumpAndSettle();

      expect(f.destinationRequests.map((route) => route.name), [
        AppRoutes.dmChat,
      ]);
      final args = f.destinationRequests.single.arguments! as DmChatScreenArgs;
      expect(args.conversationId, _conversation);
      expect(args.currentUserId, _user);
      expect(args.otherUserId, _otherUser);
      expect(args.otherUsername, 'Fresh counterpart');
      expect(
        args.otherUserProfilePicture,
        'https://example.test/current-avatar.png',
      );
      expect(args.otherUserVisibilityMode, ListenerVisibilityMode.ghost);
      expect(f.observer.replacements, isEmpty);
      expect(
        find.byType(DmNotificationOpenScreen, skipOffstage: false),
        findsNothing,
      );
      f.expectNoMutations();
      f.expectVisibleUnreadRows();

      f.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Original screen'), findsOneWidget);
      expect(
        find.byType(DmNotificationOpenScreen, skipOffstage: false),
        findsNothing,
      );
    },
  );

  for (final change in [
    'logout',
    'account',
    'token',
    'inactive',
    'onboarding',
  ]) {
    testWidgets('late preview after $change cannot navigate or read any row', (
      tester,
    ) async {
      final pending = Completer<Result<DmConversationPreview>>();
      f.dm.onPreview = () => pending.future;
      await f.mount(tester);
      await tester.pump();
      expect(f.dm.previewIds, [_conversation]);
      f.sessions.replace(switch (change) {
        'logout' => const AuthSession.guest(),
        'account' => audienceSession(user: _otherUser, role: 'ROLE_MUSICIAN'),
        'token' => audienceSession(
          user: _user,
          token: 'replacement',
          role: 'ROLE_MUSICIAN',
        ),
        'inactive' => audienceSession(
          user: _user,
          status: 'INACTIVE',
          role: 'ROLE_MUSICIAN',
        ),
        'onboarding' => _onboardingSession(),
        _ => throw StateError('Unexpected fixture'),
      });
      pending.complete(Result.success(_preview()));
      await tester.pumpAndSettle();
      f.expectNoNavigationOrMutations(tester);
    });
  }

  testWidgets('late preview after back cannot reopen the disposed route', (
    tester,
  ) async {
    final pending = Completer<Result<DmConversationPreview>>();
    f.dm.onPreview = () => pending.future;
    await f.mount(tester);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    pending.complete(Result.success(_preview()));
    await tester.pumpAndSettle();
    expect(
      find.byType(DmNotificationOpenScreen, skipOffstage: false),
      findsNothing,
    );
    f.expectNoNavigationOrMutations(tester);
    f.expectVisibleUnreadRows();
  });

  testWidgets(
    'covered opener does not redirect and offers a fresh manual retry',
    (tester) async {
      final pending = Completer<Result<DmConversationPreview>>();
      f.dm.onPreview = () => pending.future;
      await f.mount(tester);
      await tester.pump();
      unawaited(
        f.navigator.currentState!.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Cover')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      pending.complete(Result.success(_preview()));
      await tester.pumpAndSettle();
      expect(find.text('Cover'), findsOneWidget);
      f.expectNoNavigationOrMutations(tester);

      f.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(f.dm.previewIds, [_conversation]);
      f.dm.onPreview = () async => Result.success(_preview());
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(f.destinationRequests.single.name, AppRoutes.dmChat);
      expect(f.dm.previewIds, [_conversation, _conversation]);
      f.expectNoMutations();
    },
  );

  testWidgets(
    'preview completed while paused waits for an explicit retry on resume',
    (tester) async {
      final pending = Completer<Result<DmConversationPreview>>();
      f.dm.onPreview = () => pending.future;
      await f.mount(tester);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      pending.complete(Result.success(_preview()));
      await tester.pump();
      f.expectNoNavigationOrMutations(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(f.dm.previewIds, [_conversation]);
      f.dm.onPreview = () async => Result.success(_preview());
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(f.destinationRequests.single.name, AppRoutes.dmChat);
      f.expectNoMutations();
    },
  );

  testWidgets(
    'initial inactive mount defers the first lookup until one resume',
    (tester) async {
      final pending = Completer<Result<DmConversationPreview>>();
      f.dm.onPreview = () => pending.future;
      await f.mount(tester, lifecycle: AppLifecycleState.inactive);
      await tester.pump();
      expect(f.dm.previewIds, isEmpty);
      f.expectNoNavigationOrMutations(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(f.dm.previewIds, [_conversation]);
      pending.complete(Result.success(_preview()));
      await tester.pumpAndSettle();
      expect(f.destinationRequests.single.name, AppRoutes.dmChat);
      f.expectNoMutations();
    },
  );

  for (final invalid in [
    'wrong-recipient',
    'missing-conversation',
    'blank-conversation',
    'missing-notification',
    'wrong-type',
    'guest',
    'inactive',
    'onboarding',
  ]) {
    testWidgets('$invalid is rejected before a private conversation lookup', (
      tester,
    ) async {
      if (invalid == 'guest') f.sessions.current = const AuthSession.guest();
      if (invalid == 'inactive') {
        f.sessions.current = audienceSession(user: _user, status: 'INACTIVE');
      }
      if (invalid == 'onboarding') f.sessions.current = _onboardingSession();
      await f.mount(
        tester,
        target: PushTarget(
          notificationId: invalid == 'missing-notification'
              ? ''
              : _notification,
          recipientId: invalid == 'wrong-recipient' ? _otherUser : _user,
          type: invalid == 'wrong-type'
              ? 'SOCIAL_NEW_FOLLOWER'
              : 'DM_NEW_MESSAGE',
          conversationId: switch (invalid) {
            'missing-conversation' => null,
            'blank-conversation' => '  ',
            _ => _conversation,
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(f.dm.previewIds, isEmpty);
      f.expectNoNavigationOrMutations(tester);
    });
  }
}

class _Fixture {
  final sessions = AudienceTestSessions(
    audienceSession(user: _user, role: 'ROLE_MUSICIAN'),
  );
  final dm = _DmRepository();
  final notifications = _Notifications();
  final realtime = _Realtime();
  final navigator = GlobalKey<NavigatorState>();
  final observer = _NavigationObserver();
  final destinationRequests = <RouteSettings>[];
  int deliveryReconciliations = 0;
  late final cubit = NotificationCubit(
    notifications,
    _Tokens(),
    sessions: sessions,
    realtimeClient: realtime,
    onDeliveryStateChanged: () async => deliveryReconciliations++,
  );
  bool disposed = false;

  Future<void> mount(
    WidgetTester tester, {
    PushTarget target = const PushTarget(
      notificationId: _notification,
      recipientId: _user,
      type: 'DM_NEW_MESSAGE',
      conversationId: _conversation,
    ),
    AppLifecycleState lifecycle = AppLifecycleState.resumed,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(lifecycle);
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    serviceLocator.registerSingleton<DmRepository>(dm);
    serviceLocator.registerSingleton<NotificationCubit>(cubit);
    await cubit.ensureStarted();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer, notificationTargetRouteObserver],
        home: const Scaffold(body: Text('Original screen')),
        onGenerateRoute: (settings) {
          destinationRequests.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                Scaffold(body: Text('Destination ${settings.name}')),
          );
        },
      ),
    );
    unawaited(
      NotificationDirectOpen.start(
        navigator.currentContext!,
        identity: target.notificationId,
        builder: (_) => DmNotificationOpenScreen(target: target),
      ),
    );
    await tester.pump();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await dispose();
    });
  }

  void expectNoMutations() {
    expect(notifications.mutations, isEmpty);
    expect(notifications.items.map((row) => row.id), [
      _notification,
      _socialSibling,
      _eventSibling,
    ]);
    expect(notifications.items.every((row) => !row.read), isTrue);
    expect(dm.readMessageIds, isEmpty);
    expect(deliveryReconciliations, 0);
  }

  void expectVisibleUnreadRows() {
    expect(cubit.state.unreadCount, 3);
    expect(cubit.state.items.map((row) => row.id), [
      _notification,
      _socialSibling,
      _eventSibling,
    ]);
    expect(cubit.state.items.every((row) => !row.read), isTrue);
  }

  void expectNoNavigationOrMutations(WidgetTester tester) {
    expect(destinationRequests, isEmpty);
    expect(observer.replacements, isEmpty);
    expect(find.byType(NotificationScreen), findsNothing);
    expect(find.byType(DmChatScreen), findsNothing);
    expect(tester.takeException(), isNull);
    expectNoMutations();
  }

  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await cubit.close();
    await realtime.dispose();
    sessions.dispose();
  }
}

class _DmRepository extends Fake implements DmRepository {
  final previewIds = <String>[];
  final readMessageIds = <String>[];
  Future<Result<DmConversationPreview>> Function()? onPreview;

  @override
  Future<Result<DmConversationPreview>> getConversationPreview({
    required String conversationId,
  }) {
    previewIds.add(conversationId);
    return onPreview?.call() ?? Future.value(Result.success(_preview()));
  }

  @override
  Future<Result<void>> markMessageAsRead({required String messageId}) async {
    readMessageIds.add(messageId);
    return const Result.success(null);
  }
}

class _Notifications extends Fake implements NotificationRepository {
  final mutations = <String>[];
  List<AppNotification> items = [
    _row(_notification, 'DM_NEW_MESSAGE'),
    _row(_socialSibling, 'SOCIAL_NEW_FOLLOWER'),
    _row(_eventSibling, 'EVENT_PERFORMER_APPROVAL_REQUESTED'),
  ];

  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async => Result.success(Page(items: List.of(items), hasNext: false));

  @override
  Future<Result<int>> getUnreadCount() async =>
      Result.success(items.where((row) => !row.read).length);

  @override
  Future<Result<void>> markAsRead({required String notificationId}) async {
    mutations.add('read:$notificationId');
    items = [
      for (final row in items)
        if (row.id == notificationId) row.copyWith(read: true) else row,
    ];
    return const Result.success(null);
  }

  @override
  Future<Result<int>> markAllAsRead() async {
    mutations.add('read-all');
    final count = items.where((row) => !row.read).length;
    items = [for (final row in items) row.copyWith(read: true)];
    return Result.success(count);
  }

  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async {
    mutations.add('delete:$notificationId');
    items.removeWhere((row) => row.id == notificationId);
    return const Result.success(null);
  }

  @override
  Future<Result<int>> clearAllNotifications() async {
    mutations.add('clear-all');
    final count = items.length;
    items.clear();
    return Result.success(count);
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

class _NavigationObserver extends NavigatorObserver {
  final replacements = <({String? oldName, String? newName})>[];
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacements.add((
      oldName: oldRoute?.settings.name,
      newName: newRoute?.settings.name,
    ));
  }
}

DmConversationPreview _preview({
  String conversation = _conversation,
  String otherUser = _otherUser,
}) => DmConversationPreview(
  conversationId: conversation,
  otherUserId: otherUser,
  otherUsername: 'Fresh counterpart',
  otherUserProfilePicture: 'https://example.test/current-avatar.png',
  lastMessageContent: 'Private message stays in the conversation',
  lastMessageType: 'text',
  lastMessageSenderId: _otherUser,
  lastMessageAt: DateTime.utc(2026, 9, 24),
  lastMessageRead: false,
  otherUserVisibilityMode: ListenerVisibilityMode.ghost,
);

AppNotification _row(String id, String type) => AppNotification(
  id: id,
  recipientId: _user,
  type: type,
  title: 'Unread fixture',
  message: '',
  read: false,
  createdAt: DateTime.utc(2026, 9, 24),
  payload: const {},
);

AuthSession _onboardingSession() => AuthSession.authenticated(
  token: 'token',
  userId: _user,
  username: 'current user',
  accountStatus: 'ACTIVE',
  roles: const ['ROLE_LISTENER'],
  permissions: const [],
  expiresAt: DateTime.utc(2100),
  isAdmin: false,
  requiresListenerProfileChoice: true,
);
