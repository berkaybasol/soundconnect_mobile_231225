import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_session.dart';
import '../auth/auth_session_manager.dart';
import 'push_device_api.dart';
import 'push_delivered_reconciler.dart';
import 'push_delivery_api.dart';
import 'push_installation_store.dart';
import 'push_provider.dart';

enum PushStatus { disabled, unavailable, starting, ready, retrying }

/// Serializes registration, rotation and logout so a delayed registration can
/// never run after its revocation. All UI/navigation reads remain account-fenced.
class PushCoordinator extends ChangeNotifier {
  PushCoordinator({
    required AuthSessionManager sessions,
    required PushProvider provider,
    required PushDeviceApi api,
    required PushInstallationStore store,
    required Future<void> Function() reconcileUnread,
    PushDeliveryApi? deliveryApi,
    this.enabled = const bool.fromEnvironment('SOUNDCONNECT_PUSH_ENABLED'),
  }) : _sessions = sessions,
       _provider = provider,
       _api = api,
       _store = store,
       _reconcileUnread = reconcileUnread,
       _delivered = deliveryApi != null && provider is PushDeliveredProvider
           ? PushDeliveredReconciler(
               sessions,
               provider as PushDeliveredProvider,
               deliveryApi,
             )
           : null;

  final AuthSessionManager _sessions;
  final PushProvider _provider;
  final PushDeviceApi _api;
  final PushInstallationStore _store;
  final Future<void> Function() _reconcileUnread;
  final PushDeliveredReconciler? _delivered;
  final bool enabled;
  PushStatus status = PushStatus.disabled;
  PushPermission permission = PushPermission.notDetermined;
  int foregroundRevision = 0;
  PushTarget? _pending;
  PushTarget? get pending => _pending;
  AuthSession _observed = const AuthSession.guest();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final Set<String> _openedIds = {};
  Future<void> _tail = Future<void>.value();
  Future<void>? _starting;
  Timer? _retry;
  int _retryAttempt = 0;
  bool _ready = false;
  bool _resetPending = false;
  bool _disposed = false;
  bool _observingSession = false;

  /// The app supplies its already-started local credential restoration on the
  /// first call. Concurrent resume/reconcile calls share this startup operation.
  Future<void> start({Future<AuthSession>? initialSession}) {
    final existing = _starting;
    if (existing != null) return existing;
    final operation = _start(initialSession: initialSession);
    _starting = operation;
    return operation.whenComplete(() {
      if (!_ready && identical(_starting, operation)) _starting = null;
    });
  }

  Future<void> _start({Future<AuthSession>? initialSession}) async {
    if (!enabled) return;
    if (!_provider.supported) {
      _setStatus(PushStatus.unavailable);
      return;
    }
    _setStatus(PushStatus.starting);
    var restoreFailed = false;
    if (initialSession != null) {
      try {
        // Secure token/metadata reads already drive the app's initial session.
        // Do not reinterpret their temporary guest value as an actual logout,
        // or impose a new short timeout that discards cards on slower devices.
        await initialSession;
      } catch (_) {
        restoreFailed = true;
      }
    }
    if (_disposed) return;
    _observed = _sessions.session;
    if (!_observingSession) {
      _sessions.addListener(_onSessionChanged);
      _observingSession = true;
    }
    try {
      if (restoreFailed) {
        // Observe later login even if initial restoration itself failed.
        await _bindRecipient(null);
        _setStatus(PushStatus.unavailable);
        return;
      }
      await _prepareNativeStartup();
      if (_disposed) return;
      await _provider.initialize();
      if (_disposed) return;
      _ready = true;
      _subscriptions.add(
        _provider.tokenRefresh.listen(
          (_) => unawaited(reconcile()),
          onError: (Object _) => _scheduleRetry(),
        ),
      );
      _subscriptions.add(
        _provider.opened.listen(
          _receiveOpen,
          onError: (Object _) => _scheduleRetry(),
        ),
      );
      _subscriptions.add(
        _provider.foreground.listen((target) {
          if (_matchesRecipient(target)) {
            foregroundRevision++;
            if (_sessions.session.isActive) unawaited(_reconcileUnread());
            _notify();
          }
        }, onError: (Object _) => _scheduleRetry()),
      );
      try {
        final initial = await _provider.initialMessage();
        if (initial != null) _receiveOpen(initial);
      } catch (_) {
        // A failed launch-message lookup must not block device registration.
      }
      await reconcile();
    } catch (_) {
      // Never log provider exceptions: SDK errors may include registration IDs.
      _setStatus(PushStatus.unavailable);
    }
  }

  Future<void> _prepareNativeStartup() async {
    final captured = _sessions.session;
    var retainExisting = false;
    try {
      final provider = _provider;
      if (_canRegister(captured) &&
          PushTarget.isUuid(captured.userId) &&
          !_resetPending &&
          provider is PushDeliveredProvider) {
        final owner = await _store.ownerId();
        if (_isCurrent(captured) && owner == captured.userId) {
          final reset = await _store.resetRequired();
          if (_isCurrent(captured) && !reset && !_resetPending) {
            final snapshot = await (provider as PushDeliveredProvider)
                .deliveredSnapshot(captured.userId!);
            final contextStore = _store;
            final context = contextStore is PushBindingContextStore
                ? await (contextStore as PushBindingContextStore)
                      .bindingContext()
                : null;
            final contextMatches =
                snapshot != null &&
                (context == _bindingContext(captured, snapshot.bindingEpoch) ||
                    (context == null && !captured.isVenueApplicationSession));
            retainExisting =
                contextMatches &&
                _isCurrent(captured) &&
                !_resetPending &&
                snapshot.recipientId == captured.userId!.toLowerCase() &&
                PushTarget.isUuid(snapshot.bindingEpoch);
          }
        }
      }
    } catch (_) {
      // Unreadable ownership/reset/native state is never proof of continuity.
    }
    if (!_disposed && !retainExisting) await _bindRecipient(null);
    // Retention is read-only. Only a successful current device registration can
    // create a positive binding; never reopen an absent or mismatched identity.
  }

  Future<void> requestPermission() async {
    await start();
    if (!_ready || !_canRegister(_sessions.session)) return;
    try {
      permission = await _provider.permission(request: true);
      _notify();
      await reconcile();
    } catch (_) {
      _scheduleRetry();
    }
  }

  Future<void> reconcile() {
    if (_disposed) return Future.value();
    if (!_ready) return start();
    final session = _sessions.session;
    // An existing native binding can reconcile even when FCM/token registration
    // is slow or unavailable. Both operations independently fence the session.
    return Future.wait<void>([
      _enqueue(() => _registerCurrent(session)),
      reconcileDelivered(),
    ]).then((_) {});
  }

  Future<void> reconcileDelivered() => _ready && !_disposed
      ? _delivered?.reconcile() ?? Future.value()
      : Future.value();

  void _onSessionChanged() {
    final previous = _observed;
    final current = _sessions.session;
    _observed = current;
    if (previous.token == current.token && previous.userId == current.userId) {
      if (previous.accountStatus != current.accountStatus ||
          previous.sessionScope != current.sessionScope ||
          previous.applicationId != current.applicationId ||
          previous.requiresListenerProfileChoice !=
              current.requiresListenerProfileChoice) {
        _clearNativeRecipient();
        unawaited(reconcile());
        _notify();
      }
      return;
    }
    _retry?.cancel();
    _clearNativeRecipient();
    _retryAttempt = 0;
    if (previous.isAuthenticated) {
      // Fence immediately even if persisting the reset marker fails later.
      _resetPending = true;
      _pending = null;
      _openedIds.clear();
      unawaited(_enqueue(() => _revoke(previous)));
    }
    if (_pending != null &&
        current.isAuthenticated &&
        !_matchesRecipient(_pending!)) {
      _pending = null;
    }
    unawaited(reconcile());
    _notify();
  }

  Future<void> _registerCurrent(AuthSession captured) async {
    if (!_isCurrent(captured)) return;
    try {
      if (!_canRegister(captured)) {
        await _bindRecipient(null);
      }
      if (!_isCurrent(captured)) return;
      final storedOwner = await _store.ownerId();
      final needsReset = await _store.resetRequired();
      // Covers process death during logout and restore after an expired JWT.
      // Never reopen native delivery while a previous token still needs reset.
      if (_resetPending ||
          needsReset ||
          (storedOwner != null && storedOwner != captured.userId)) {
        await _bindRecipient(null);
        await _resetToken();
      }
      if (!_isCurrent(captured)) return;
      permission = await _provider.permission();
      if (!_isCurrent(captured)) return;
      if (!_canRegister(captured)) {
        if (captured.isAuthenticated && storedOwner == captured.userId) {
          final mutation = await _store.nextMutation();
          await _api.revoke(
            session: captured,
            installationId: mutation.installationId,
            clientRevision: mutation.clientRevision,
          );
          await _store.setOwnerId(null);
        }
        _setStatus(PushStatus.ready);
        return;
      }
      if (!permission.canDeliver) {
        await _bindRecipient(null);
        if (!_isCurrent(captured)) return;
        if (storedOwner == captured.userId) {
          final mutation = await _store.nextMutation();
          await _api.revoke(
            session: captured,
            installationId: mutation.installationId,
            clientRevision: mutation.clientRevision,
          );
          await _store.setOwnerId(null);
        }
        _setStatus(PushStatus.ready);
        return;
      }
      final token = await _provider.token();
      if (!_isCurrent(captured)) return;
      if (token == null || token.isEmpty) {
        _scheduleRetry();
        return;
      }
      // Persist before the request: a timeout can still commit on the server.
      await _store.setOwnerId(captured.userId);
      if (!_isCurrent(captured)) return;
      final mutation = await _store.nextMutation();
      if (!_isCurrent(captured)) return;
      await _api.register(
        session: captured,
        installationId: mutation.installationId,
        clientRevision: mutation.clientRevision,
        token: token,
        platform: _provider.platform,
        permission: permission,
      );
      if (!_isCurrent(captured)) return;
      // Token invalidation also clears native delivered notifications/binding.
      // Restore the current recipient only after the replacement is registered.
      await _bindRecipient(captured.userId);
      if (!_isCurrent(captured)) return;
      final contextStore = _store;
      final provider = _provider;
      if (contextStore is PushBindingContextStore &&
          provider is PushDeliveredProvider) {
        final snapshot = await (provider as PushDeliveredProvider)
            .deliveredSnapshot(captured.userId!);
        if (!_isCurrent(captured)) return;
        if (snapshot == null ||
            snapshot.recipientId != captured.userId ||
            !PushTarget.isUuid(snapshot.bindingEpoch)) {
          throw StateError('Native binding unavailable');
        }
        await (contextStore as PushBindingContextStore).setBindingContext(
          _bindingContext(captured, snapshot.bindingEpoch),
        );
        if (!_isCurrent(captured)) return;
      }
      _retryAttempt = 0;
      _retry?.cancel();
      _setStatus(PushStatus.ready);
      await reconcileDelivered();
    } catch (_) {
      if (_isCurrent(captured)) _scheduleRetry();
    }
  }

  Future<void> _revoke(AuthSession previous) async {
    _resetPending = true;
    // Neither the durable logout fence nor server revocation depends on Firebase
    // initialization. A process can stop while initialization is pending/failed.
    await _persistResetMarker();
    try {
      final mutation = await _store.nextMutation();
      await _api.revoke(
        session: previous,
        installationId: mutation.installationId,
        clientRevision: mutation.clientRevision,
      );
    } catch (_) {
      // Storage/server revocation failure must not prevent token invalidation.
    }
    // The SDK itself may be unavailable; its token reset will be retried once
    // initialization succeeds, including after a process restart.
    if (!_ready) return;
    try {
      await _resetToken(persistMarker: false);
    } catch (_) {
      // Keep both the memory fence and any durable marker until recovery.
      _scheduleRetry();
    }
  }

  Future<void> _persistResetMarker() async {
    try {
      await _store.setResetRequired(true);
    } catch (_) {
      // Invalidation is an independent boundary and must still be attempted.
      // _resetPending fences this process if storage and invalidation both fail.
    }
  }

  Future<void> _resetToken({bool persistMarker = true}) async {
    _resetPending = true;
    if (persistMarker) await _persistResetMarker();
    await _provider.deleteToken();
    await _store.setOwnerId(null);
    await _store.setResetRequired(false);
    _resetPending = false;
  }

  String _bindingContext(AuthSession session, String epoch) =>
      '${session.userId}|${session.isVenueApplicationSession ? 'APPLICATION:${session.applicationId}' : 'GENERAL'}|$epoch';

  Future<void> _bindRecipient(String? recipientId) async {
    final provider = _provider;
    if (provider is PushRecipientBindingProvider) {
      await (provider as PushRecipientBindingProvider).bindRecipient(
        recipientId,
      );
    }
  }

  void _clearNativeRecipient() {
    // Dispatch immediately, even while an old network request is in flight.
    unawaited(_bindRecipient(null).catchError((Object _) => _scheduleRetry()));
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _tail.then((_) async {
      if (!_disposed) await action();
    });
    _tail = operation.catchError((Object _) {
      _scheduleRetry();
    });
    return _tail;
  }

  bool _canRegister(AuthSession session) =>
      session.canRegisterPush &&
      (!session.isVenueApplicationSession || _provider.platform == 'ANDROID');

  bool _isCurrent(AuthSession captured) =>
      !_disposed &&
      _sessions.session.userId == captured.userId &&
      _sessions.session.token == captured.token &&
      _sessions.session.accountStatus == captured.accountStatus &&
      _sessions.session.sessionScope == captured.sessionScope &&
      _sessions.session.applicationId == captured.applicationId &&
      _sessions.session.requiresListenerProfileChoice ==
          captured.requiresListenerProfileChoice;
  bool _matchesRecipient(PushTarget target) =>
      _canRegister(_sessions.session) &&
      (!_sessions.session.isVenueApplicationSession ||
          target.isVenueApplication) &&
      _sessions.session.userId?.toLowerCase() ==
          target.recipientId.toLowerCase();

  void _receiveOpen(PushTarget target) {
    if (_disposed || _openedIds.contains(target.notificationId)) return;
    if (_sessions.session.isAuthenticated && !_matchesRecipient(target)) return;
    _pending = target;
    _notify();
  }

  PushTarget? consumePending() {
    final target = _pending;
    if (target == null ||
        !_matchesRecipient(target) ||
        _sessions.session.requiresListenerProfileChoice) {
      return null;
    }
    _pending = null;
    _openedIds.add(target.notificationId);
    if (_openedIds.length > 100) _openedIds.remove(_openedIds.first);
    return target;
  }

  void _scheduleRetry() {
    if (_disposed || !_ready) return;
    _setStatus(PushStatus.retrying);
    _retry?.cancel();
    // Bounded automatic retries; resume, token refresh, and settings retry later.
    if (_retryAttempt >= 6) return;
    final seconds = 5 * (1 << _retryAttempt++);
    _retry = Timer(Duration(seconds: seconds), () => unawaited(reconcile()));
  }

  void _setStatus(PushStatus value) {
    status = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _delivered?.dispose();
    _retry?.cancel();
    _sessions.removeListener(_onSessionChanged);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
