import '../auth/auth_session.dart';
import '../auth/auth_session_manager.dart';
import 'push_delivery_api.dart';
import 'push_provider.dart';

/// The OS tray is a projection, never a read acknowledgement. Only a successful
/// authenticated snapshot comparison may remove selected delivered alerts.
class PushDeliveredReconciler {
  PushDeliveredReconciler(this._sessions, this._provider, this._api);
  final AuthSessionManager _sessions;
  final PushDeliveredProvider _provider;
  final PushDeliveryApi _api;
  Future<void>? _inFlight;
  bool _again = false;
  bool _disposed = false;

  Future<void> reconcile() {
    if (_disposed) return Future.value();
    _again = true;
    return _inFlight ??= _drain().whenComplete(() => _inFlight = null);
  }

  Future<void> _drain() async {
    while (_again && !_disposed) {
      _again = false;
      final captured = _sessions.session;
      if (!captured.canRegisterPush) return;
      try {
        final snapshot = await _provider.deliveredSnapshot(captured.userId!);
        if (!_current(captured) || snapshot == null) continue;
        if (snapshot.recipientId != captured.userId!.toLowerCase() ||
            !PushTarget.isUuid(snapshot.bindingEpoch) ||
            snapshot.notificationIds.isEmpty ||
            snapshot.notificationIds.length > 100 ||
            snapshot.notificationIds.any((id) => !PushTarget.isUuid(id))) {
          continue;
        }
        final dismissed = await _api.dismissedIds(
          captured,
          snapshot.notificationIds,
        );
        if (!_current(captured)) continue;
        // Defense in depth: even another implementation of the API must not
        // cancel a new notification that wasn't in this native snapshot.
        final requested = snapshot.notificationIds.toSet();
        final selected = dismissed.where(requested.contains).toList();
        if (selected.isNotEmpty) {
          await _provider.dismissDelivered(snapshot, selected);
        }
      } catch (_) {
        // Offline/malformed responses preserve the tray. Next resume/ACK retries.
        // Provider/network errors can contain credentials; never log them.
      }
    }
  }

  bool _current(AuthSession captured) =>
      !_disposed &&
      _sessions.session.userId == captured.userId &&
      _sessions.session.token == captured.token &&
      _sessions.session.canRegisterPush &&
      _sessions.session.sessionScope == captured.sessionScope &&
      _sessions.session.applicationId == captured.applicationId &&
      !_sessions.session.requiresListenerProfileChoice;

  void dispose() => _disposed = true;
}
