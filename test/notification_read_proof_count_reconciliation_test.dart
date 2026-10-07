import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_read_recovery.dart';

import 'support/event_audience_fakes.dart';
import 'support/notification_counter_fakes.dart';

class DelayedPageRepository extends CounterRepository {
  DelayedPageRepository(super.initial);
  Completer<void>? pageGate;
  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    final gate = pageGate;
    if (gate != null) {
      pageGate = null;
      await gate.future;
    }
    return super.listNotifications(page: page, size: size);
  }
}

void main() {
  for (final mode in ['page', 'refreshCountError']) {
    for (final learnReadBeforeAck in [false, true]) {
      for (final duplicateCallbacks in [false, true]) {
        test(
          '$mode readProofFirst=$learnReadBeforeAck duplicates=$duplicateCallbacks keeps both confirmed reads',
          () async {
            final a = counterNotification('a');
            final b = counterNotification('b');
            final siblings = List.generate(
              19,
              (i) => counterNotification('sibling-$i'),
            );
            final rows = mode == 'page'
                ? [a, ...siblings, b]
                : [a, b, ...siblings];
            final repo = DelayedPageRepository(rows);
            final sessions = AudienceTestSessions(
              audienceSession(user: counterOwner, role: 'ROLE_MUSICIAN'),
            );
            final realtime = CounterRealtime();
            final cubit = NotificationCubit(
              repo,
              CounterTokens(),
              realtimeClient: realtime,
              sessions: sessions,
            );
            final ackB = Completer<bool>();
            final owner = Object();
            var ackCalls = 0;
            final recovery = NotificationReadRecovery(
              isCurrent: () => !cubit.isClosed,
              acknowledge: () {
                ackCalls++;
                repo.commitRead('b');
                return ackB.future;
              },
              confirm: () =>
                  cubit.applyConfirmedExternalRead(b, sessions.session),
            );
            try {
              await cubit.ensureStarted();
              final heldA = repo.holdNextCount();
              repo.commitRead('a');
              final first = cubit.applyConfirmedExternalRead(
                rows.first,
                sessions.session,
              );
              await flushCounter();
              expect(heldA.snapshot, 20);
              Future<void>? projection;
              Completer<void>? pageGate;
              if (learnReadBeforeAck) {
                pageGate = Completer<void>();
                repo.pageGate = pageGate;
                if (mode == 'page') {
                  projection = cubit.loadMore();
                } else {
                  // This active refresh has started before the target's read commits.
                  projection = cubit.refresh();
                }
              }
              recovery.present(owner, () => true);
              expect(ackCalls, 1);
              if (learnReadBeforeAck) {
                HeldCounterResponse? failedCount;
                if (mode == 'refreshCountError') {
                  failedCount = repo.holdNextCount();
                }
                pageGate!.complete();
                await flushCounter();
                failedCount?.fail();
                await projection;
                expect(
                  cubit.state.items.singleWhere((n) => n.id == 'b').read,
                  isTrue,
                );
              }
              ackB.complete(true);
              await flushCounter();
              final latestCount = repo.holdNextCount();
              heldA.deliver();
              await flushCounter();
              expect(latestCount.snapshot, 19);
              final duplicates = duplicateCallbacks
                  ? List.generate(
                      20,
                      (_) =>
                          cubit.applyConfirmedExternalRead(b, sessions.session),
                    )
                  : <Future<void>>[];
              await flushCounter();
              latestCount.deliver();
              await first;
              await Future.wait(duplicates);
              await flushCounter();
              expect(ackCalls, 1);
              expect(repo.unread, 19);
              expect(
                repo.counts,
                learnReadBeforeAck && mode == 'refreshCountError'
                    ? [21, 20, 19, 19]
                    : [21, 20, 19],
                reason:
                    'Duplicate callbacks must not extend the shared count flight.',
              );
              expect(repo.readCalls, isEmpty);
              expect(repo.deleteCalls, isEmpty);
              expect(
                repo.rows.where((row) => !row.read).map((row) => row.id),
                siblings.map((row) => row.id),
              );
              expect(
                cubit.state.unreadCount,
                19,
                reason:
                    'Both successful exact reads must reconcile without WS/manual recovery.',
              );
            } finally {
              recovery.dispose();
              await cubit.close();
              await realtime.dispose();
              sessions.dispose();
            }
          },
        );
      }
    }
  }
}
