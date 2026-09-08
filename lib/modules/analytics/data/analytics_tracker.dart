import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../domain/analytics_collection_repository.dart';
import '../domain/analytics_observation.dart';

/// Best-effort, bounded, identity-scoped analytics. It never owns UI state.
///
/// Only invoke record methods after a real exposure. Fetches and preloads are
/// deliberately not observed. The server remains authoritative for ownership
/// exclusions, eligibility and unique visitor aggregation.
class AnalyticsTracker with WidgetsBindingObserver {
  AnalyticsTracker({
    required AnalyticsCollectionRepository repository,
    required AuthSessionManager sessionManager,
    Future<SharedPreferences> Function()? preferencesLoader,
    DateTime Function()? clock,
    String Function()? createId,
    double Function()? random,
  }) : _repository = repository,
       _sessionManager = sessionManager,
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _clock = clock ?? DateTime.now,
       _createId = createId ?? const Uuid().v4,
       _random = random ?? Random().nextDouble {
    _session = _sessionManager.session;
    _foreground = _isForeground;
    _sessionManager.addListener(_onSessionChanged);
    WidgetsBinding.instance.addObserver(this);
    _ready = _initialize();
  }

  static const installationKey = 'sc_analytics_installation_v1';
  static const queueKey = 'sc_analytics_queue_v1';
  static const maxQueueSize = 128;
  static const maxBatchSize = 20;
  static const observationTtl = Duration(hours: 24);
  static const _flushDelay = Duration(seconds: 3);
  static const _maxFailures = 6;
  static const _recentTtl = Duration(seconds: 30);
  static const _maxRecentKeys = 512;
  static final Map<SharedPreferences, Future<String?>> _installationLoads = {};

  final AnalyticsCollectionRepository _repository;
  final AuthSessionManager _sessionManager;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final DateTime Function() _clock;
  final String Function() _createId;
  final double Function() _random;
  final List<AnalyticsObservation> _queue = [];
  final LinkedHashMap<String, DateTime> _recent = LinkedHashMap();
  late AuthSession _session;
  late final Future<void> _ready;
  SharedPreferences? _preferences;
  String? _clientId;
  Future<void>? _writeInFlight;
  String? _pendingSnapshot;
  Future<void>? _flushInFlight;
  Timer? _flushTimer;
  bool _disposed = false;
  late bool _foreground;
  int _generation = 0;
  int _failures = 0;
  DateTime? _serverRetryUntil;

  bool get _isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  String _scope(AuthSession session) {
    if (!session.isAuthenticated) return 'guest';
    return sha256
        .convert(utf8.encode('user:${session.userId ?? ''}'))
        .toString();
  }

  bool _mayObserve(AuthSession session) =>
      !session.isAdmin &&
      (!session.isAuthenticated ||
          (session.userId?.trim().isNotEmpty == true && session.isActive));

  Future<void> _initialize() async {
    final generation = _generation;
    final scope = _scope(_session);
    try {
      final preferences = await _preferencesLoader();
      if (_disposed) return;
      _preferences = preferences;
      final clientId = await _installationId(preferences);
      if (clientId == null) return;
      if (_disposed) return;
      _clientId = clientId;
      if (generation == _generation && _mayObserve(_session)) {
        final stored = preferences.getString(queueKey);
        if (stored != null) {
          try {
            final decoded = jsonDecode(stored);
            if (decoded is Map<String, dynamic> &&
                decoded['scope'] == scope &&
                decoded['observations'] is List) {
              final rows = decoded['observations'] as List;
              if (rows.length <= maxQueueSize) {
                final unique = <String>{};
                for (final row in rows) {
                  try {
                    final observation = AnalyticsObservation.fromJson(
                      Map<String, dynamic>.from(row as Map),
                    );
                    if (_isFresh(observation) && unique.add(observation.id)) {
                      _queue.add(observation);
                    }
                  } catch (_) {
                    // A corrupt entry cannot block the rest of a bounded queue.
                  }
                }
              }
            }
          } catch (_) {
            // Invalid local data is replaced with a clean scoped envelope.
          }
        }
      }
      await _persist();
      _scheduleFlush();
    } catch (_) {
      // Storage availability must not affect discovery or navigation.
      _clientId = null;
    }
  }

  Future<String?> _installationId(SharedPreferences preferences) async {
    final existing = _installationLoads[preferences];
    if (existing != null) return existing;
    Future<String?> createOrRead() async {
      final stored = preferences.getString(installationKey);
      if (stored != null && isAnalyticsUuid(stored)) return stored;
      final created = _createId();
      if (!isAnalyticsUuid(created) ||
          !await preferences.setString(installationKey, created)) {
        return null;
      }
      return created;
    }

    final operation = createOrRead();
    _installationLoads[preferences] = operation;
    try {
      return await operation;
    } finally {
      if (identical(_installationLoads[preferences], operation)) {
        _installationLoads.remove(preferences);
      }
    }
  }

  bool _isFresh(AnalyticsObservation observation) {
    final age = _clock().toUtc().difference(observation.observedAt);
    return !age.isNegative && age <= observationTtl;
  }

  void recordEventImpression(String eventId) =>
      _record(AnalyticsObservationType.eventImpression, eventId: eventId);

  void recordEventDetailView(String eventId) =>
      _record(AnalyticsObservationType.eventDetailView, eventId: eventId);

  void recordVenueProfileView(String venueId, {String? sourceEventId}) =>
      _record(
        AnalyticsObservationType.venueProfileView,
        venueId: venueId,
        sourceEventId: sourceEventId,
      );

  void _record(
    AnalyticsObservationType type, {
    String? eventId,
    String? venueId,
    String? sourceEventId,
  }) {
    if (_disposed || !_foreground || !_mayObserve(_session)) return;
    final now = _clock().toUtc();
    final istanbulDate = now.add(const Duration(hours: 3));
    final recentKey =
        '${type.wireValue}|${eventId ?? venueId}|${sourceEventId ?? ''}|'
        '${istanbulDate.year}-${istanbulDate.month}-${istanbulDate.day}';
    final previous = _recent[recentKey];
    if (previous != null &&
        !now.difference(previous).isNegative &&
        now.difference(previous) < _recentTtl) {
      return;
    }
    final generation = _generation;
    final observation = AnalyticsObservation(
      id: _createId(),
      type: type,
      observedAt: now,
      eventId: eventId,
      venueId: venueId,
      sourceEventId: sourceEventId,
    );
    if (!observation.isValid) return;
    _recent.removeWhere((_, time) => now.difference(time) >= _recentTtl);
    _recent.remove(recentKey);
    while (_recent.length >= _maxRecentKeys) {
      _recent.remove(_recent.keys.first);
    }
    _recent[recentKey] = now;
    unawaited(_enqueue(observation, generation));
  }

  Future<void> _enqueue(
    AnalyticsObservation observation,
    int generation,
  ) async {
    await _ready;
    if (_disposed || generation != _generation || _clientId == null) return;
    _queue.removeWhere((value) => !_isFresh(value));
    while (_queue.length >= maxQueueSize) {
      _queue.removeAt(0);
    }
    _queue.add(observation);
    await _persist();
    if (_disposed || generation != _generation) return;
    if (_queue.length >= maxBatchSize && _failures == 0) {
      unawaited(flush());
    } else {
      _scheduleFlush();
    }
  }

  /// Safe to call on resume or tests. Concurrent callers share one upload.
  Future<void> flush() {
    if (_disposed) return Future<void>.value();
    final pending = _flushInFlight;
    if (pending != null) return pending;
    _flushTimer?.cancel();
    _flushTimer = null;
    final operation = _flush();
    _flushInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_flushInFlight, operation)) {
        _flushInFlight = null;
        _scheduleFlush();
      }
    });
  }

  Future<void> _flush() async {
    await _ready;
    if (_disposed || !_foreground || _clientId == null) return;
    final retryUntil = _serverRetryUntil;
    if (retryUntil != null && _clock().toUtc().isBefore(retryUntil)) return;
    _serverRetryUntil = null;
    final generation = _generation;
    _queue.removeWhere((value) => !_isFresh(value));
    if (_queue.isEmpty || !_mayObserve(_session)) {
      await _persist();
      return;
    }
    final batch = List<AnalyticsObservation>.unmodifiable(
      _queue.take(maxBatchSize),
    );
    final userId = _session.isAuthenticated ? _session.userId : null;
    try {
      final result = await _repository.collect(
        clientId: _clientId!,
        observations: batch,
        expectedUserId: userId,
      );
      if (_disposed || generation != _generation) return;
      if (result.isSuccess) {
        final acknowledged = (result.data ?? const <String>[]).toSet();
        final sent = batch.map((value) => value.id).toSet();
        // Do not trust an injected adapter to acknowledge unrelated queued IDs.
        _queue.removeWhere(
          (value) => sent.contains(value.id) && acknowledged.contains(value.id),
        );
        _failures = acknowledged.intersection(sent).isEmpty ? _failures + 1 : 0;
      } else {
        final code = result.error?.code ?? '';
        final retryAfter = result.error?.retryAfter;
        if (const {'429', '503', '9912', '9913'}.contains(code) &&
            retryAfter != null &&
            !retryAfter.isNegative) {
          _serverRetryUntil = _clock().toUtc().add(
            retryAfter > const Duration(hours: 1)
                ? const Duration(hours: 1)
                : retryAfter,
          );
        }
        if (_isPermanentFailure(code)) {
          final rejected = batch.map((value) => value.id).toSet();
          _queue.removeWhere((value) => rejected.contains(value.id));
          _failures = 0;
        } else {
          _failures++;
        }
      }
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _failures++;
    }
    await _persist();
  }

  bool _isPermanentFailure(String code) {
    if (code == 'api_session_fence' || code == 'analytics_invalid') return true;
    if (const {'9910', '9911', '9914'}.contains(code)) return true;
    final status = int.tryParse(code);
    return status != null &&
        status >= 400 &&
        status < 500 &&
        status != 408 &&
        status != 429;
  }

  void _scheduleFlush() {
    if (_disposed ||
        !_foreground ||
        _queue.isEmpty ||
        _clientId == null ||
        _flushInFlight != null ||
        _flushTimer != null) {
      return;
    }
    var delay = _failures == 0
        ? _flushDelay
        : Duration(
            milliseconds:
                ((_failures >= _maxFailures
                            ? 300000
                            : min(300000, 3000 * (1 << min(_failures, 7)))) *
                        (1 + _random().clamp(0, 1) * 0.2))
                    .round(),
          );
    final serverDelay = _serverRetryUntil?.difference(_clock().toUtc());
    if (serverDelay != null && serverDelay > delay) delay = serverDelay;
    _flushTimer = Timer(delay, () {
      _flushTimer = null;
      unawaited(flush());
    });
  }

  Future<void> _persist() {
    final preferences = _preferences;
    if (preferences == null) return Future<void>.value();
    _pendingSnapshot = jsonEncode({
      'scope': _scope(_session),
      'observations': _queue.map((value) => value.toJson()).toList(),
    });
    final existing = _writeInFlight;
    if (existing != null) return existing;
    final completion = Completer<void>();
    _writeInFlight = completion.future;
    // Serialize and coalesce snapshots: one active write plus the newest
    // pending snapshot. A slow device cannot build an unbounded write backlog,
    // nor can an older account's write run after the latest scoped snapshot.
    unawaited(() async {
      try {
        while (_pendingSnapshot != null) {
          final snapshot = _pendingSnapshot!;
          _pendingSnapshot = null;
          try {
            await preferences.setString(queueKey, snapshot);
          } catch (_) {
            // RAM remains bounded and can still deliver during this session.
          }
        }
      } finally {
        _writeInFlight = null;
        completion.complete();
      }
    }());
    return completion.future;
  }

  void _onSessionChanged() {
    final next = _sessionManager.session;
    if (identical(next, _session)) return;
    final sameActor = _scope(next) == _scope(_session);
    final remainsEligible = _mayObserve(next) && _mayObserve(_session);
    _session = next;
    // A refreshed token for the same eligible actor is not a new viewer.
    // Preserve receipt IDs and allow its in-flight acknowledgement to finish.
    if (sameActor && remainsEligible) return;
    _generation++;
    _queue.clear();
    _recent.clear();
    _failures = 0;
    _serverRetryUntil = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    unawaited(_persist());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_foreground) {
      _failures = 0;
      _scheduleFlush();
    } else {
      // Pending observations are already persisted. Never start new background
      // network work whose completion the operating system cannot guarantee.
      unawaited(_persist());
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _flushTimer?.cancel();
    _sessionManager.removeListener(_onSessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    await _persist();
  }
}
