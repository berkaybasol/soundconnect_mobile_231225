import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';

import 'support/event_audience_fakes.dart';

void main() {
  late AudienceTestSessions sessions;
  late _Repository repository;
  late _Realtime realtime;
  late NotificationCubit cubit;
  late GlobalKey<NavigatorState> navigator;
  late ValueNotifier<bool> ready;
  var reconciliations = 0;

  setUp(() async {
    sessions = AudienceTestSessions(audienceSession(user: 'account'));
    repository = _Repository();
    realtime = _Realtime();
    navigator = GlobalKey<NavigatorState>();
    ready = ValueNotifier(false);
    reconciliations = 0;
    cubit = NotificationCubit(
      repository,
      _Tokens(),
      sessions: sessions,
      realtimeClient: realtime,
      onDeliveryStateChanged: () async {
        reconciliations++;
      },
    );
    await cubit.ensureStarted();
  });

  tearDown(() async {
    ready.dispose();
    await cubit.close();
    await realtime.dispose();
    sessions.dispose();
  });

  NotificationTargetRead ticket() => NotificationTargetRead(
    notification: repository.items.first,
    cubit: cubit,
    sessions: sessions,
  );

  Future<void> mount(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [notificationTargetRouteObserver],
        home: const Scaffold(body: Text('Inbox')),
      ),
    );
  }

  Route<void> targetRoute({bool duplicateMarkers = false}) => _route(
    ValueListenableBuilder<bool>(
      valueListenable: ready,
      builder: (context, loaded, _) {
        final content = Text(loaded ? 'Exact target detail' : 'Loading target');
        return NotificationTargetReady(
          ready: loaded,
          child: Scaffold(
            body: duplicateMarkers
                ? NotificationTargetReady(ready: loaded, child: content)
                : content,
          ),
        );
      },
    ),
  );

  Future<void> open(
    WidgetTester tester, {
    NotificationTargetRead? withTicket,
    bool duplicateMarkers = false,
  }) async {
    final read = withTicket ?? ticket();
    final destination = targetRoute(duplicateMarkers: duplicateMarkers);
    expect(identical(read.attach(destination), destination), isTrue);
    unawaited(navigator.currentState!.push(destination));
    await tester.pump();
  }

  void expectUnread({int attempts = 0}) {
    expect(repository.readIds.length, attempts);
    expect(cubit.state.items.every((item) => !item.read), isTrue);
    expect(cubit.state.unreadCount, 2);
    expect(reconciliations, 0);
  }

  void expectOnlyTargetRead() {
    expect(repository.readIds, ['target']);
    expect(
      cubit.state.items.singleWhere((item) => item.id == 'target').read,
      isTrue,
    );
    expect(
      cubit.state.items.singleWhere((item) => item.id == 'sibling').read,
      isFalse,
    );
    expect(cubit.state.unreadCount, 1);
    expect(reconciliations, 1);
  }

  Future<void> openTerminal(WidgetTester tester, {bool acknowledge = true}) async {
    final content = Object();
    final read = NotificationTargetRead.content(
      notification: repository.items.first,
      cubit: cubit,
      sessions: sessions,
      repository: _Targets(repository),
      content: content,
    );
    unawaited(navigator.currentState!.push(read.attach(_route(
      ValueListenableBuilder<bool>(
        valueListenable: ready,
        builder: (context, loaded, _) => NotificationTerminalFeedback(
          message: 'Masa kapatıldı.',
          contentIdentity: content,
          acknowledge: acknowledge,
          ready: loaded,
          child: const Scaffold(body: Text('Gerçek ürün sayfası')),
        ),
      ),
    ))));
    await tester.pumpAndSettle();
  }

  testWidgets('queued terminal result is not read until its own message is painted', (tester) async {
    await mount(tester);
    await openTerminal(tester);
    final messenger = tester.state<ScaffoldMessengerState>(find.descendant(
      of: find.byType(NotificationTerminalFeedback),
      matching: find.byType(ScaffoldMessenger),
    ));
    messenger.showSnackBar(const SnackBar(content: Text('Önceki mesaj'), persist: true));
    await tester.pumpAndSettle();
    ready.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Önceki mesaj'), findsOneWidget);
    expect(find.text('Masa kapatıldı.'), findsNothing);
    expectUnread();
    messenger.removeCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.text('Masa kapatıldı.'), findsOneWidget);
    expectOnlyTargetRead();
  });

  testWidgets('covered terminal result and generic fallback never acknowledge', (tester) async {
    await mount(tester);
    await openTerminal(tester);
    unawaited(navigator.currentState!.push(_route(const Scaffold(body: Text('Cover')))));
    await tester.pumpAndSettle();
    ready.value = true;
    await tester.pumpAndSettle();
    expectUnread();
    navigator.currentState!.pop();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await openTerminal(tester, acknowledge: false);
    expect(find.text('Masa kapatıldı.'), findsOneWidget);
    expectUnread();
  });

  testWidgets('terminal ACK retry keeps product page and only retries exact ACK', (tester) async {
    repository.failRead = true;
    await mount(tester);
    ready.value = true;
    await openTerminal(tester);
    expectUnread(attempts: 1);
    expect(find.text('Gerçek ürün sayfası'), findsOneWidget);
    expect(find.text('Okundu bilgisi kaydedilemedi.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('Tekrar dene'), findsOneWidget);
    expectUnread(attempts: 1);
    repository.failRead = false;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(repository.readIds, ['target', 'target']);
    expect(cubit.state.unreadCount, 1);
    expect(cubit.state.items.singleWhere((e) => e.id == 'sibling').read, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
  });

  for (final hidden in ['background', 'covered']) {
    testWidgets('terminal entrance interrupted by $hidden is shown on return before ACK', (tester) async {
      await mount(tester);
      await openTerminal(tester);
      ready.value = true;
      // Build and start the snackbar, without letting its entrance finish.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).animation?.status,
          isNot(AnimationStatus.completed));
      expectUnread();
      if (hidden == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else {
        unawaited(navigator.currentState!.push(_route(
          const Scaffold(body: Text('Cover during entrance')),
        )));
      }
      await tester.pumpAndSettle();
      expectUnread();
      if (hidden == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      } else {
        navigator.currentState!.pop();
      }
      await tester.pumpAndSettle();
      expect(find.text('Gerçek ürün sayfası'), findsOneWidget);
      expect(find.text('Masa kapatıldı.'), findsOneWidget);
      expectOnlyTargetRead();
    });
  }

  testWidgets('terminal result queued before account change remains unread', (tester) async {
    await mount(tester);
    await openTerminal(tester);
    await tester.runAsync(() async {
      sessions.replace(audienceSession(user: 'other', token: 'new-token'));
      await cubit.stop();
    });
    ready.value = true;
    await tester.pumpAndSettle();
    expect(repository.readIds, isEmpty);
    expect(find.text('Masa kapatıldı.'), findsNothing);
  });

  testWidgets('loading and target errors never acknowledge an unread target', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    expect(find.text('Loading target'), findsOneWidget);
    expectUnread();
    await tester.pump(const Duration(seconds: 2));
    expectUnread();

    // A failed lookup never adds a ready marker, even if its error UI is visible.
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    unawaited(
      navigator.currentState!.push(
        ticket().attach(
          _route(
            const NotificationTargetReady(
              ready: false,
              child: Scaffold(body: Text('Target unavailable. Retry')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Target unavailable. Retry'), findsOneWidget);
    expectUnread();
  });

  testWidgets('first ready frame acknowledges only its target and reconciles', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    expectUnread();
    ready.value = true;
    expectUnread();
    await tester.pump();
    expect(find.text('Exact target detail'), findsOneWidget);
    expectOnlyTargetRead();
  });

  testWidgets('a ready screen without an attached ticket cannot acknowledge', (
    tester,
  ) async {
    await mount(tester);
    ready.value = true;
    unawaited(navigator.currentState!.push(targetRoute()));
    await tester.pumpAndSettle();
    expect(find.text('Exact target detail'), findsOneWidget);
    expectUnread();
  });

  testWidgets('ready content waits until its entry transition completes', (
    tester,
  ) async {
    await mount(tester);
    unawaited(
      navigator.currentState!.push(
        ticket().attach(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (context, animation, secondaryAnimation) =>
                const NotificationTargetReady(
                  child: Scaffold(body: Text('Animated target')),
                ),
          ),
        ),
      ),
    );
    await tester.pump();
    expectUnread();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Animated target'), findsOneWidget);
    expectUnread();
    await tester.pumpAndSettle();
    expectOnlyTargetRead();
  });

  testWidgets('an unrelated recipient cannot attach a read ticket', (
    tester,
  ) async {
    await mount(tester);
    final read = NotificationTargetRead(
      notification: _item('target', recipient: 'other'),
      cubit: cubit,
      sessions: sessions,
    );
    ready.value = true;
    await open(tester, withTicket: read);
    expect(read.isCurrent, isFalse);
    expectUnread();
  });

  testWidgets('pending ACK leaves detail usable and local rows unread', (
    tester,
  ) async {
    repository.pendingRead = Completer<Result<void>>();
    await mount(tester);
    ready.value = true;
    await open(tester);
    expect(find.text('Exact target detail'), findsOneWidget);
    expectUnread(attempts: 1);
    await tester.pump(const Duration(seconds: 10));
    expectUnread(attempts: 1);
    repository.pendingRead!.complete(const Result.success(null));
    await tester.pump();
    expectOnlyTargetRead();
  });

  testWidgets(
    'failed ACK keeps detail and unread state without implicit retry',
    (tester) async {
      repository.failRead = true;
      await mount(tester);
      ready.value = true;
      await open(tester, duplicateMarkers: true);
      expect(find.text('Exact target detail'), findsOneWidget);
      expectUnread(attempts: 1);
      expect(cubit.state.errorMessage, 'ACK unavailable');
      ready.value = false;
      await tester.pump();
      ready.value = true;
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expectUnread(attempts: 1);
    },
  );

  testWidgets('covered target waits until its own route is visible again', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    unawaited(
      navigator.currentState!.push(_route(const Scaffold(body: Text('Cover')))),
    );
    await tester.pumpAndSettle();
    ready.value = true;
    await tester.pump();
    expect(find.text('Cover'), findsOneWidget);
    expectUnread();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Exact target detail'), findsOneWidget);
    expectOnlyTargetRead();
  });

  testWidgets('background target waits for foreground before acknowledgement', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    ready.value = true;
    await tester.pump();
    expectUnread();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expectOnlyTargetRead();
  });

  for (final replacement in ['logout', 'account', 'token']) {
    testWidgets('$replacement change invalidates a pending target ticket', (
      tester,
    ) async {
      await mount(tester);
      final read = ticket();
      await open(tester, withTicket: read);
      // Session restart cancels streams created in setUp's real async zone.
      // Keep that cancellation there so fake-async teardown cannot strand it.
      await tester.runAsync(() async {
        sessions.replace(switch (replacement) {
          'logout' => const AuthSession.guest(),
          'account' => audienceSession(user: 'other', token: 'other-token'),
          _ => audienceSession(user: 'account', token: 'refreshed-token'),
        });
        await cubit.stop();
      });
      ready.value = true;
      await tester.pump();
      expect(read.isCurrent, isFalse);
      expect(repository.readIds, isEmpty);
      expect(reconciliations, 0);
    });
  }

  testWidgets('late ACK after session replacement cannot read or reconcile', (
    tester,
  ) async {
    repository.pendingRead = Completer<Result<void>>();
    await mount(tester);
    ready.value = true;
    await open(tester);
    expectUnread(attempts: 1);
    await tester.runAsync(() async {
      sessions.replace(const AuthSession.guest());
      await cubit.stop();
    });
    repository.pendingRead!.complete(const Result.success(null));
    await tester.pump();
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.unreadCount, 0);
    expect(reconciliations, 0);
  });

  testWidgets('a popped target cannot acknowledge when its lookup completes', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    ready.value = true;
    await tester.pump();
    expect(find.text('Inbox'), findsOneWidget);
    expectUnread();
  });

  testWidgets('duplicate markers rebuilds and resumes make only one ACK', (
    tester,
  ) async {
    await mount(tester);
    ready.value = true;
    await open(tester, duplicateMarkers: true);
    expectOnlyTargetRead();
    ready.value = false;
    await tester.pump();
    ready.value = true;
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expectOnlyTargetRead();
  });

  testWidgets('transfer moves the ticket from routing screen to final detail', (
    tester,
  ) async {
    await mount(tester);
    final finalReady = ValueNotifier(false);
    addTearDown(finalReady.dispose);
    late BuildContext routingContext;
    unawaited(
      navigator.currentState!.push(
        ticket().attach(
          _route(
            Builder(
              builder: (context) {
                routingContext = context;
                return ValueListenableBuilder<bool>(
                  valueListenable: ready,
                  builder: (context, loaded, _) => NotificationTargetReady(
                    ready: loaded,
                    child: const Scaffold(body: Text('Routing screen')),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final destination = _route(
      ValueListenableBuilder<bool>(
        valueListenable: finalReady,
        builder: (context, loaded, _) => NotificationTargetReady(
          ready: loaded,
          child: Scaffold(
            body: Text(loaded ? 'Final detail' : 'Final loading'),
          ),
        ),
      ),
    );
    expect(
      identical(
        NotificationTargetRead.transfer(routingContext, destination),
        destination,
      ),
      isTrue,
    );
    unawaited(navigator.currentState!.push(destination));
    ready.value = true;
    await tester.pumpAndSettle();
    expectUnread();
    finalReady.value = true;
    await tester.pump();
    expect(find.text('Final detail'), findsOneWidget);
    expectOnlyTargetRead();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Routing screen'), findsOneWidget);
    expectOnlyTargetRead();
  });
}

Route<void> _route(Widget child) => PageRouteBuilder<void>(
  transitionDuration: Duration.zero,
  reverseTransitionDuration: Duration.zero,
  pageBuilder: (context, animation, secondaryAnimation) => child,
);

AppNotification _item(String id, {String recipient = 'account'}) =>
    AppNotification(
      id: id,
      recipientId: recipient,
      type: 'SOCIAL_NEW_FOLLOWER',
      title: 'Fixture',
      message: 'Fixture',
      read: false,
      createdAt: DateTime.utc(2026, 9, 27),
      payload: const {},
    );

class _Repository extends Fake implements NotificationRepository {
  List<AppNotification> items = [_item('target'), _item('sibling')];
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

class _Targets extends Fake implements NotificationTargetRepository {
  _Targets(this.inbox);
  final _Repository inbox;
  @override
  Future<Result<void>> acknowledge(AppNotification notification, AuthSession session) =>
      inbox.markAsRead(notificationId: notification.id);
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
