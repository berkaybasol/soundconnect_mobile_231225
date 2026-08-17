import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_idempotency_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'lease survives store recreation without persisting private payload',
    () async {
      final tokenStore = _MemoryTokenStore(_jwt('user-a'));
      var requestSequence = 0;
      String nextRequestId() => 'request-${++requestSequence}';

      final firstStore = SharedPreferencesCollabIdempotencyStore(
        tokenStore: tokenStore,
      );
      final first = await firstStore.acquire(
        operation: 'apply',
        targetId: 'listing-1',
        payloadFingerprint: 'phone=05550000000|message=özel mesaj',
        createRequestId: nextRequestId,
      );

      final recreatedStore = SharedPreferencesCollabIdempotencyStore(
        tokenStore: tokenStore,
      );
      final recovered = await recreatedStore.acquire(
        operation: 'apply',
        targetId: 'listing-1',
        payloadFingerprint: 'phone=05550000000|message=özel mesaj',
        createRequestId: nextRequestId,
      );

      expect(recovered.requestId, first.requestId);
      expect(requestSequence, 1);
      final preferences = await SharedPreferences.getInstance();
      final persisted = preferences
          .getKeys()
          .map(preferences.getString)
          .whereType<String>()
          .join('|');
      expect(persisted, isNot(contains('05550000000')));
      expect(persisted, isNot(contains('özel mesaj')));
    },
  );

  test('lease is user scoped and cleared only after reconciliation', () async {
    final tokenStore = _MemoryTokenStore(_jwt('user-a'));
    var requestSequence = 0;
    String nextRequestId() => 'request-${++requestSequence}';
    final store = SharedPreferencesCollabIdempotencyStore(
      tokenStore: tokenStore,
    );

    final userA = await store.acquire(
      operation: 'review',
      targetId: 'job-1',
      payloadFingerprint: '5|harika',
      createRequestId: nextRequestId,
    );
    tokenStore.token = _jwt('user-b');
    final userB = await store.acquire(
      operation: 'review',
      targetId: 'job-1',
      payloadFingerprint: '5|harika',
      createRequestId: nextRequestId,
    );

    expect(userB.requestId, isNot(userA.requestId));
    tokenStore.token = _jwt('user-a');
    final recoveredA = await store.acquire(
      operation: 'review',
      targetId: 'job-1',
      payloadFingerprint: '5|harika',
      createRequestId: nextRequestId,
    );
    expect(recoveredA.requestId, userA.requestId);

    await store.complete(recoveredA);
    final afterReconciliation = await store.acquire(
      operation: 'review',
      targetId: 'job-1',
      payloadFingerprint: '5|harika',
      createRequestId: nextRequestId,
    );
    expect(afterReconciliation.requestId, isNot(userA.requestId));
  });

  test(
    'lease expires after TTL while response-loss retries stay reusable',
    () async {
      final tokenStore = _MemoryTokenStore(_jwt('user-a'));
      var now = DateTime.utc(2026, 8, 11, 10);
      var requestSequence = 0;
      String nextRequestId() => 'request-${++requestSequence}';

      SharedPreferencesCollabIdempotencyStore createStore() =>
          SharedPreferencesCollabIdempotencyStore(
            tokenStore: tokenStore,
            leaseTtl: const Duration(hours: 24),
            clock: () => now,
          );

      final initial = await createStore().acquire(
        operation: 'create_listing',
        targetId: 'new',
        payloadFingerprint: 'canonical-payload',
        createRequestId: nextRequestId,
      );
      now = now.add(const Duration(hours: 23, minutes: 59));
      final retry = await createStore().acquire(
        operation: 'create_listing',
        targetId: 'new',
        payloadFingerprint: 'canonical-payload',
        createRequestId: nextRequestId,
      );
      expect(retry.requestId, initial.requestId);
      expect(retry.createdAt, initial.createdAt);

      now = now.add(const Duration(minutes: 2));
      final expired = await createStore().acquire(
        operation: 'create_listing',
        targetId: 'new',
        payloadFingerprint: 'canonical-payload',
        createRequestId: nextRequestId,
      );
      expect(expired.requestId, isNot(initial.requestId));
      expect(requestSequence, 2);
    },
  );

  test('explicit abandon and operation reset rotate the request id', () async {
    final store = SharedPreferencesCollabIdempotencyStore(
      tokenStore: _MemoryTokenStore(_jwt('user-a')),
      clock: () => DateTime.utc(2026, 8, 11, 10),
    );
    var requestSequence = 0;
    String nextRequestId() => 'request-${++requestSequence}';

    Future<CollabIdempotencyLease> acquire() => store.acquire(
      operation: 'create_listing',
      targetId: 'new',
      payloadFingerprint: 'canonical-payload',
      createRequestId: nextRequestId,
    );

    final initial = await acquire();
    await store.abandon(initial);
    final afterAbandon = await acquire();
    expect(afterAbandon.requestId, isNot(initial.requestId));

    await store.resetOperation(operation: 'create_listing', targetId: 'new');
    final afterReset = await acquire();
    expect(afterReset.requestId, isNot(afterAbandon.requestId));
  });

  test('rejects acquisition when no authenticated user scope exists', () async {
    final store = SharedPreferencesCollabIdempotencyStore(
      tokenStore: _MemoryTokenStore(null),
    );

    await expectLater(
      store.acquire(
        operation: 'report',
        targetId: 'listing-1',
        payloadFingerprint: 'spam|details',
        createRequestId: () => 'request-1',
      ),
      throwsA(isA<CollabIdempotencyStoreException>()),
    );
  });
}

String _jwt(String subject) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, Object>{
        'sub': subject,
        'exp':
            DateTime.now()
                .add(const Duration(days: 1))
                .millisecondsSinceEpoch ~/
            1000,
      }),
    ),
  );
  return '$header.$payload.signature';
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore(this.token);

  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async => token = value;
}
