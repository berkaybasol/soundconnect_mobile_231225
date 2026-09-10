import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/overthinking_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_incoming_unread_status.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_incoming_unread_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/widgets/overthinking_incoming_request_icon.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  test(
    'unread status and seen use server revisions and original auth token',
    () async {
      final sessions = AudienceTestSessions(audienceSession(user: 'author'));
      addTearDown(sessions.dispose);
      final api = RecordingApiClient(
        (request) => {
          'hasUnread': request.method == RecordedHttpMethod.get,
          'revision': 12,
        },
      );
      final repository = OverthinkingRepositoryImpl(api, sessions: sessions);
      final status = await repository.getIncomingUnreadStatus();
      expect(status.data!.hasUnread, isTrue);
      expect(status.data!.revision, 12);
      final seen = await repository.markIncomingRequestsSeen(
        revision: status.data!.revision,
      );
      expect(seen.data!.hasUnread, isFalse);
      expect(api.requests.map((r) => r.path), [
        '/api/v1/overthinking/reveal-requests/incoming/unread-status',
        '/api/v1/overthinking/reveal-requests/incoming/seen',
      ]);
      expect(api.requests.last.method, RecordedHttpMethod.post);
      expect(api.requests.last.body, {'revision': 12});
      for (final request in api.requests) {
        expect(request.query, isNull);
        expect(request.requestContext?.expectedSessionKey, 'author');
        expect(request.requestContext?.expectedToken, 'token');
      }
    },
  );

  for (final payload in [
    null,
    {},
    {'hasUnread': true},
    {'hasUnread': 1, 'revision': 4},
    {'hasUnread': true, 'revision': -1},
    {'hasUnread': true, 'revision': 1.5},
  ]) {
    test('malformed unread status $payload stays unknown', () async {
      final repository = OverthinkingRepositoryImpl(
        RecordingApiClient((_) => payload),
      );
      expect((await repository.getIncomingUnreadStatus()).isSuccess, isFalse);
      expect(
        (await repository.markIncomingRequestsSeen(revision: 4)).isSuccess,
        isFalse,
      );
    });
  }

  test('negative seen revision and guest operations never dispatch', () async {
    final sessions = AudienceTestSessions(const AuthSession.guest());
    addTearDown(sessions.dispose);
    final api = RecordingApiClient((_) => {'hasUnread': true, 'revision': 2});
    final repository = OverthinkingRepositoryImpl(api, sessions: sessions);
    expect((await repository.getIncomingUnreadStatus()).isSuccess, isFalse);
    expect(
      (await repository.markIncomingRequestsSeen(revision: 2)).isSuccess,
      isFalse,
    );
    expect(
      (await OverthinkingRepositoryImpl(
        api,
      ).markIncomingRequestsSeen(revision: -1)).isSuccess,
      isFalse,
    );
    expect(api.requests, isEmpty);
  });

  test('repository rejects a late old-session acknowledgement', () async {
    final sessions = AudienceTestSessions(
      audienceSession(user: 'author', token: 'old'),
    );
    addTearDown(sessions.dispose);
    final pending = Completer<Object?>();
    final repository = OverthinkingRepositoryImpl(
      RecordingApiClient((_) => pending.future),
      sessions: sessions,
    );
    final marking = repository.markIncomingRequestsSeen(revision: 2);
    sessions.replace(audienceSession(user: 'author', token: 'new'));
    pending.complete({'hasUnread': false, 'revision': 2});
    expect((await marking).error?.code, 'overthinking_session_changed');
  });

  test(
    'opening hides dot immediately and persists seen without a reveal decision',
    () async {
      final repository = _Inbox();
      final cubit = OverthinkingIncomingUnreadCubit(repository);
      await cubit.refresh();
      expect(cubit.state, isTrue);
      final marking = cubit.markSeen();
      expect(cubit.state, isFalse);
      await marking;
      expect(repository.acknowledged, [5]);
      await cubit.refresh();
      expect(cubit.state, isFalse);
      await cubit.close();
      final reopened = OverthinkingIncomingUnreadCubit(repository);
      addTearDown(reopened.close);
      await reopened.refresh();
      expect(reopened.state, isFalse);
      expect(repository.decisions, 0);
    },
  );

  test(
    'old unread GET and parallel refresh cannot reopen an acknowledged dot',
    () async {
      final repository = _Inbox();
      final stale = Completer<Result<OverthinkingIncomingUnreadStatus>>();
      repository.onRead = () => repository.reads == 1
          ? stale.future
          : Future.value(repository.status);
      final cubit = OverthinkingIncomingUnreadCubit(repository);
      addTearDown(cubit.close);
      final reading = cubit.refresh();
      final marking = cubit.markSeen();
      final concurrent = cubit.refresh();
      expect(cubit.state, isFalse);
      await marking;
      await concurrent;
      stale.complete(_status(true, 5));
      await reading;
      await _flush();
      expect(cubit.state, isFalse);
      expect(repository.acknowledged, [5]);
    },
  );

  test(
    'delayed seen notification never emits unread while its status GET is pending',
    () async {
      final repository = _Inbox()..seen = 5;
      final incoming = StreamController<AppNotification>.broadcast(sync: true);
      final cubit = OverthinkingIncomingUnreadCubit(
        repository,
        notifications: incoming.stream,
      );
      await cubit.refresh();
      await _flush();
      final observed = <bool?>[];
      final subscription = cubit.stream.listen(observed.add);
      final status = Completer<Result<OverthinkingIncomingUnreadStatus>>();
      repository.onRead = () => status.future;
      addTearDown(() async {
        await cubit.close();
        await subscription.cancel();
        await incoming.close();
      });
      incoming.add(_notification());
      expect(repository.reads, 2);
      await _flush();
      final beforeReply = List<bool?>.of(observed);
      status.complete(_status(false, 5));
      await _flush();
      expect(beforeReply, isNot(contains(true)));
      expect(observed, isNot(contains(true)));
      expect(cubit.state, isFalse);
    },
  );

  for (final duringGet in [true, false]) {
    test(
      'delayed seen notification during ${duringGet ? 'first snapshot GET' : 'seen POST'} never reopens dot',
      () async {
        final repository = _Inbox()..seen = 5;
        final incoming = StreamController<AppNotification>.broadcast(
          sync: true,
        );
        final pending = Completer<Result<OverthinkingIncomingUnreadStatus>>();
        if (duringGet) {
          repository.onRead = () => repository.reads == 1
              ? pending.future
              : Future.value(repository.status);
        } else {
          repository.onSeen = (_) => pending.future;
        }
        final cubit = OverthinkingIncomingUnreadCubit(
          repository,
          notifications: incoming.stream,
        );
        final observed = <bool?>[];
        final subscription = cubit.stream.listen(observed.add);
        addTearDown(() async {
          await cubit.close();
          await subscription.cancel();
          await incoming.close();
        });
        final marking = cubit.markSeen();
        await _flush();
        incoming.add(_notification());
        await _flush();
        pending.complete(_status(false, 5));
        await marking;
        await _flush();
        expect(observed, isNot(contains(true)));
        expect(cubit.state, isFalse);
      },
    );
  }

  test(
    'new request during seen POST stays unread after the old acknowledgement',
    () async {
      final repository = _Inbox();
      final incoming = StreamController<AppNotification>.broadcast(sync: true);
      final post = Completer<Result<OverthinkingIncomingUnreadStatus>>();
      repository.onSeen = (_) => post.future;
      final cubit = OverthinkingIncomingUnreadCubit(
        repository,
        notifications: incoming.stream,
      );
      addTearDown(() async {
        await cubit.close();
        await incoming.close();
      });
      await cubit.refresh();
      final marking = cubit.markSeen();
      await _flush();
      expect(repository.acknowledged, [5]);
      ++repository.revision;
      incoming.add(_notification());
      expect(cubit.state, isFalse);
      repository.seen = 5;
      post.complete(_status(false, 5));
      await marking;
      await _flush();
      expect(cubit.state, isTrue);
      expect(repository.seen, 5);
      expect(repository.revision, 6);
    },
  );

  test(
    'new request during opening GET is not included in the seen watermark',
    () async {
      final repository = _Inbox();
      final incoming = StreamController<AppNotification>.broadcast(sync: true);
      final cubit = OverthinkingIncomingUnreadCubit(
        repository,
        notifications: incoming.stream,
      );
      addTearDown(() async {
        await cubit.close();
        await incoming.close();
      });
      await cubit.refresh();
      final opening = Completer<Result<OverthinkingIncomingUnreadStatus>>();
      repository.onRead = () => repository.reads == 2
          ? opening.future
          : Future.value(repository.status);
      final marking = cubit.markSeen();
      ++repository.revision;
      incoming.add(_notification());
      opening.complete(repository.status);
      await marking;
      await _flush();
      expect(repository.acknowledged, [5]);
      expect(cubit.state, isTrue);
    },
  );

  test(
    'arrival before first snapshot stays unread without acknowledging unknown newer revision',
    () async {
      final repository = _Inbox();
      final incoming = StreamController<AppNotification>.broadcast(sync: true);
      final opening = Completer<Result<OverthinkingIncomingUnreadStatus>>();
      repository.onRead = () => repository.reads == 1
          ? opening.future
          : Future.value(repository.status);
      final cubit = OverthinkingIncomingUnreadCubit(
        repository,
        notifications: incoming.stream,
      );
      addTearDown(() async {
        await cubit.close();
        await incoming.close();
      });
      final marking = cubit.markSeen();
      ++repository.revision;
      incoming.add(_notification());
      opening.complete(repository.status);
      await marking;
      await _flush();
      expect(repository.acknowledged, isEmpty);
      expect(cubit.state, isTrue);
    },
  );

  test(
    'only the current recipients incoming requests reopen the dot; reconnect restores it',
    () async {
      final repository = _Inbox()..seen = 5;
      final sessions = AudienceTestSessions(audienceSession(user: 'author'));
      final incoming = StreamController<AppNotification>.broadcast(sync: true);
      final connections = StreamController<void>.broadcast(sync: true);
      final cubit = OverthinkingIncomingUnreadCubit(
        repository,
        sessions: sessions,
        notifications: incoming.stream,
        reconnections: connections.stream,
      );
      addTearDown(() async {
        await cubit.close();
        await incoming.close();
        await connections.close();
        sessions.dispose();
      });
      await cubit.refresh();
      incoming.add(_notification(recipient: 'other'));
      incoming.add(_notification(type: 'OVERTHINKING_REVEAL_REQUEST_APPROVED'));
      expect(repository.reads, 1);
      expect(cubit.state, isFalse);
      ++repository.revision;
      incoming.add(_notification());
      expect(cubit.state, isFalse);
      await _flush();
      expect(cubit.state, isTrue);
      await cubit.markSeen();
      expect(cubit.state, isFalse);
      ++repository.revision;
      connections.add(null);
      await _flush();
      expect(cubit.state, isTrue);
    },
  );

  test(
    'failed acknowledgement restores unread and retry can persist seen',
    () async {
      final repository = _Inbox();
      final cubit = OverthinkingIncomingUnreadCubit(repository);
      addTearDown(cubit.close);
      await cubit.refresh();
      repository.onSeen = (_) async =>
          const Result.failure(AppError(code: 'offline', message: 'Offline'));
      final marking = cubit.markSeen();
      expect(cubit.state, isFalse);
      await marking;
      await _flush();
      expect(cubit.state, isTrue);
      repository.onSeen = null;
      await cubit.markSeen();
      expect(cubit.state, isFalse);
    },
  );

  for (final nextUser in ['author', 'other']) {
    test(
      'session replacement into $nextUser clears dot and rejects pending seen',
      () async {
        final sessions = AudienceTestSessions(
          audienceSession(user: 'author', token: 'old'),
        );
        final repository = _Inbox();
        final pending = Completer<Result<OverthinkingIncomingUnreadStatus>>();
        repository.onSeen = (_) => pending.future;
        final cubit = OverthinkingIncomingUnreadCubit(
          repository,
          sessions: sessions,
        );
        addTearDown(() async {
          await cubit.close();
          sessions.dispose();
        });
        await cubit.refresh();
        final marking = cubit.markSeen();
        await _flush();
        sessions.replace(const AuthSession.guest());
        sessions.replace(audienceSession(user: nextUser, token: 'new'));
        pending.complete(_status(true, 6));
        await marking;
        expect(cubit.state, isNull);
        final reads = repository.reads;
        await cubit.markSeen();
        await cubit.refresh();
        expect(repository.reads, reads);
        expect(repository.acknowledged, [5]);
      },
    );
  }

  test(
    'guest does not read or acknowledge and close drops late callbacks',
    () async {
      final sessions = AudienceTestSessions(const AuthSession.guest());
      final repository = _Inbox();
      final guest = OverthinkingIncomingUnreadCubit(
        repository,
        sessions: sessions,
      );
      await guest.markSeen();
      await guest.refresh();
      expect(repository.reads, 0);
      expect(repository.acknowledged, isEmpty);
      await guest.close();
      sessions.dispose();
      final pending = Completer<Result<OverthinkingIncomingUnreadStatus>>();
      repository.onRead = () => pending.future;
      final cubit = OverthinkingIncomingUnreadCubit(repository);
      final marking = cubit.markSeen();
      await cubit.close();
      await cubit.close();
      pending.complete(_status(true, 5));
      await marking;
      expect(repository.acknowledged, isEmpty);
    },
  );

  testWidgets('incoming icon keeps 17px size and adds only a 7px unread dot', (
    tester,
  ) async {
    Future<void> mount(bool? unread) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: OverthinkingIncomingRequestIcon(hasUnread: unread),
          ),
        ),
      ),
    );
    for (final unread in [null, false, true]) {
      await mount(unread);
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, unread == true);
      expect(badge.label, isNull);
      expect(badge.smallSize, 7);
      expect(tester.widget<Icon>(find.byIcon(Icons.inbox_outlined)).size, 17);
      expect(tester.getSize(find.byType(Badge)), const Size(17, 17));
      expect(find.byType(Text), findsNothing);
    }
    expect(find.bySemanticsLabel('Yeni kimlik isteği var'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

Result<OverthinkingIncomingUnreadStatus> _status(bool unread, int revision) =>
    Result.success(
      OverthinkingIncomingUnreadStatus(hasUnread: unread, revision: revision),
    );

class _Inbox extends Fake implements OverthinkingRepository {
  int revision = 5;
  int seen = 0;
  int reads = 0;
  final decisions = 0;
  final acknowledged = <int>[];
  Future<Result<OverthinkingIncomingUnreadStatus>> Function()? onRead;
  Future<Result<OverthinkingIncomingUnreadStatus>> Function(int)? onSeen;
  Result<OverthinkingIncomingUnreadStatus> get status =>
      _status(seen < revision, revision);

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>> getIncomingUnreadStatus() {
    ++reads;
    return onRead?.call() ?? Future.value(status);
  }

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>> markIncomingRequestsSeen({
    required int revision,
  }) async {
    acknowledged.add(revision);
    if (onSeen != null) return onSeen!(revision);
    if (revision > seen) seen = revision;
    return status;
  }
}

AppNotification _notification({
  String recipient = 'author',
  String type = 'OVERTHINKING_REVEAL_REQUEST_RECEIVED',
}) => AppNotification(
  id: 'notification',
  recipientId: recipient,
  type: type,
  title: '',
  message: '',
  read: false,
  createdAt: null,
  payload: const {},
);
