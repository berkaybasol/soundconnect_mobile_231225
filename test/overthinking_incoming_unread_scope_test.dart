import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_incoming_unread_status.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_incoming_unread_binding.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_incoming_unread_scope.dart';

import 'support/event_audience_fakes.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async => serviceLocator.reset());
  tearDown(() async => serviceLocator.reset());

  test(
    'profile without Overthinking repository has no scope or background read',
    () {
      expect(findOverthinkingIncomingUnreadScope(), isNull);
      expect(findOverthinkingIncomingUnreadScope(), isNull);
      expect(
        serviceLocator.isRegistered<OverthinkingIncomingUnreadScope>(),
        isFalse,
      );
    },
  );

  test(
    'all entry points share one read and synchronously clear the same state',
    () async {
      final repository = _Inbox();
      serviceLocator.registerSingleton<OverthinkingRepository>(repository);
      final firstRead = Completer<Result<OverthinkingIncomingUnreadStatus>>();
      repository.onRead = (_) => repository.reads.length == 1
          ? firstRead.future
          : Future.value(repository.status());
      final profile = findOverthinkingIncomingUnreadScope()!;
      final launcher = findOverthinkingIncomingUnreadScope()!;
      final feed = requireOverthinkingIncomingUnreadScope();
      for (var i = 0; i < 20; ++i) {
        expect(findOverthinkingIncomingUnreadScope(), same(profile));
      }
      expect(profile, same(launcher));
      expect(profile, same(feed));
      expect(repository.reads, hasLength(1));
      firstRead.complete(repository.status());
      await profile.ensureStarted();
      await _flush();
      expect(profile.state, isTrue);
      final marked = feed.markSeen();
      expect(profile.state, isFalse);
      expect(launcher.state, isFalse);
      await marked;
      expect(repository.seen, [('test', 5)]);
      final reads = repository.reads.length;
      expect(findOverthinkingIncomingUnreadScope(), same(profile));
      await _flush();
      expect(repository.reads, hasLength(reads));
      await serviceLocator.reset();
      expect(profile.isClosed, isTrue);
    },
  );

  test(
    'disposing one entry-point subscription leaves the shared signal alive',
    () async {
      final repository = _Inbox();
      final incoming = StreamController<AppNotification>.broadcast(sync: true);
      final scope = OverthinkingIncomingUnreadScope(
        repository,
        notifications: incoming.stream,
      );
      final profileStates = <bool?>[];
      final profile = scope.stream.listen(profileStates.add);
      final feed = scope.stream.listen((_) {});
      addTearDown(() async {
        await profile.cancel();
        await scope.close();
        await incoming.close();
      });
      await scope.ensureStarted();
      await scope.markSeen();
      await _flush();
      await feed.cancel();
      expect(scope.isClosed, isFalse);
      repository.values['test'] = _value(true, 6);
      incoming.add(_notification());
      await _flush();
      expect(scope.state, isTrue);
      expect(profileStates.last, isTrue);
    },
  );

  test(
    'old replay on another screen stays seen and real new server revision reopens it',
    () async {
      final repository = _Inbox()..values['test'] = _value(false, 5);
      final incoming = StreamController<AppNotification>.broadcast(sync: true);
      final scope = OverthinkingIncomingUnreadScope(
        repository,
        notifications: incoming.stream,
      );
      addTearDown(() async {
        await scope.close();
        await incoming.close();
      });
      await scope.ensureStarted();
      await _flush();
      final values = <bool?>[];
      final listener = scope.stream.listen(values.add);
      addTearDown(listener.cancel);
      incoming.add(_notification());
      await _flush();
      expect(scope.state, isFalse);
      expect(values, isNot(contains(true)));
      repository.values['test'] = _value(true, 6);
      incoming.add(_notification());
      expect(scope.state, isFalse);
      await _flush();
      expect(scope.state, isTrue);
    },
  );

  test(
    'notification badge invalidates a cancelled request even during a pending read',
    () async {
      final repository = _Inbox()..values['test'] = _value(false, 5);
      final badges = StreamController<int>.broadcast(sync: true);
      final scope = OverthinkingIncomingUnreadScope(
        repository,
        invalidations: badges.stream.map<void>((_) {}),
      );
      addTearDown(() async {
        await scope.close();
        await badges.close();
      });
      await scope.ensureStarted();
      badges.add(8);
      await _flush();
      expect(scope.state, isFalse);
      repository.values['test'] = _value(true, 6);
      badges.add(0);
      await _flush();
      expect(scope.state, isTrue);
      final oldRead = Completer<Result<OverthinkingIncomingUnreadStatus>>();
      repository.onRead = (_) => oldRead.future;
      final refreshing = scope.refresh();
      repository.values['test'] = _value(false, 6);
      repository.onRead = null;
      badges.add(0);
      oldRead.complete(_status(true, 6));
      await refreshing;
      await _flush();
      expect(scope.state, isFalse);
      expect(repository.seen, isEmpty);
      await scope.close();
      expect(badges.hasListener, isFalse);
    },
  );

  test(
    'application resume and reconnect refresh without duplicate icon reads',
    () async {
      final repository = _Inbox()..values['test'] = _value(false, 5);
      final connections = StreamController<void>.broadcast(sync: true);
      final scope = OverthinkingIncomingUnreadScope(
        repository,
        reconnections: connections.stream,
      );
      addTearDown(() async {
        await scope.close();
        await connections.close();
      });
      await scope.ensureStarted();
      final resumed = Completer<Result<OverthinkingIncomingUnreadStatus>>();
      repository.onRead = (_) => repository.reads.length == 2
          ? resumed.future
          : Future.value(repository.status());
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final pageRefresh = scope.refresh();
      expect(repository.reads, hasLength(2));
      resumed.complete(_status(true, 6));
      await pageRefresh;
      await _flush();
      expect(scope.state, isTrue);
      repository.values['test'] = _value(false, 6);
      connections.add(null);
      await _flush();
      expect(scope.state, isFalse);
    },
  );

  for (final user in ['author', 'other']) {
    test(
      'new session $user loads immediately while the previous GET is pending',
      () async {
        final sessions = AudienceTestSessions(
          audienceSession(user: 'author', token: 'old'),
        );
        final repository = _Inbox(sessions: sessions)
          ..values['new'] = _value(false, 6);
        final old = Completer<Result<OverthinkingIncomingUnreadStatus>>();
        repository.onRead = (token) => token == 'old'
            ? old.future
            : Future.value(repository.status(token));
        final scope = OverthinkingIncomingUnreadScope(
          repository,
          sessions: sessions,
        );
        addTearDown(() async {
          await scope.close();
          sessions.dispose();
        });
        final loading = scope.ensureStarted();
        sessions.replace(const AuthSession.guest());
        expect(scope.state, isNull);
        expect(repository.reads, ['old']);
        sessions.replace(audienceSession(user: user, token: 'new'));
        await _flush();
        expect(scope.state, isFalse);
        expect(repository.reads, ['old', 'new']);
        old.complete(_status(true, 5));
        await loading;
        await _flush();
        expect(scope.state, isFalse);
      },
    );

    test(
      'new session $user cannot inherit the previous seen POST result',
      () async {
        final sessions = AudienceTestSessions(
          audienceSession(user: 'author', token: 'old'),
        );
        final repository = _Inbox(sessions: sessions)
          ..values['new'] = _value(true, 6);
        final old = Completer<Result<OverthinkingIncomingUnreadStatus>>();
        repository.onSeen = (token, revision) => token == 'old'
            ? old.future
            : Future.value(repository.acknowledge(token, revision));
        final scope = OverthinkingIncomingUnreadScope(
          repository,
          sessions: sessions,
        );
        addTearDown(() async {
          await scope.close();
          sessions.dispose();
        });
        await scope.ensureStarted();
        final marking = scope.markSeen();
        expect(scope.state, isFalse);
        await _flush();
        expect(repository.seen, [('old', 5)]);
        sessions.replace(audienceSession(user: user, token: 'new'));
        expect(scope.state, isNull);
        await _flush();
        expect(scope.state, isTrue);
        old.complete(_status(false, 5));
        await marking;
        await _flush();
        expect(scope.state, isTrue);
        await scope.markSeen();
        await _flush();
        expect(scope.state, isFalse);
        expect(repository.seen, [('old', 5), ('new', 6)]);
      },
    );
  }

  test(
    'guest and inactive sessions perform no reads or acknowledgements',
    () async {
      final sessions = AudienceTestSessions(const AuthSession.guest());
      final repository = _Inbox(sessions: sessions);
      final scope = OverthinkingIncomingUnreadScope(
        repository,
        sessions: sessions,
      );
      addTearDown(() async {
        await scope.close();
        sessions.dispose();
      });
      await scope.ensureStarted();
      await scope.markSeen();
      sessions.replace(
        audienceSession(user: 'author', token: 'inactive', status: 'SUSPENDED'),
      );
      await scope.refresh();
      await scope.markSeen();
      expect(repository.reads, isEmpty);
      expect(repository.seen, isEmpty);
      sessions.replace(audienceSession(user: 'author', token: 'active'));
      await _flush();
      expect(repository.reads, ['active']);
      expect(scope.state, isTrue);
      sessions.replace(const AuthSession.guest());
      expect(scope.state, isNull);
    },
  );

  test(
    'closing scope removes session realtime and lifecycle subscriptions',
    () async {
      final sessions = AudienceTestSessions(
        audienceSession(user: 'author', token: 'old'),
      );
      final repository = _Inbox(sessions: sessions);
      final notifications = StreamController<AppNotification>.broadcast(
        sync: true,
      );
      final scope = OverthinkingIncomingUnreadScope(
        repository,
        sessions: sessions,
        notifications: notifications.stream,
      );
      await scope.ensureStarted();
      await scope.close();
      await scope.close();
      sessions.replace(audienceSession(user: 'other', token: 'new'));
      notifications.add(_notification(recipient: 'other'));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await scope.ensureStarted();
      await scope.markSeen();
      await _flush();
      expect(repository.reads, ['old']);
      expect(repository.seen, isEmpty);
      sessions.dispose();
      await notifications.close();
    },
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

OverthinkingIncomingUnreadStatus _value(bool unread, int revision) =>
    OverthinkingIncomingUnreadStatus(hasUnread: unread, revision: revision);

Result<OverthinkingIncomingUnreadStatus> _status(bool unread, int revision) =>
    Result.success(_value(unread, revision));

class _Inbox extends Fake implements OverthinkingRepository {
  _Inbox({this.sessions});
  final AuthSessionManager? sessions;
  final reads = <String>[];
  final seen = <(String, int)>[];
  final values = <String, OverthinkingIncomingUnreadStatus>{};
  Future<Result<OverthinkingIncomingUnreadStatus>> Function(String)? onRead;
  Future<Result<OverthinkingIncomingUnreadStatus>> Function(String, int)?
  onSeen;
  String get token => sessions?.session.token ?? 'test';

  Result<OverthinkingIncomingUnreadStatus> status([String? forToken]) =>
      Result.success(values[forToken ?? token] ?? _value(true, 5));

  Result<OverthinkingIncomingUnreadStatus> acknowledge(
    String token,
    int revision,
  ) {
    final current = status(token).data!;
    values[token] = _value(current.revision > revision, current.revision);
    return status(token);
  }

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>> getIncomingUnreadStatus() {
    final currentToken = token;
    reads.add(currentToken);
    return onRead?.call(currentToken) ?? Future.value(status(currentToken));
  }

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>> markIncomingRequestsSeen({
    required int revision,
  }) {
    final currentToken = token;
    seen.add((currentToken, revision));
    return onSeen?.call(currentToken, revision) ??
        Future.value(acknowledge(currentToken, revision));
  }
}

AppNotification _notification({String recipient = 'author'}) => AppNotification(
  id: 'notification',
  recipientId: recipient,
  type: 'OVERTHINKING_REVEAL_REQUEST_RECEIVED',
  title: '',
  message: '',
  read: false,
  createdAt: null,
  payload: const {},
);
