import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_read_recovery.dart';

void main() {
  test(
    'unexpected ACK exception can retry explicitly without early confirmation',
    () async {
      final owner = Object();
      var requests = 0, confirmed = 0;
      final recovery = NotificationReadRecovery(
        isCurrent: () => true,
        acknowledge: () async {
          if (++requests == 1) throw StateError('transport');
          return true;
        },
        confirm: () async {
          confirmed++;
        },
      );
      recovery.present(owner, () => true);
      await Future<void>.delayed(Duration.zero);
      expect(recovery.showsRetryFor(owner), isTrue);
      expect(confirmed, 0);
      recovery.present(owner, () => true);
      expect(requests, 1);
      recovery.retry(owner);
      recovery.retry(owner);
      await Future<void>.delayed(Duration.zero);
      expect(requests, 2);
      expect(confirmed, 1);
      expect(recovery.showsRetryFor(owner), isFalse);
      recovery.dispose();
    },
  );

  test(
    'multiple success markers cannot duplicate the ACK or recovery surface',
    () async {
      final first = Object(), second = Object();
      final pending = Completer<bool>();
      var requests = 0;
      final recovery = NotificationReadRecovery(
        isCurrent: () => true,
        acknowledge: () {
          requests++;
          return pending.future;
        },
        confirm: () async {},
      );
      recovery.present(first, () => true);
      recovery.present(second, () => true);
      expect(
        recovery.showsRetryFor(first),
        isFalse,
      ); // No initial loading overlay.
      pending.complete(false);
      await Future<void>.delayed(Duration.zero);
      expect(recovery.showsRetryFor(first), isTrue);
      expect(recovery.showsRetryFor(second), isFalse);
      recovery.retry(second);
      expect(requests, 1);
      recovery.dispose();
    },
  );

  test(
    'projection refresh exception after successful ACK never sends another ACK',
    () async {
      final owner = Object();
      var requests = 0, confirmed = 0;
      final recovery = NotificationReadRecovery(
        isCurrent: () => true,
        acknowledge: () async {
          requests++;
          return true;
        },
        confirm: () async {
          confirmed++;
          throw StateError('count unavailable');
        },
      );
      recovery.present(owner, () => true);
      await Future<void>.delayed(Duration.zero);
      recovery.suspend(owner);
      recovery.present(owner, () => true);
      recovery.retry(owner);
      expect(requests, 1);
      expect(confirmed, 1);
      expect(recovery.showsRetryFor(owner), isFalse);
      recovery.dispose();
    },
  );

  test(
    'hidden and resumed owner cannot overlap an outstanding request',
    () async {
      final owner = Object();
      final pending = Completer<bool>();
      var requests = 0, confirmed = 0;
      final recovery = NotificationReadRecovery(
        isCurrent: () => true,
        acknowledge: () {
          requests++;
          return pending.future;
        },
        confirm: () async {
          confirmed++;
        },
      );
      recovery.present(owner, () => true);
      recovery.suspend(owner);
      recovery.present(owner, () => true);
      recovery.retry(owner);
      expect(requests, 1);
      pending.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(confirmed, 0);
      expect(recovery.showsRetryFor(owner), isTrue);
      recovery.retry(owner);
      await Future<void>.delayed(Duration.zero);
      expect(requests, 2);
      expect(confirmed, 1);
      recovery.dispose();
    },
  );
}
