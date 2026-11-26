import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import 'analytics_consent_store.dart';
import 'analytics_live_activity.dart';
import 'analytics_measurement.dart';

export 'analytics_consent_store.dart' show ConsentChoice;

class AnalyticsConsentController extends ChangeNotifier {
  AnalyticsConsentController(
    this._sessions,
    this._store,
    this._measurement, {
    this.liveActivity,
  });
  final AuthSessionManager _sessions;
  final AnalyticsConsentStore _store;
  final AnalyticsMeasurement _measurement;
  final AnalyticsLiveActivity? liveActivity;
  AnalyticsPreference _preference = const AnalyticsPreference(
    ConsentChoice.undecided,
  );
  ConsentChoice get choice => _preference.choice;
  bool get isMember => _sessions.session.isAuthenticated;
  bool get canChooseForSubject => _supported;
  int get subjectRevision => _subjectRevision;
  bool get busy => !_started || _saving || (_loading && !_hasSnapshot);
  String? get error => _error;

  int _subjectRevision = 0;
  int _credentialRevision = -1;
  AuthSession? _subject;
  bool _loading = false;
  bool _saving = false;
  bool _hasSnapshot = false;
  int _request = 0;
  bool _started = false;
  bool _foreground = true;
  bool _retryRead = false;
  int? _pendingDenialRevision;
  int _denialRetryIndex = 0;
  static const _denialRetrySeconds = [2, 5, 15, 30, 60];
  String? _error;
  Timer? _recheck;

  void _stop() {
    liveActivity?.stop();
    _measurement.stop();
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _sessions.addListener(_onSessionChanged);
    await Future.wait([
      _store.clearLegacyObservations().catchError((Object _) {}),
      _loadSubject(),
    ]);
  }

  bool _current(int revision) =>
      _started &&
      revision == _subjectRevision &&
      _credentialRevision == _sessions.credentialRevision;

  bool get _supported =>
      !_sessions.session.isSuspendedNotice &&
      (!isMember ||
          (_sessions.session.isActive &&
              !_sessions.session.isAdmin &&
              _sessions.session.userId != null));

  void _onSessionChanged() {
    final next = _sessions.session;
    if (_credentialRevision == _sessions.credentialRevision &&
        next.token == _subject?.token &&
        next.accountStatus == _subject?.accountStatus &&
        next.isAdmin == _subject?.isAdmin &&
        setEquals(next.normalizedRoles, _subject?.normalizedRoles)) {
      return;
    }
    unawaited(_loadSubject());
  }

  Future<void> _loadSubject() {
    _subjectRevision++;
    _subject = _sessions.session;
    _credentialRevision = _sessions.credentialRevision;
    _preference = const AnalyticsPreference(ConsentChoice.undecided);
    _loading = false;
    _saving = false;
    _hasSnapshot = false;
    _retryRead = false;
    _pendingDenialRevision = null;
    _denialRetryIndex = 0;
    _error = null;
    _recheck?.cancel();
    _stop();
    return refresh();
  }

  void setForeground(bool active) {
    if (_foreground == active) return;
    _foreground = active;
    if (!active) {
      _recheck?.cancel();
      if (_loading && !_saving) {
        ++_request;
        _loading = false;
        _retryRead = false;
      }
      liveActivity?.stop();
      _measurement.suspend();
    } else if (_started) {
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    if (!_started || !_supported) {
      if (_started) notifyListeners();
      return;
    }
    if (_loading) {
      _retryRead = true;
      return;
    }
    final subject = _subjectRevision;
    final request = ++_request;
    bool currentRead() => _current(subject) && request == _request;
    _recheck?.cancel();
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final session = _sessions.session;
      AnalyticsPreference current;
      if (session.isAuthenticated) {
        final account = session.userId!;
        final credential = _credentialRevision;
        final pending =
            _pendingDenialRevision ?? await _store.pendingDenial(account);
        if (!currentRead()) return;
        _pendingDenialRevision = pending;
        if (pending != null && _preference.choice != ConsentChoice.denied) {
          _preference = AnalyticsPreference(
            ConsentChoice.denied,
            revision: pending,
          );
          _stop();
        }
        current = await _store.member(session, credential);
        if (!currentRead()) return;
        if (pending != null) {
          if (current.choice != ConsentChoice.denied) {
            if (pending != current.revision) {
              // A newer choice requires user input. Keep the durable local veto.
              _pendingDenialRevision = null;
              _preference = AnalyticsPreference(
                ConsentChoice.denied,
                revision: current.revision,
              );
              throw StateError('Preference changed on another device');
            }
            current = await _store.member(
              session,
              credential,
              allow: false,
              revision: pending,
            );
            if (!currentRead()) return;
            if (current.choice != ConsentChoice.denied) {
              throw StateError('Withdrawal was not acknowledged');
            }
          }
          await _store.setPendingDenial(account, null);
          if (!currentRead()) return;
          _pendingDenialRevision = null;
          _denialRetryIndex = 0;
        }
      } else {
        current = await _store.guest();
      }
      if (currentRead()) _apply(current);
    } catch (_) {
      if (currentRead()) {
        _stop();
        _error = 'Tercih doğrulanamadı. Bağlantını kontrol edip tekrar dene.';
      }
    } finally {
      if (currentRead()) _finish(subject);
    }
  }

  Future<void> choose(bool allow, {int? expectedSubject}) async {
    final subject = _subjectRevision;
    if (busy ||
        !_supported ||
        !_current(subject) ||
        (expectedSubject != null && expectedSubject != subject)) {
      throw StateError('Oturum değişti. Tercihi yeniden aç.');
    }
    _recheck?.cancel();
    // An in-flight GET must never delay revocation or restore an older grant.
    ++_request;
    _loading = true;
    _saving = true;
    _error = null;
    _denialRetryIndex = 0;
    final revision = _preference.revision;
    if (!allow) {
      _stop();
      _preference = AnalyticsPreference(
        ConsentChoice.denied,
        revision: revision,
      );
    }
    notifyListeners();
    try {
      final session = _sessions.session;
      final credential = _credentialRevision;
      AnalyticsPreference saved;
      if (session.isAuthenticated) {
        final account = session.userId!;
        if (!allow) {
          _pendingDenialRevision = revision;
          await _store.setPendingDenial(account, revision);
        }
        if (!_current(subject)) throw StateError('Oturum değişti.');
        saved = await _store.member(
          session,
          credential,
          allow: allow,
          revision: revision,
        );
        if (!_current(subject)) throw StateError('Oturum değişti.');
      } else {
        saved = await _store.guest(allow: allow);
      }
      if (!_current(subject)) throw StateError('Oturum değişti.');
      if (saved.choice !=
          (allow ? ConsentChoice.granted : ConsentChoice.denied)) {
        throw StateError('Unexpected preference');
      }
      if (session.isAuthenticated) {
        await _store.setPendingDenial(session.userId!, null);
        if (!_current(subject)) throw StateError('Oturum değişti.');
        _pendingDenialRevision = null;
      }
      _apply(saved);
    } catch (_) {
      if (_current(subject)) {
        _stop();
        _error = 'Tercih kaydedilemedi. Bağlantını kontrol edip tekrar dene.';
      }
      rethrow;
    } finally {
      _finish(subject);
    }
  }

  void _apply(AnalyticsPreference next) {
    _hasSnapshot = true;
    _preference = next;
    if (next.choice != ConsentChoice.granted || next.identity == null) {
      _stop();
      return;
    }
    if (!_foreground) {
      liveActivity?.stop();
      _measurement.suspend();
      return;
    }
    final roles = _sessions.session.normalizedRoles;
    final role = !isMember
        ? 'guest'
        : ['studio', 'venue', 'musician', 'listener']
              .where(
                (value) =>
                    roles.contains('ROLE_${value.toUpperCase()}') ||
                    roles.contains(value.toUpperCase()),
              )
              .firstOrNull;
    if (role == null) {
      _stop();
    } else {
      unawaited(liveActivity?.record(next));
      _measurement.start(next.identity!, role);
    }
  }

  void _finish(int subject) {
    if (!_current(subject)) return;
    _loading = false;
    _saving = false;
    notifyListeners();
    if (_retryRead) {
      _retryRead = false;
      unawaited(refresh());
    } else if (_foreground && isMember && _pendingDenialRevision != null) {
      final delay = Duration(seconds: _denialRetrySeconds[_denialRetryIndex]);
      if (_denialRetryIndex < _denialRetrySeconds.length - 1) {
        _denialRetryIndex++;
      }
      _recheck?.cancel();
      _recheck = Timer(delay, refresh);
    } else if (_foreground &&
        (isMember || liveActivity != null) &&
        _preference.choice == ConsentChoice.granted) {
      _recheck?.cancel();
      _recheck = Timer(const Duration(minutes: 1), refresh);
    }
  }

  @override
  void dispose() {
    _started = false;
    _recheck?.cancel();
    _sessions.removeListener(_onSessionChanged);
    _stop();
    super.dispose();
  }
}
