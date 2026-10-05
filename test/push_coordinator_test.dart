import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_coordinator.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_device_api.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_delivery_api.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_installation_store.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';

part 'push_coordinator_test_tokens.dart';

const userA = '10000000-0000-4000-8000-000000000001';

const userB = '10000000-0000-4000-8000-000000000002';

const notification = '20000000-0000-4000-8000-000000000001';

const otherNotification = '20000000-0000-4000-8000-000000000002';

AuthSession session(
  String user, {
  bool needsChoice = false,
  String status = 'ACTIVE',
  List<String> roles = const ['ROLE_MUSICIAN'],
}) => AuthSession.authenticated(
  token: 'token-$user',
  userId: user,
  username: 'user',
  accountStatus: status,
  roles: roles,
  permissions: [],
  expiresAt: DateTime(2099),
  isAdmin: false,
  requiresListenerProfileChoice: needsChoice,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Sessions sessions;
  late _Provider provider;
  late _Api api;
  late _Store store;
  late PushCoordinator coordinator;
  late List<String> operations;
  var reconciliations = 0;
  setUp(() {
    operations = [];
    reconciliations = 0;
    sessions = _Sessions()..change(session(userA));
    provider = _Provider(operations);
    api = _Api(operations);
    store = _Store();
    coordinator = PushCoordinator(
      sessions: sessions,
      provider: provider,
      api: api,
      store: store,
      enabled: true,
      reconcileUnread: () async {
        reconciliations++;
      },
    );
  });
  tearDown(() async {
    coordinator.dispose();
    sessions.dispose();
    await provider.close();
  });

  const application = '40000000-0000-4000-8000-000000000001';
  AuthSession applicant([String id = application]) => AuthSession.authenticated(
    token: 'applicant-$id',
    userId: userA,
    username: 'applicant',
    accountStatus: 'PENDING_VENUE_REQUEST',
    roles: [],
    permissions: [],
    expiresAt: DateTime(2099),
    isAdmin: false,
    sessionScope: 'VENUE_APPLICATION',
    applicationId: id,
  );

  test(
    'limited application session never registers or requests permission on deferred iOS',
    () async {
      sessions.change(applicant());
      provider.currentPlatform = 'IOS';
      await coordinator.start();
      await coordinator.requestPermission();
      expect(api.registrations, isEmpty);
      expect(provider.permissionRequests, 0);
      expect(provider.boundRecipient, isNull);
    },
  );

  test(
    'limited restored session retains two cards only with owner scope application and epoch proof',
    () async {
      sessions.change(applicant());
      store.owner = userA;
      provider.boundRecipient = userA;
      provider.deliveredIds = [notification, otherNotification];
      final epoch = provider.bindingEpoch;
      store.context = '$userA|APPLICATION:$application|$epoch';
      await coordinator.start();
      expect(provider.bindingEpoch, epoch);
      expect(provider.deliveredIds, [notification, otherNotification]);
      expect(api.registrations, hasLength(1));
      expect(store.context, '$userA|APPLICATION:$application|$epoch');
    },
  );
  for (final context in [
    null,
    '$userA|GENERAL|$userB',
    '$userA|APPLICATION:$userB|$userB',
    '$userA|APPLICATION:$application|$userA',
  ]) {
    test(
      'limited cold startup rejects missing or mismatched proof $context',
      () async {
        sessions.change(applicant());
        store.owner = userA;
        store.context = context;
        provider.boundRecipient = userA;
        provider.deliveredIds = [notification, otherNotification];
        final epoch = provider.bindingEpoch;
        await coordinator.start();
        expect(provider.deliveredIds, isEmpty);
        expect(provider.bindingEpoch, isNot(epoch));
        expect(provider.boundRecipient, userA);
        expect(
          store.context,
          '$userA|APPLICATION:$application|${provider.bindingEpoch}',
        );
      },
    );
  }
  test(
    'normal startup cannot preserve a prior limited binding for the same account',
    () async {
      store.owner = userA;
      store.context = '$userA|APPLICATION:$application|$userB';
      provider.boundRecipient = userA;
      provider.deliveredIds = [notification, otherNotification];
      await coordinator.start();
      expect(provider.deliveredIds, isEmpty);
      expect(store.context, '$userA|GENERAL|${provider.bindingEpoch}');
    },
  );
  test(
    'same owner changing signed application clears native epoch before re-registration',
    () async {
      sessions.change(applicant());
      await coordinator.start();
      provider.deliveredIds = [notification, otherNotification];
      final epoch = provider.bindingEpoch;
      sessions.change(applicant(userB));
      await coordinator.reconcile();
      expect(provider.deliveredIds, isEmpty);
      expect(provider.bindingEpoch, isNot(epoch));
      expect(
        store.context,
        '$userA|APPLICATION:$userB|${provider.bindingEpoch}',
      );
    },
  );
  test(
    'late context write after logout cannot prove a subsequently cleared native epoch',
    () async {
      sessions.change(applicant());
      store.contextGate = Completer<void>();
      store.contextReached = Completer<void>();
      final starting = coordinator.start();
      await store.contextReached!.future;
      final boundEpoch = provider.bindingEpoch;
      sessions.change(const AuthSession.guest());
      expect(provider.bindingEpoch, isNot(boundEpoch));
      store.contextGate!.complete();
      await starting;
      await coordinator.reconcile();
      expect(provider.boundRecipient, isNull);
      expect(store.context, '$userA|APPLICATION:$application|$boundEpoch');
      expect(
        store.context,
        isNot('$userA|APPLICATION:$application|${provider.bindingEpoch}'),
      );
    },
  );

  test(
    'disabled build never initializes a provider or registers a device',
    () async {
      coordinator.dispose();
      coordinator = PushCoordinator(
        sessions: sessions,
        provider: provider,
        api: api,
        store: store,
        reconcileUnread: () async {},
        enabled: false,
      );
      await coordinator.start();
      expect(provider.initialized, 0);
      expect(api.registrations, isEmpty);
      expect(coordinator.status, PushStatus.disabled);
    },
  );

  test('missing native Firebase configuration is contained', () async {
    provider.failInitialize = true;
    provider.boundRecipient = userB;
    await coordinator.start();
    expect(coordinator.status, PushStatus.unavailable);
    expect(api.registrations, isEmpty);
    expect(provider.boundRecipient, isNull);
  });

  test(
    'permission is requested only by explicit action; denied never gets token',
    () async {
      provider.allowed = PushPermission.denied;
      await coordinator.start();
      expect(provider.permissionRequests, 0);
      expect(provider.tokenReads, 0);
      await coordinator.requestPermission();
      expect(provider.permissionRequests, 1);
      expect(api.registrations, isEmpty);
    },
  );

  test(
    'registration uses one installation and current token after rotation',
    () async {
      await coordinator.start();
      provider.currentToken = 'rotated';
      provider.refresh.add('rotated');
      await Future<void>.delayed(Duration.zero);
      await coordinator.reconcile();
      expect(api.registrations.last, '$userA:rotated');
      expect(api.installations.toSet(), {'installation'});
      expect(store.owner, userA);
    },
  );

  test(
    'cold start preserves two same-owner cards and their binding epoch',
    () async {
      store.owner = userA;
      provider.boundRecipient = userA;
      provider.deliveredIds = [notification, otherNotification];
      final epoch = provider.bindingEpoch;
      await coordinator.start();
      expect(provider.deliveredIds, [notification, otherNotification]);
      expect(provider.bindingEpoch, epoch);
      expect(provider.bindings, isNot(contains(null)));
    },
  );

  test(
    'local credential restore gates startup and selective ACK preserves the other card',
    () async {
      final token = Completer<String?>();
      final restoredSessions = AuthSessionManager(
        tokenStore: _RestoringTokens(token.future),
        sessionStore: _RestoringMetadata(),
      );
      addTearDown(restoredSessions.dispose);
      final restoration = restoredSessions.restore();
      store.owner = userA;
      provider.boundRecipient = userA;
      provider.deliveredIds = [notification, otherNotification];
      final epoch = provider.bindingEpoch;
      final delivery = _DeliveredApi()..selected = {};
      coordinator.dispose();
      coordinator = PushCoordinator(
        sessions: restoredSessions,
        provider: provider,
        api: api,
        store: store,
        enabled: true,
        reconcileUnread: () async {},
        deliveryApi: delivery,
      );
      final startup = coordinator.start(initialSession: restoration);
      final resumed = coordinator.reconcile();
      await Future<void>.delayed(Duration.zero);
      expect(provider.initialized, 0);
      expect(provider.bindings, isEmpty);
      expect(provider.deliveredIds, [notification, otherNotification]);
      token.complete(_jwt(userA));
      await Future.wait([startup, resumed]);
      expect(provider.initialized, 1);
      expect(provider.bindingEpoch, epoch);
      expect(provider.deliveredIds, [notification, otherNotification]);
      delivery.selected = {
        notification,
      }; // Server confirms only the opened row read.
      await coordinator.reconcileDelivered();
      expect(provider.deliveredIds, [otherNotification]);
      expect(provider.dismissedIds, [notification]);
      expect(provider.bindingEpoch, epoch);
    },
  );

  for (final mode in [
    'guest',
    'expired',
    'incomplete',
    'inactive',
    'changed-account',
  ]) {
    test(
      'restored $mode session cannot retain previous native cards',
      () async {
        final restoredSessions = AuthSessionManager(
          tokenStore: _RestoringTokens(
            Future.value(
              mode == 'guest'
                  ? null
                  : _jwt(
                      mode == 'changed-account' ? userB : userA,
                      expired: mode == 'expired',
                      listener: mode == 'incomplete',
                    ),
            ),
          ),
          sessionStore: _RestoringMetadata(
            metadata: AuthSessionMetadata(
              accountStatus: mode == 'inactive' ? 'SUSPENDED' : 'ACTIVE',
              requiresListenerProfileChoice: mode == 'incomplete',
            ),
          ),
        );
        addTearDown(restoredSessions.dispose);
        final restoration = restoredSessions.restore();
        store.owner = userA;
        provider.boundRecipient = userA;
        provider.deliveredIds = [notification, otherNotification];
        provider.failInitialize = true;
        coordinator.dispose();
        coordinator = PushCoordinator(
          sessions: restoredSessions,
          provider: provider,
          api: api,
          store: store,
          enabled: true,
          reconcileUnread: () async {},
        );
        await coordinator.start(initialSession: restoration);
        expect(provider.boundRecipient, isNull);
        expect(provider.deliveredIds, isEmpty);
        expect(api.registrations, isEmpty);
        expect(provider.bindings.whereType<String>(), isEmpty);
      },
    );
  }

  test(
    'verified cold binding survives SDK failure but later logout clears it',
    () async {
      store.owner = userA;
      provider.boundRecipient = userA;
      provider.deliveredIds = [notification, otherNotification];
      provider.failInitialize = true;
      final epoch = provider.bindingEpoch;
      await coordinator.start();
      expect(coordinator.status, PushStatus.unavailable);
      expect(provider.deliveredIds, [notification, otherNotification]);
      expect(provider.bindingEpoch, epoch);
      expect(api.registrations, isEmpty);
      sessions.change(const AuthSession.guest());
      await Future<void>.delayed(Duration.zero);
      expect(provider.boundRecipient, isNull);
      expect(provider.deliveredIds, isEmpty);
      expect(store.reset, isTrue);
    },
  );

  for (final failure in [
    'owner',
    'reset',
    'snapshot',
    'absent-native',
    'other-native',
    'invalid-epoch',
  ]) {
    test(
      'cold $failure state fails closed without creating a binding',
      () async {
        store.owner = userA;
        provider.boundRecipient = failure == 'absent-native'
            ? null
            : failure == 'other-native'
            ? userB
            : userA;
        provider.deliveredIds = [notification, otherNotification];
        provider.failInitialize = true;
        store.failOwnerRead = failure == 'owner';
        store.failResetRead = failure == 'reset';
        provider.failSnapshot = failure == 'snapshot';
        if (failure == 'invalid-epoch') provider.bindingEpoch = 'invalid';
        await coordinator.start();
        expect(provider.deliveredIds, isEmpty);
        expect(provider.boundRecipient, isNull);
        expect(provider.bindings.whereType<String>(), isEmpty);
      },
    );
  }

  test(
    'persisted reset clears both cards even for restored same owner',
    () async {
      store.owner = userA;
      store.reset = true;
      provider.boundRecipient = userA;
      provider.deliveredIds = [notification, otherNotification];
      provider.failDelete = true;
      await coordinator.start();
      expect(provider.boundRecipient, isNull);
      expect(provider.deliveredIds, isEmpty);
      expect(provider.bindings.whereType<String>(), isEmpty);
      expect(api.registrations, isEmpty);
      expect(store.reset, isTrue);
    },
  );

  for (final stage in ['owner', 'reset', 'snapshot']) {
    test(
      'account change during cold $stage proof cannot retain or rebind old account',
      () async {
        store.owner = userA;
        provider.boundRecipient = userA;
        provider.deliveredIds = [notification, otherNotification];
        provider.failInitialize = true;
        final gate = Completer<void>();
        final reached = Completer<void>();
        if (stage == 'owner') {
          store.ownerReadGate = gate;
          store.ownerReadReached = reached;
        }
        if (stage == 'reset') {
          store.resetReadGate = gate;
          store.resetReadReached = reached;
        }
        if (stage == 'snapshot') {
          provider.snapshotGate = gate;
          provider.snapshotReached = reached;
        }
        final startup = coordinator.start();
        await reached.future;
        sessions.change(session(userB));
        expect(provider.boundRecipient, isNull);
        gate.complete();
        await startup;
        expect(provider.deliveredIds, isEmpty);
        expect(provider.bindings, isNot(contains(userA)));
        expect(api.registrations, isEmpty);
        expect(store.reset, isTrue);
      },
    );
  }

  test(
    'failed initial restore clears native state before any SDK startup',
    () async {
      provider.boundRecipient = userA;
      provider.deliveredIds = [notification, otherNotification];
      await coordinator.start(
        initialSession: Future<AuthSession>.error(StateError('local storage')),
      );
      expect(provider.deliveredIds, isEmpty);
      expect(provider.boundRecipient, isNull);
      expect(provider.initialized, 0);
      expect(coordinator.status, PushStatus.unavailable);
    },
  );

  test('restore rejection still observes later login without resume', () async {
    sessions.change(const AuthSession.guest());
    provider.boundRecipient = userA;
    await coordinator.start(
      initialSession: Future<AuthSession>.error(StateError('restore')),
    );
    expect(provider.boundRecipient, isNull);
    sessions.change(session(userA));
    await api.started.future;
    await Future<void>.delayed(Duration.zero);
    expect(api.registrations, ['$userA:first']);
    expect(provider.boundRecipient, userA);
  });

  test(
    'confirmed permission denial clears a retained same-owner cold binding',
    () async {
      store.owner = userA;
      provider.boundRecipient = userA;
      provider.deliveredIds = [notification, otherNotification];
      provider.allowed = PushPermission.denied;
      await coordinator.start();
      expect(provider.boundRecipient, isNull);
      expect(provider.deliveredIds, isEmpty);
      expect(api.registrations, isEmpty);
      expect(operations, contains('revoke:$userA'));
      expect(store.owner, isNull);
    },
  );

  test('same-session warm reconcile performs selective OS cleanup', () async {
    coordinator.dispose();
    coordinator = PushCoordinator(
      sessions: sessions,
      provider: provider,
      api: api,
      store: store,
      reconcileUnread: () async {},
      enabled: true,
      deliveryApi: _DeliveredApi(),
    );
    await coordinator.start();
    provider.deliveredIds = [notification];
    await coordinator.reconcile();
    expect(provider.dismissedIds, [notification]);
    expect(provider.boundRecipient, userA);
  });

  test(
    'warm delivered cleanup is independent of blocked token registration',
    () async {
      coordinator.dispose();
      coordinator = PushCoordinator(
        sessions: sessions,
        provider: provider,
        api: api,
        store: store,
        reconcileUnread: () async {},
        enabled: true,
        deliveryApi: _DeliveredApi(),
      );
      await coordinator.start();
      provider.deliveredIds = [notification];
      provider.tokenBlock = Completer<String?>();
      final pending = coordinator.reconcile();
      await Future<void>.delayed(Duration.zero);
      expect(provider.dismissedIds, [notification]);
      provider.tokenBlock!.complete(null);
      await pending;
      expect(coordinator.status, PushStatus.retrying);
    },
  );

  test(
    'provider initialization retries on resume after transient failure',
    () async {
      provider.failInitialize = true;
      await coordinator.start();
      expect(coordinator.status, PushStatus.unavailable);
      provider.failInitialize = false;
      await coordinator.reconcile();
      expect(provider.initialized, 2);
      expect(api.registrations, hasLength(1));
    },
  );

  for (final initialization in ['pending', 'failed']) {
    test(
      'logout during $initialization startup survives same-account restart',
      () async {
        store.owner = userA;
        Future<void>? starting;
        if (initialization == 'pending') {
          provider.initializeBlock = Completer<void>();
          starting = coordinator.start();
          await provider.initializeStarted.future;
        } else {
          provider.failInitialize = true;
          await coordinator.start();
        }
        sessions.change(const AuthSession.guest());
        await Future<void>.delayed(Duration.zero);
        expect(store.reset, isTrue);
        expect(provider.boundRecipient, isNull);
        expect(operations, contains('revoke:$userA'));
        expect(operations, isNot(contains('deleteToken')));
        coordinator.dispose();
        provider.initializeBlock?.complete();
        await starting;
        provider.initializeBlock = null;
        provider.failInitialize = false;
        provider.failDelete = true;
        sessions.change(session(userA));
        coordinator = PushCoordinator(
          sessions: sessions,
          provider: provider,
          api: api,
          store: store,
          enabled: true,
          reconcileUnread: () async {},
        );
        await coordinator.start();
        expect(api.registrations, isEmpty);
        expect(provider.tokenReads, 0);
        expect(provider.boundRecipient, isNull);
        expect(store.reset, isTrue);
        provider.failDelete = false;
        await coordinator.reconcile();
        expect(api.registrations, ['$userA:first']);
        expect(store.reset, isFalse);
      },
    );
  }

  test(
    'retry initialization observes account changes while provider is delayed',
    () async {
      provider.failInitialize = true;
      await coordinator.start();
      sessions.change(session(userB));
      await Future<void>.delayed(Duration.zero);
      provider.failInitialize = false;
      provider.initializeBlock = Completer<void>();
      final retry = coordinator.start();
      await Future<void>.delayed(Duration.zero);
      sessions.change(session(userA));
      await Future<void>.delayed(Duration.zero);
      expect(store.reset, isTrue);
      provider.initializeBlock!.complete();
      await retry;
      await coordinator.reconcile();
      expect(
        api.registrations.every((value) => value.startsWith(userA)),
        isTrue,
      );
      expect(api.registrations, isNotEmpty);
      sessions.change(const AuthSession.guest());
      await coordinator.reconcile();
      expect(operations, contains('revoke:$userA'));
      expect(provider.boundRecipient, isNull);
    },
  );

  for (final blocked in [
    session(userA, status: 'SUSPENDED'),
    session(userA, needsChoice: true),
  ]) {
    test(
      'late token cannot register after ${blocked.accountStatus}/${blocked.requiresListenerProfileChoice}',
      () async {
        provider.tokenBlock = Completer<String?>();
        final start = coordinator.start();
        await provider.tokenStarted.future;
        sessions.change(blocked);
        provider.tokenBlock!.complete('stale-token');
        await start;
        await coordinator.reconcile();
        expect(api.registrations, isEmpty);
      },
    );
  }

  for (final role in [
    'MUSICIAN',
    'VENUE',
    'STUDIO',
    'LISTENER',
    'ORGANIZER',
    'PRODUCER',
    'ADMIN',
    'OWNER',
  ]) {
    test(
      '$role active session registers and receives only its own taps',
      () async {
        sessions.change(session(userA, roles: ['ROLE_$role']));
        await coordinator.start();
        expect(api.registrations, hasLength(1));
        provider.opens.add(
          const PushTarget(
            notificationId: notification,
            recipientId: userA,
            type: 'DM_NEW_MESSAGE',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.consumePending()?.recipientId, userA);
      },
    );
  }

  test(
    'register, logout and replacement use strictly increasing durable revisions',
    () async {
      await coordinator.start();
      sessions.change(session(userB));
      await coordinator.reconcile();
      expect(api.revisions, orderedEquals([...api.revisions]..sort()));
      expect(api.revisions.toSet(), hasLength(api.revisions.length));
      expect(api.revisions.length, greaterThanOrEqualTo(3));
    },
  );

  test(
    'late registration finishes before logout revocation and next login',
    () async {
      api.block = Completer<void>();
      final start = coordinator.start();
      await api.started.future;
      sessions.change(const AuthSession.guest());
      expect(provider.boundRecipient, isNull);
      sessions.change(session(userB));
      api.block!.complete();
      await start;
      await coordinator.reconcile();
      expect(
        operations.indexOf('register:$userA'),
        lessThan(operations.indexOf('revoke:$userA')),
      );
      expect(
        operations.indexOf('revoke:$userA'),
        lessThan(operations.indexOf('deleteToken')),
      );
      expect(
        operations.indexOf('deleteToken'),
        lessThan(operations.indexOf('register:$userB')),
      );
      expect(store.owner, userB);
      expect(provider.boundRecipient, userB);
    },
  );

  test(
    'failed logout provider reset stays durable and blocks account reuse',
    () async {
      await coordinator.start();
      provider.failDelete = true;
      sessions.change(session(userB));
      await coordinator.reconcile();
      expect(store.reset, isTrue);
      expect(api.registrations.every((item) => item.startsWith(userA)), isTrue);
      provider.failDelete = false;
      await coordinator.reconcile();
      expect(store.reset, isFalse);
      expect(store.owner, userB);
    },
  );

  test(
    'logout storage failure still attempts server and token revocation',
    () async {
      await coordinator.start();
      store.failResetWrite = true;
      sessions.change(const AuthSession.guest());
      await coordinator.reconcile();
      expect(operations, contains('revoke:$userA'));
      expect(operations, contains('deleteToken'));
      expect(provider.boundRecipient, isNull);
      expect(store.owner, isNull);
    },
  );

  test(
    'logout revision failure still invalidates the provider token',
    () async {
      await coordinator.start();
      store.failMutation = true;
      sessions.change(const AuthSession.guest());
      await coordinator.reconcile();
      expect(operations, contains('deleteToken'));
      expect(store.owner, isNull);
      expect(provider.boundRecipient, isNull);
    },
  );

  test(
    'combined reset-write and token failure fences same-account relogin',
    () async {
      await coordinator.start();
      store.failResetWrite = true;
      provider.failDelete = true;
      api.failRevoke = true;
      sessions.change(const AuthSession.guest());
      await coordinator.reconcile();
      expect(operations, contains('revoke:$userA'));
      expect(operations, contains('deleteToken'));
      sessions.change(session(userA));
      await coordinator.reconcile();
      expect(api.registrations, hasLength(1));
      expect(provider.boundRecipient, isNull);
      expect(coordinator.status, PushStatus.retrying);
      store.failResetWrite = false;
      provider.failDelete = false;
      api.failRevoke = false;
      await coordinator.reconcile();
      expect(api.registrations, hasLength(2));
      expect(store.reset, isFalse);
      expect(store.owner, userA);
      expect(provider.boundRecipient, userA);
    },
  );

  test(
    'failed reset never binds a replacement account before registration',
    () async {
      await coordinator.start();
      provider.failDelete = true;
      sessions.change(session(userB));
      await coordinator.reconcile();
      expect(api.registrations, hasLength(1));
      expect(provider.boundRecipient, isNull);
      expect(provider.bindings, isNot(contains(userB)));
    },
  );

  test(
    'restored reset remains unbound while provider invalidation fails',
    () async {
      store.owner = userA;
      store.reset = true;
      provider.failDelete = true;
      await coordinator.start();
      expect(api.registrations, isEmpty);
      expect(provider.boundRecipient, isNull);
      expect(coordinator.status, PushStatus.retrying);
      expect(provider.bindings, isNot(contains(userA)));
    },
  );

  test(
    'independent native reset fences same-account restart after failed logout',
    () async {
      const channel = MethodChannel('com.soundconnect/push');
      final preferences = _Preferences();
      var durableNativeReset = false;
      var revision = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'pushResetRequired':
                return durableNativeReset;
              case 'setPushResetRequired':
                durableNativeReset =
                    (call.arguments as Map)['required'] as bool;
                return null;
              case 'nextMutation':
                return {
                  'installationId': notification,
                  'clientRevision': ++revision,
                };
              default:
                throw StateError('Unexpected method');
            }
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      coordinator.dispose();
      coordinator = PushCoordinator(
        sessions: sessions,
        provider: provider,
        api: api,
        store: SharedPreferencesPushInstallationStore(preferences: preferences),
        enabled: true,
        reconcileUnread: () async {},
      );
      await coordinator.start();
      expect(api.registrations, hasLength(1));
      preferences.failResetWrite = true;
      provider.failDelete = true;
      api.failRevoke = true;
      sessions.change(const AuthSession.guest());
      await coordinator.reconcile();
      expect(durableNativeReset, isTrue);
      expect(preferences.reset, isFalse);
      expect(provider.boundRecipient, isNull);
      coordinator.dispose();
      sessions.change(session(userA));
      coordinator = PushCoordinator(
        sessions: sessions,
        provider: provider,
        api: api,
        store: SharedPreferencesPushInstallationStore(preferences: preferences),
        enabled: true,
        reconcileUnread: () async {},
      );
      await coordinator.start();
      expect(api.registrations, hasLength(1));
      expect(provider.boundRecipient, isNull);
      expect(coordinator.status, PushStatus.retrying);
      preferences.failResetWrite = false;
      provider.failDelete = false;
      await coordinator.reconcile();
      expect(api.registrations, hasLength(2));
      expect(durableNativeReset, isFalse);
      expect(preferences.reset, isFalse);
      expect(provider.boundRecipient, userA);
    },
  );

  test(
    'restored owner reset restores native binding after token invalidation',
    () async {
      store.owner = userB;
      await coordinator.start();
      expect(operations, contains('deleteToken'));
      expect(provider.boundRecipient, userA);
      expect(api.registrations.last, '$userA:first');
    },
  );

  test(
    'expired restored session clears previous installation ownership',
    () async {
      store.owner = userA;
      sessions.change(const AuthSession.guest());
      await coordinator.start();
      expect(operations, contains('deleteToken'));
      expect(store.owner, isNull);
      expect(api.registrations, isEmpty);
    },
  );

  test(
    'terminated tap waits for matching auth; duplicate and other-account taps ignored',
    () async {
      sessions.change(const AuthSession.guest());
      provider.initial = const PushTarget(
        notificationId: notification,
        recipientId: userA,
        type: 'DM_NEW_MESSAGE',
      );
      await coordinator.start();
      expect(coordinator.consumePending(), isNull);
      sessions.change(session(userA));
      await coordinator.reconcile();
      expect(coordinator.consumePending()?.notificationId, notification);
      provider.opens.add(provider.initial!);
      provider.opens.add(
        const PushTarget(
          notificationId: 'other',
          recipientId: userB,
          type: 'DM_NEW_MESSAGE',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.consumePending(), isNull);
    },
  );

  for (final type in {
    ...PushTarget.tableTypes,
    ...PushTarget.overthinkingTypes,
  }) {
    for (final cold in [true, false]) {
      test('$type ${cold ? "cold" : "warm"} exact owner and dedup', () async {
        final target = PushTarget(
          notificationId: notification,
          recipientId: userA,
          type: type,
        );
        if (cold) {
          sessions.change(const AuthSession.guest());
          provider.initial = target;
        }
        await coordinator.start();
        if (cold) {
          expect(coordinator.consumePending(), isNull);
          sessions.change(session(userA));
          await coordinator.reconcile();
        } else {
          provider.opens.add(target);
          await Future<void>.delayed(Duration.zero);
        }
        expect(coordinator.consumePending()?.notificationId, notification);
        provider.opens.add(target);
        provider.opens.add(
          PushTarget(
            notificationId: otherNotification,
            recipientId: userB,
            type: type,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.consumePending(), isNull);
        sessions.change(session(userB));
        await coordinator.reconcile();
        provider.opens.add(
          PushTarget(
            notificationId: otherNotification,
            recipientId: userA,
            type: type,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.consumePending(), isNull);
      });
    }
  }

  test(
    'foreground payload reconciles only its authenticated recipient',
    () async {
      await coordinator.start();
      provider.messages.add(
        const PushTarget(
          notificationId: notification,
          recipientId: userB,
          type: 'DM_NEW_MESSAGE',
        ),
      );
      provider.messages.add(
        const PushTarget(
          notificationId: notification,
          recipientId: userA,
          type: 'DM_NEW_MESSAGE',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(reconciliations, 1);
    },
  );

  test('malformed navigation payload is rejected', () {
    expect(
      PushTarget.parse({
        'notificationId': notification,
        'recipientId': userA,
        'type': 'DM_NEW_MESSAGE',
        'conversationId': '../../profile',
      }),
      isNull,
    );
    expect(
      PushTarget.parse({
        'notificationId': notification,
        'recipientId': userA,
        'type': 'DM_NEW_MESSAGE',
      })?.recipientId,
      userA,
    );
  });

  test(
    'native installation identity retries failed storage then caches success',
    () async {
      const channel = MethodChannel('com.soundconnect/push');
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'installationId');
            if (++calls == 1) {
              throw PlatformException(code: 'temporarily_unavailable');
            }
            return notification;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final nativeStore = SharedPreferencesPushInstallationStore();
      await expectLater(
        nativeStore.installationId(),
        throwsA(isA<PlatformException>()),
      );
      expect(await nativeStore.installationId(), notification);
      expect(await nativeStore.installationId(), notification);
      expect(calls, 2);
    },
  );

  test(
    'native revision allocation validates range and updates rotated identity',
    () async {
      const channel = MethodChannel('com.soundconnect/push');
      var revision = 1;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'nextMutation');
            return {'installationId': notification, 'clientRevision': revision};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final store = SharedPreferencesPushInstallationStore();
      final mutation = await store.nextMutation();
      expect(mutation.clientRevision, 1);
      expect(await store.installationId(), notification);
      revision = 9007199254740992;
      await expectLater(store.nextMutation(), throwsStateError);
    },
  );

  test(
    'completing onboarding registers without token change or revocation',
    () async {
      sessions.change(session(userA, needsChoice: true));
      await coordinator.start();
      expect(api.registrations, isEmpty);
      sessions.change(session(userA));
      await coordinator.reconcile();
      expect(api.registrations, isNotEmpty);
      expect(
        operations.where((operation) => operation.startsWith('revoke:')),
        isEmpty,
      );
    },
  );
}

class _Sessions extends AuthSessionManager {
  _Sessions() : super(tokenStore: _Tokens(), sessionStore: _SessionStore());
  AuthSession value = const AuthSession.guest();
  @override
  AuthSession get session => value;
  void change(AuthSession next) {
    value = next;
    notifyListeners();
  }
}
