import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/presentation/event_audience_controller.dart';

import 'support/event_audience_fakes.dart';

void main() {
  for (final role in ['ROLE_LISTENER', 'ROLE_MUSICIAN']) {
    test(
      '$role saves private intent before optional listener publication',
      () async {
        final repository = AudienceTestRepository();
        final sessions = AudienceTestSessions(audienceSession(role: role));
        final controller = EventAudienceController(
          eventId: audienceEventId,
          repository: repository,
          sessions: sessions,
          initialIntent: repository.current,
        );
        addTearDown(controller.dispose);
        await controller.choose(
          EventAudienceStatus.going,
          expectedRevision: controller.revision,
        );
        expect(repository.writes.single.published, isFalse);
        expect(repository.writes.single.note, isNull);
        expect(controller.state!.intent, EventAudienceStatus.going);
        final publish = await controller.publish(
          'Görüşürüz',
          expectedRevision: controller.revision,
        );
        expect(publish != null, role == 'ROLE_LISTENER');
        expect(repository.writes.length, role == 'ROLE_LISTENER' ? 2 : 1);
      },
    );
  }

  for (final session in [
    const AuthSession.guest(),
    audienceSession(role: 'ROLE_VENUE'),
    audienceSession(role: 'ROLE_ADMIN'),
    audienceSession(status: 'PASSIVE'),
    audienceSession(isAdmin: true),
    audienceSession(roles: ['LISTENER', 'MUSICIAN']),
    for (final role in [
      'ADMIN',
      'OWNER',
      'VENUE',
      'STUDIO',
      'BAND',
      'ORGANIZER',
      'PRODUCER',
    ])
      audienceSession(roles: ['ROLE_MUSICIAN', 'ROLE_$role']),
  ]) {
    test(
      'ineligible session ${session.roles} makes no audience reads or writes',
      () async {
        final repository = AudienceTestRepository();
        final controller = EventAudienceController(
          eventId: audienceEventId,
          repository: repository,
          sessions: AudienceTestSessions(session),
        );
        addTearDown(controller.dispose);
        await controller.choose(
          EventAudienceStatus.going,
          expectedRevision: controller.revision,
        );
        expect(repository.reads, isEmpty);
        expect(repository.writes, isEmpty);
      },
    );
  }

  test(
    'normalized aliases and auxiliary USER role allow exactly one supported profile',
    () {
      expect(
        canUseEventAudience(
          audienceSession(roles: [' role_listener ', 'LISTENER', 'ROLE_USER']),
        ),
        isTrue,
      );
      expect(
        canUseEventAudience(audienceSession(roles: [' musician ', 'USER'])),
        isTrue,
      );
      expect(canUseEventAudience(audienceSession(roles: ['USER'])), isFalse);
    },
  );

  test(
    'rapid opposing taps dispatch once and stale callbacks cannot overwrite',
    () async {
      final pending = Completer<Result<EventAudienceState>>();
      final repository = AudienceTestRepository()
        ..onWrite = (_) => pending.future;
      final controller = EventAudienceController(
        eventId: audienceEventId,
        repository: repository,
        sessions: AudienceTestSessions(audienceSession()),
        initialIntent: repository.current,
      );
      addTearDown(controller.dispose);
      final revision = controller.revision;
      final first = controller.choose(
        EventAudienceStatus.going,
        expectedRevision: revision,
      );
      expect(
        await controller.choose(
          EventAudienceStatus.thinking,
          expectedRevision: revision,
        ),
        isNull,
      );
      expect(repository.writes.length, 1);
      pending.complete(
        Result.success(
          audienceState(intent: EventAudienceStatus.going, version: 1),
        ),
      );
      await first;
      expect(
        await controller.choose(
          EventAudienceStatus.thinking,
          expectedRevision: revision,
        ),
        isNull,
      );
      expect(controller.state!.intent, EventAudienceStatus.going);
    },
  );

  test(
    'account switch clears state and rejects a late old-account mutation',
    () async {
      final pending = Completer<Result<EventAudienceState>>();
      final repository = AudienceTestRepository()
        ..onWrite = (_) => pending.future;
      final sessions = AudienceTestSessions(audienceSession());
      final controller = EventAudienceController(
        eventId: audienceEventId,
        repository: repository,
        sessions: sessions,
        initialIntent: repository.current,
      );
      addTearDown(controller.dispose);
      final save = controller.choose(
        EventAudienceStatus.going,
        expectedRevision: controller.revision,
      );
      sessions.replace(audienceSession(user: 'second', token: 'second-token'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state!.intent, EventAudienceStatus.none);
      pending.complete(
        Result.success(
          audienceState(intent: EventAudienceStatus.going, version: 1),
        ),
      );
      expect(await save, isNull);
      expect(controller.state!.intent, EventAudienceStatus.none);
      expect(repository.writes.single.user, 'listener');
      expect(repository.reads, ['second']);
    },
  );

  test('logout clears private state and rejects late reads', () async {
    final pending = Completer<Result<EventAudienceState>>();
    final repository = AudienceTestRepository()..onRead = () => pending.future;
    final sessions = AudienceTestSessions(audienceSession());
    final controller = EventAudienceController(
      eventId: audienceEventId,
      repository: repository,
      sessions: sessions,
    );
    addTearDown(controller.dispose);
    sessions.replace(const AuthSession.guest());
    pending.complete(
      Result.success(
        audienceState(intent: EventAudienceStatus.going, version: 1),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, isNull);
    expect(controller.allowed, isFalse);
  });

  test(
    'same account new token rejects old read even if it resolves last',
    () async {
      final old = Completer<Result<EventAudienceState>>();
      final repository = AudienceTestRepository()..onRead = () => old.future;
      final sessions = AudienceTestSessions(audienceSession());
      final controller = EventAudienceController(
        eventId: audienceEventId,
        repository: repository,
        sessions: sessions,
      );
      addTearDown(controller.dispose);
      repository.onRead = () async => Result.success(
        audienceState(intent: EventAudienceStatus.thinking, version: 2),
      );
      sessions.replace(audienceSession(token: 'new-token'));
      await Future<void>.delayed(Duration.zero);
      old.complete(
        Result.success(
          audienceState(intent: EventAudienceStatus.going, version: 1),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state!.intent, EventAudienceStatus.thinking);
      expect(controller.state!.version, 2);
    },
  );

  test(
    'admin promotion clears private state even with unchanged role strings',
    () async {
      final repository = AudienceTestRepository();
      final sessions = AudienceTestSessions(audienceSession());
      final controller = EventAudienceController(
        eventId: audienceEventId,
        repository: repository,
        sessions: sessions,
        initialIntent: repository.current,
      );
      addTearDown(controller.dispose);
      sessions.replace(audienceSession(isAdmin: true));
      expect(controller.state, isNull);
      expect(controller.allowed, isFalse);
      expect(repository.reads, isEmpty);
    },
  );

  test('ambiguous mutation requires readback before any new write', () async {
    final repository = AudienceTestRepository()
      ..onWrite = (_) async =>
          const Result.failure(AppError(code: '9921', message: 'conflict'));
    final controller = EventAudienceController(
      eventId: audienceEventId,
      repository: repository,
      sessions: AudienceTestSessions(audienceSession()),
      initialIntent: repository.current,
    );
    addTearDown(controller.dispose);
    await controller.choose(
      EventAudienceStatus.going,
      expectedRevision: controller.revision,
    );
    expect(controller.needsRefresh, isTrue);
    await controller.choose(
      EventAudienceStatus.thinking,
      expectedRevision: controller.revision,
    );
    expect(repository.writes.length, 1);
    repository.current = audienceState(
      intent: EventAudienceStatus.going,
      version: 2,
    );
    await controller.refresh();
    expect(controller.state!.version, 2);
    expect(controller.needsRefresh, isFalse);
  });

  test(
    'repository invalidation during a read triggers one deferred refresh',
    () async {
      final old = Completer<Result<EventAudienceState>>();
      final repository = AudienceTestRepository()..onRead = () => old.future;
      final controller = EventAudienceController(
        eventId: audienceEventId,
        repository: repository,
        sessions: AudienceTestSessions(audienceSession()),
      );
      addTearDown(controller.dispose);
      repository.signal.value++;
      repository.signal.value++;
      repository.onRead = () async => Result.success(
        audienceState(intent: EventAudienceStatus.thinking, version: 2),
      );
      old.complete(Result.success(audienceState()));
      await Future<void>.delayed(Duration.zero);
      expect(repository.reads.length, 2);
      expect(controller.state!.intent, EventAudienceStatus.thinking);
    },
  );

  test(
    'changing published status updates live post and preserves note; removal clears both',
    () async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.thinking,
          published: true,
          note: 'Eski not',
          version: 4,
        );
      final controller = EventAudienceController(
        eventId: audienceEventId,
        repository: repository,
        sessions: AudienceTestSessions(audienceSession()),
        initialIntent: repository.current,
      );
      addTearDown(controller.dispose);
      await controller.choose(
        EventAudienceStatus.going,
        expectedRevision: controller.revision,
      );
      expect(repository.writes.single.published, isTrue);
      expect(controller.state!.note, 'Eski not');
      await controller.choose(
        EventAudienceStatus.thinking,
        expectedRevision: controller.revision,
      );
      expect(repository.writes.last.published, isTrue);
      expect(repository.writes.last.note, 'Eski not');
      await controller.choose(
        EventAudienceStatus.none,
        expectedRevision: controller.revision,
      );
      expect(repository.writes.last.intent, EventAudienceStatus.none);
      expect(repository.writes.last.published, isFalse);
    },
  );

  test(
    'ended plans can be cleared or unpublished but not changed or newly published',
    () async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          published: true,
          note: 'Geçmiş',
          version: 3,
          ended: true,
        );
      final controller = EventAudienceController(
        eventId: audienceEventId,
        repository: repository,
        sessions: AudienceTestSessions(audienceSession()),
        initialIntent: repository.current,
      );
      addTearDown(controller.dispose);
      expect(
        await controller.choose(
          EventAudienceStatus.thinking,
          expectedRevision: controller.revision,
        ),
        isNull,
      );
      expect(
        await controller.publish('Yeni', expectedRevision: controller.revision),
        isNull,
      );
      await controller.unpublish(expectedRevision: controller.revision);
      expect(repository.writes.single.published, isFalse);
      await controller.choose(
        EventAudienceStatus.none,
        expectedRevision: controller.revision,
      );
      expect(repository.writes.last.intent, EventAudienceStatus.none);
    },
  );
}
