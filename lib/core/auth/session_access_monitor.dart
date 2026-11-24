import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_session_manager.dart';

enum SessionAccessState { ready, checking, unavailable }

/// The HTTP security layer retires rejected credentials. This monitor governs
/// when the app may display the private view and bounds detection on idle pages.
class SessionAccessMonitor extends ChangeNotifier {
  SessionAccessMonitor(this.sessions) {
    sessions.addListener(_onSession);
    _onSession();
  }

  final AuthSessionManager sessions;
  static const interval = Duration(seconds: 35);
  static const timeout = Duration(seconds: 10);
  SessionAccessState _state = SessionAccessState.ready;
  SessionAccessState get state => _state;
  bool get blocksContent => state != SessionAccessState.ready;
  bool _foreground = true;
  bool _inFlight = false;
  int _generation = 0;
  String? _token;
  int? _revision;
  Timer? _nextCheck;
  Timer? _socketCooldown;

  void _onSession() {
    final token = sessions.session.token;
    final revision = sessions.credentialRevision;
    if (_token == token && _revision == revision) return;
    _token = token;
    _revision = revision;
    _reset();
    if (token == null || sessions.verifyAccess == null) {
      _setState(SessionAccessState.ready);
      return;
    }
    _setState(SessionAccessState.checking);
    if (_foreground) unawaited(check());
  }

  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    _reset();
    if (_token == null || sessions.verifyAccess == null) return;
    _setState(SessionAccessState.checking);
    if (value) unawaited(check());
  }

  void onSocketLoss() {
    if (!_foreground ||
        _inFlight ||
        _socketCooldown != null ||
        _token == null) {
      return;
    }
    _socketCooldown = Timer(
      const Duration(seconds: 5),
      () => _socketCooldown = null,
    );
    unawaited(check());
  }

  Future<void> check() async {
    final probe = sessions.verifyAccess;
    final session = sessions.session;
    final revision = sessions.credentialRevision;
    if (probe == null || session.token == null || !_foreground || _inFlight) {
      return;
    }
    final generation = _generation;
    _nextCheck?.cancel();
    _inFlight = true;
    if (state == SessionAccessState.unavailable) {
      _setState(SessionAccessState.checking);
    }
    try {
      await probe(session, revision).timeout(timeout);
      if (generation == _generation) _setState(SessionAccessState.ready);
    } catch (_) {
      if (generation == _generation) _setState(SessionAccessState.unavailable);
    } finally {
      if (generation == _generation) {
        _inFlight = false;
        _nextCheck = Timer(interval, check);
      }
    }
  }

  void _reset() {
    _generation++;
    _inFlight = false;
    _nextCheck?.cancel();
    _socketCooldown?.cancel();
    _socketCooldown = null;
  }

  void _setState(SessionAccessState value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    sessions.removeListener(_onSession);
    _reset();
    super.dispose();
  }
}
