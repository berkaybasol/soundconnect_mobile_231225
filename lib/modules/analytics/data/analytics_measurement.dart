import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'analytics_section.dart';
import 'analytics_live_activity.dart';
import 'first_week_measurement.dart';

typedef AnalyticsActionSession = ({
  int generation,
  String identity,
  String profile,
});

/// Android's Firebase SDK must not initialize before the current actor's
/// consent is known, including on engine creation and FCM background starts.
class AnalyticsMeasurement {
  AnalyticsMeasurement({
    this.firstWeek,
    bool? configured,
    bool? firstPartyEnabled,
    MethodChannel? channel,
    Duration Function()? elapsed,
    DateTime Function()? utcNow,
  }) : _override = configured,
       _firstPartyEnabled = firstPartyEnabled ?? AnalyticsLiveActivity.enabled,
       _channel =
           channel ??
           const MethodChannel('com.soundconnect/analytics_consent') {
    _clock = SectionClock(_sectionTime, elapsed: elapsed, utcNow: utcNow);
  }
  final FirstWeekMeasurement? firstWeek;
  final bool? _override;
  final bool _firstPartyEnabled;
  final MethodChannel _channel;
  late final SectionClock _clock;
  static const _project = String.fromEnvironment('SOUNDCONNECT_GA4_PROJECT');
  bool get _configured =>
      _override ??
      (_project.isNotEmpty &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android);
  Future<void> _pending = Future.value();
  int _generation = 0;
  String? _id;
  String? _role;
  bool _suspended = false;
  bool _active = false;
  bool _nativeActive = false;
  int? _claiming;
  String? _closedWindow;
  String? _claimedIdentity;

  void show(SectionView view) => _clock.show(view);

  AnalyticsActionSession? captureAction() => _active && _role != 'guest'
      ? (generation: _generation, identity: _id!, profile: _role!)
      : null;

  void claimFirstAction() {
    final session = captureAction();
    final backend = firstWeek;
    if (!_nativeActive ||
        session == null ||
        backend == null ||
        _claiming == session.generation ||
        _claimedIdentity == session.identity) {
      return;
    }
    _claiming = session.generation;
    unawaited(() async {
      try {
        final first = await backend.claim(session.identity);
        if (first == null ||
            captureAction() != session ||
            first.profile != session.profile) {
          return;
        }
        _claimedIdentity = session.identity;
        meaningfulAction(session, first.action, first.occurredAt);
      } catch (_) {
        // The next verified foreground refresh can claim a pending server action.
      } finally {
        if (_claiming == session.generation) _claiming = null;
      }
    }());
  }

  void meaningfulAction(
    AnalyticsActionSession session,
    String action,
    DateTime occurredAt,
  ) {
    if (session != captureAction() || !firstActionTypes.contains(action)) {
      return;
    }
    _event('meaningful_action', {
      'action_type': action,
      'occurred_at_ms': occurredAt.millisecondsSinceEpoch,
    });
  }

  void _sectionTime(SectionView view, DateTime start, int milliseconds) {
    if (!_active) return;
    _event('section_time', {
      'section': view.section.name,
      'duration_ms': milliseconds,
      if (view.profile != null) 'viewed_profile_type': view.profile!.name,
      if (view.own != null) 'is_own_profile': view.own! ? 1 : 0,
      if (view.table != null) 'table_view': view.table!.name,
      if (view.discoveryEvent) 'navigation_source': 'discover',
    });
    final member = captureAction();
    final backend = firstWeek;
    if (member == null || backend == null || _closedWindow == member.identity) {
      return;
    }
    unawaited(
      backend
          .duration(
            member.identity,
            start,
            milliseconds,
            () => captureAction() == member && _closedWindow != member.identity,
          )
          .then<void>((open) {
            if (!open && _id == member.identity) {
              _closedWindow = member.identity;
            }
          })
          .catchError((Object _) {}),
    );
  }

  void _event(String name, Map<String, Object> parameters) {
    if (!_nativeActive) return;
    // Dart platform messages on this channel are FIFO. A lifecycle final sample
    // is dispatched before suspend, and a withdrawal drops its partial sample.
    unawaited(
      _channel
          .invokeMethod<void>('event', {
            'identity': _id,
            'name': name,
            'parameters': {...parameters, 'profile_type': _role},
          })
          .catchError((Object _) {}),
    );
  }

  void start(String id, String role) {
    if (!_configured && !_firstPartyEnabled) return;
    if (!_suspended && _id == id && _role == role) {
      claimFirstAction();
      return;
    }
    _clock.end(sendLast: false);
    _active = false;
    _nativeActive = false;
    final generation = ++_generation;
    _id = id;
    _role = role;
    _suspended = false;
    _enqueue(() async {
      if (generation != _generation) return;
      // The native channel returns false on Android 7–8, where GA4 cannot
      // run. Consented first-week durations still belong to SoundConnect.
      final supported =
          _configured &&
          await _channel.invokeMethod<bool>('prepare', {'identity': id}) !=
              false;
      if (generation != _generation) return;
      if (supported) {
        final enabled = await _channel.invokeMethod<bool>('start', {
          'identity': id,
          'profile': role,
        });
        if (generation != _generation) return;
        if (enabled != true) {
          _id = null;
          return;
        }
        _nativeActive = true;
      } else if (!_firstPartyEnabled || role == 'guest') {
        return;
      }
      _active = true;
      _clock.begin();
      claimFirstAction();
    });
  }

  void stop() {
    if (!_configured && !_firstPartyEnabled) return;
    _clock.end(sendLast: false);
    _active = false;
    _nativeActive = false;
    _claimedIdentity = null;
    _closedWindow = null;
    ++_generation;
    _id = null;
    _role = null;
    if (_configured) {
      _closeGate();
      _enqueue(() => _channel.invokeMethod<void>('stop'));
    }
  }

  void suspend() {
    if ((!_configured && !_firstPartyEnabled) || _suspended) return;
    _clock.end(sendLast: true);
    _active = false;
    _nativeActive = false;
    ++_generation;
    _suspended = true;
    if (_configured) _closeGate();
  }

  void _closeGate() {
    // Close the native worker gate even while a previous reset is pending.
    unawaited(_channel.invokeMethod<void>('suspend').catchError((Object _) {}));
  }

  void _enqueue(Future<void> Function() change) {
    final generation = _generation;
    _pending = _pending.then((_) => change()).catchError((Object _) {
      if (generation == _generation) _id = null;
    });
  }
}
