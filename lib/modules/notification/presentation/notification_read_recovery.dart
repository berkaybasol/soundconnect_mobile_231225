import 'dart:async';

import 'package:flutter/foundation.dart';

/// An explicit retry belongs to one visible target, never to a timer or resume.
/// A visibility revision also fences responses that arrive after hide + return.
class NotificationReadRecovery extends ChangeNotifier {
  NotificationReadRecovery({
    required bool Function() isCurrent,
    required Future<bool> Function() acknowledge,
    required Future<void> Function() confirm,
  }) : _isCurrent = isCurrent,
       _acknowledge = acknowledge,
       _confirm = confirm;

  final bool Function() _isCurrent;
  final Future<bool> Function() _acknowledge;
  final Future<void> Function() _confirm;
  Object? _owner;
  bool Function()? _visible;
  int _revision = 0;
  bool _attempted = false;
  bool _busy = false;
  bool _failed = false;
  bool _needsRecovery = false;
  bool _confirmed = false;

  bool get attempted => _attempted;
  bool get busy => _busy;

  bool _current(Object owner) =>
      identical(_owner, owner) && _isCurrent() && _visible?.call() == true;

  bool showsRetryFor(Object owner) =>
      !_confirmed && _needsRecovery && (_failed || busy) && _current(owner);

  void present(Object owner, bool Function() visible) {
    if (!_isCurrent() || !visible() || _confirmed) return;
    // Several success markers can exist on the same route. Only one owns UI.
    if (_owner != null && !identical(_owner, owner)) return;
    _owner = owner;
    _visible = visible;
    if (!attempted) unawaited(_attempt(owner));
  }

  void suspend(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _visible = null;
    _revision++;
    if (attempted && !_confirmed) {
      _failed = true;
      _needsRecovery = true;
    }
  }

  void retry(Object owner) {
    if (!_failed || busy || _confirmed || !_current(owner)) return;
    unawaited(_attempt(owner));
  }

  Future<void> _attempt(Object owner) async {
    if (busy || _confirmed || !_current(owner)) return;
    final revision = _revision;
    _attempted = true;
    _busy = true;
    _failed = false;
    notifyListeners();
    var success = false;
    try {
      success = await _acknowledge();
    } catch (_) {
      // Unexpected transports follow the same explicit recovery path as Result.
    }
    _busy = false;
    if (revision != _revision || !_current(owner)) {
      // The server might have accepted the request, but this old view may not
      // project it. A later explicit, idempotent retry can confirm that row.
      _failed = true;
      _needsRecovery = true;
      notifyListeners();
      return;
    }
    _failed = !success;
    _needsRecovery = !success;
    _confirmed = success;
    notifyListeners();
    if (!success) return;
    try {
      await _confirm();
    } catch (_) {
      // ACK already succeeded. A count refresh failure must not repeat it.
    }
  }
}
