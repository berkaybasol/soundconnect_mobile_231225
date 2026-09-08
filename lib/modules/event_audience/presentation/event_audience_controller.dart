import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../domain/event_audience_repository.dart';

bool canUseEventAudience(AuthSession? session) {
  if (session?.isAuthenticated != true ||
      session?.isActive != true ||
      session?.userId?.trim().isNotEmpty != true ||
      session!.isAdmin) {
    return false;
  }
  final roles = session.normalizedRoles
      .map((role) => role.startsWith('ROLE_') ? role.substring(5) : role)
      .toSet();
  if (roles.any(
    const {
      'ADMIN',
      'OWNER',
      'VENUE',
      'STUDIO',
      'BAND',
      'ORGANIZER',
      'PRODUCER',
    }.contains,
  )) {
    return false;
  }
  return roles.intersection(const {'LISTENER', 'MUSICIAN'}).length == 1;
}

bool canPublishAudienceProfile(AuthSession? session) =>
    canUseEventAudience(session) &&
    session!.hasAnyRole(const ['ROLE_LISTENER', 'LISTENER']) &&
    !session.requiresListenerProfileChoice;

bool sameEventAudienceSession(AuthSession current, AuthSession expected) =>
    canUseEventAudience(current) &&
    current.userId == expected.userId &&
    current.token == expected.token &&
    current.accountStatus == expected.accountStatus &&
    current.isAdmin == expected.isAdmin &&
    listEquals(current.roles, expected.roles) &&
    current.requiresListenerProfileChoice ==
        expected.requiresListenerProfileChoice;

class EventAudienceController extends ChangeNotifier {
  EventAudienceController({
    required this.eventId,
    required this.repository,
    required this.sessions,
    EventAudienceState? initialIntent,
  }) {
    _session = sessions.session;
    sessions.addListener(_sessionChanged);
    repository.changes.addListener(_repositoryChanged);
    if (allowed && initialIntent?.eventId == eventId) {
      _state = initialIntent;
    } else if (allowed) {
      unawaited(refresh());
    }
  }

  final String eventId;
  final EventAudienceRepository repository;
  final AuthSessionManager sessions;
  late AuthSession _session;
  EventAudienceState? _state;
  String? _error;
  bool _loading = false;
  bool _saving = false;
  bool _needsRefresh = false;
  bool _refreshAfterLoad = false;
  bool _disposed = false;
  int _revision = 0;

  EventAudienceState? get state => _state;
  String? get error => _error;
  bool get loading => _loading;
  bool get saving => _saving;
  bool get busy => _loading || _saving;
  bool get needsRefresh => _needsRefresh;
  int get revision => _revision;
  AuthSession get session => _session;
  bool get allowed => !_disposed && canUseEventAudience(sessions.session);

  bool sameSession(AuthSession expected) =>
      !_disposed && sameEventAudienceSession(sessions.session, expected);

  bool _current(int revision, AuthSession expected) =>
      revision == _revision && sameSession(expected);

  void _sessionChanged() {
    if (_disposed) return;
    final next = sessions.session;
    if (next.userId == _session.userId &&
        next.token == _session.token &&
        next.isAdmin == _session.isAdmin &&
        next.accountStatus == _session.accountStatus &&
        listEquals(next.roles, _session.roles) &&
        next.requiresListenerProfileChoice ==
            _session.requiresListenerProfileChoice) {
      return;
    }
    _revision++;
    _session = next;
    _state = null;
    _error = null;
    _needsRefresh = false;
    _refreshAfterLoad = false;
    _loading = false;
    _saving = false;
    notifyListeners();
    if (allowed) unawaited(refresh());
  }

  void _repositoryChanged() {
    if (allowed && _loading) _refreshAfterLoad = true;
    if (allowed && !busy) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (!allowed || busy) return;
    final revision = ++_revision;
    final expected = sessions.session;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await repository.getIntent(
        eventId: eventId,
        expectedSessionKey: expected.userId!,
      );
      if (!_current(revision, expected)) return;
      final value = result.data;
      if (result.isSuccess && value?.eventId == eventId) {
        _state = value;
        _needsRefresh = false;
      } else {
        _needsRefresh = true;
        _error = 'Etkinlik seçimin yüklenemedi. Yeniden dene.';
      }
    } catch (_) {
      if (!_current(revision, expected)) return;
      _needsRefresh = true;
      _error = 'Etkinlik seçimin yüklenemedi. Yeniden dene.';
    } finally {
      if (_current(revision, expected)) {
        _loading = false;
        notifyListeners();
        if (_refreshAfterLoad) {
          _refreshAfterLoad = false;
          unawaited(refresh());
        }
      }
    }
  }

  Future<EventAudienceState?> choose(
    EventAudienceStatus intent, {
    required int expectedRevision,
  }) async {
    final current = _state;
    if (!allowed ||
        busy ||
        _needsRefresh ||
        expectedRevision != _revision ||
        current == null) {
      return null;
    }
    if (current.intent == intent) return current;
    if (intent != EventAudienceStatus.none && !current.canSetIntent) {
      return null;
    }
    return _mutate(
      intent: intent,
      published: intent == EventAudienceStatus.none
          ? false
          : current.publishedOnProfile,
      note: intent == EventAudienceStatus.none ? null : current.note,
      expectedRevision: expectedRevision,
    );
  }

  Future<EventAudienceState?> publish(
    String? note, {
    required int expectedRevision,
  }) {
    final current = _state;
    if (current == null ||
        current.intent == EventAudienceStatus.none ||
        !current.canPublish ||
        !canPublishAudienceProfile(sessions.session)) {
      return Future.value(null);
    }
    return _mutate(
      intent: current.intent,
      published: true,
      note: note,
      expectedRevision: expectedRevision,
    );
  }

  Future<EventAudienceState?> unpublish({required int expectedRevision}) {
    final current = _state;
    if (current == null || !current.publishedOnProfile) {
      return Future.value(null);
    }
    return _mutate(
      intent: current.intent,
      published: false,
      note: null,
      expectedRevision: expectedRevision,
    );
  }

  Future<EventAudienceState?> _mutate({
    required EventAudienceStatus intent,
    required bool published,
    required String? note,
    required int expectedRevision,
  }) async {
    final current = _state;
    if (!allowed ||
        busy ||
        _needsRefresh ||
        expectedRevision != _revision ||
        current == null) {
      return null;
    }
    final expected = sessions.session;
    final revision = ++_revision;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final result = await repository.setIntent(
        eventId: eventId,
        intent: intent,
        publishedOnProfile: published,
        note: note,
        expectedVersion: current.version,
        expectedSessionKey: expected.userId!,
      );
      if (!_current(revision, expected)) return null;
      final value = result.data;
      if (result.isSuccess &&
          value?.eventId == eventId &&
          value?.intent == intent &&
          value?.publishedOnProfile == published) {
        _state = value;
        return value;
      }
      _needsRefresh = true;
      _error = 'Seçimin doğrulanamadı. Güncel durumu yeniden yükle.';
      return null;
    } catch (_) {
      if (_current(revision, expected)) {
        _needsRefresh = true;
        _error = 'Seçimin doğrulanamadı. Güncel durumu yeniden yükle.';
      }
      return null;
    } finally {
      if (_current(revision, expected)) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    sessions.removeListener(_sessionChanged);
    repository.changes.removeListener(_repositoryChanged);
    super.dispose();
  }
}
