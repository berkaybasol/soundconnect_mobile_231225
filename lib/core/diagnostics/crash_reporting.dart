import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:uuid/uuid.dart';

import '../auth/auth_session.dart';
import '../auth/auth_session_manager.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'app_diagnostics.dart';

enum CrashReportingStatus { disabled, ready, unavailable }

/// Only a fixed error taxonomy and source locations cross this boundary.
/// Native fatal handlers, exception messages and arbitrary runtime types do not.
class DiagnosticReport {
  const DiagnosticReport(this.source, this.errorType, this.frames, this.fatal);
  final String source;
  final String errorType;
  final List<String> frames;
  final bool fatal;

  static const errorTypes = <String>{
    'ApplicationError',
    'StateError',
    'ArgumentError',
    'FormatException',
    'TimeoutException',
    'SocketException',
    'HttpException',
    'FirebaseException',
    'DioException',
    'FlutterError',
    'RangeError',
    'TypeError',
    'NoSuchMethodError',
    'ConcurrentModificationError',
    'AssertionError',
    'UnsupportedError',
    'MissingPluginException',
    'PlatformException',
    'FrameBudgetExceeded',
    'DiagnosticAcceptanceCheck',
  };

  factory DiagnosticReport.sanitize(AppDiagnosticEvent event) {
    final source = switch (event.source) {
      'flutter-framework' => 'FLUTTER_FRAMEWORK',
      'unhandled-zone' => 'UNHANDLED_ZONE',
      'platform-dispatcher' => 'PLATFORM_DISPATCHER',
      'frame-timing' => 'FRAME_TIMING',
      'diagnostics-check' => 'DIAGNOSTICS_CHECK',
      _ => event.source.startsWith('bloc:') ? 'BLOC' : 'RECOVERABLE',
    };
    final type = errorTypes.contains(event.errorType)
        ? event.errorType
        : 'ApplicationError';
    final frames = <String>[];
    // Anchor whole VM frames; never find a package substring inside a URL,
    // message, argument, file path or unstructured custom trace.
    final pattern = RegExp(
      r'^#\d+\s+[^\r\n()]{1,160}\s+\(((?:package:soundconnect_23_12_25codx/|dart:)[a-zA-Z0-9_/-]+\.dart(?::\d{1,7}){1,2})\)\s*$',
    );
    try {
      final raw = event.stackTrace.toString();
      final bounded = raw.length > 16384 ? raw.substring(0, 16384) : raw;
      for (final line in bounded.split('\n').take(100)) {
        final match = pattern.firstMatch(line);
        final location = match?[1];
        if (location != null && location.length <= 240) {
          frames.add(location);
          if (frames.length == 40) break;
        }
      }
    } catch (_) {
      // A custom StackTrace can itself throw. Keep only the safe taxonomy.
    }
    return DiagnosticReport(
      source,
      type,
      List.unmodifiable(frames),
      event.severity == AppDiagnosticSeverity.fatal,
    );
  }
}

typedef DiagnosticWriter = Future<bool> Function(DiagnosticReport report);

/// At most four outstanding writes, twenty reports/minute, one per signature.
/// A pending write keeps its slot until its real future settles.
class DiagnosticDispatcher {
  DiagnosticDispatcher(this.writer, {Duration Function()? elapsed})
    : _elapsed = elapsed ?? (Stopwatch()..start()).elapsedDuration;
  final DiagnosticWriter writer;
  final Duration Function() _elapsed;
  final Set<String> _last = {};
  int _pending = 0;
  int _sentInWindow = 0;
  Duration _window = Duration.zero;
  bool _disposed = false;

  void accept(AppDiagnosticEvent event) => unawaited(dispatch(event));

  Future<bool> dispatch(AppDiagnosticEvent event) async {
    if (_disposed) return false;
    final now = _elapsed();
    if (now - _window >= const Duration(minutes: 1)) {
      _window = now;
      _sentInWindow = 0;
      _last.clear();
    }
    if (_pending >= 4 || _sentInWindow >= 20) return false;
    final report = DiagnosticReport.sanitize(event);
    final key = '${report.source}:${report.errorType}:${report.fatal}';
    if (!_last.add(key)) return false;
    _sentInWindow++;
    _pending++;
    try {
      return await writer(report);
    } catch (_) {
      return false;
    } finally {
      _pending--;
    }
  }

  void dispose() => _disposed = true;
}

extension on Stopwatch {
  Duration elapsedDuration() => elapsed;
}

/// Uses the existing authenticated API and transport fence. No account identity
/// is included in the report body, no disk queue survives a session or build.
class MobileDiagnosticReporter {
  MobileDiagnosticReporter({
    required ApiClient api,
    required AuthSessionManager sessions,
    required this.environment,
    Duration Function()? elapsed,
    String Function()? createId,
    Future<void> Function(Duration)? delay,
  }) : _api = api,
       _sessions = sessions,
       _createId = createId ?? const Uuid().v4,
       _delay = delay ?? Future<void>.delayed {
    _dispatcher = DiagnosticDispatcher(_write, elapsed: elapsed);
  }

  final ApiClient _api;
  final AuthSessionManager _sessions;
  final String environment;
  final String Function() _createId;
  final Future<void> Function(Duration) _delay;
  late final DiagnosticDispatcher _dispatcher;
  bool _disposed = false;

  static bool mayReport(AuthSession session) =>
      session.isAuthenticated &&
      session.isActive &&
      !session.requiresListenerProfileChoice &&
      session.userId?.isNotEmpty == true;

  void accept(AppDiagnosticEvent event) => unawaited(report(event));

  Future<bool> report(AppDiagnosticEvent event) {
    if (_disposed ||
        !const {'local', 'staging', 'production'}.contains(environment) ||
        !mayReport(_sessions.session)) {
      return Future.value(false);
    }
    return _dispatcher.dispatch(event);
  }

  Future<bool> _write(DiagnosticReport report) async {
    final session = _sessions.session;
    final revision = _sessions.credentialRevision;
    bool current() =>
        !_disposed &&
        identical(session, _sessions.session) &&
        revision == _sessions.credentialRevision &&
        mayReport(session);
    if (!current()) return false;
    final id = _createId();
    final body = <String, Object>{
      'eventId': id,
      'severity': report.fatal ? 'FATAL' : 'ERROR',
      'source': report.source,
      'errorType': report.errorType,
      'frames': report.frames,
      'environment': environment,
    };
    for (var attempt = 0; attempt < 2 && current(); attempt++) {
      try {
        final receipt = await _api.request<Object?>(
          ApiHttpMethod.post,
          '/api/v1/diagnostics/mobile',
          body: body,
          requestContext: ApiRequestContext(
            expectedSessionKey: session.userId,
            expectedToken: session.token,
            expectedCredentialRevision: revision,
          ),
        );
        return current() &&
            receipt is Map &&
            receipt['eventId'] == id &&
            receipt['accepted'] == true;
      } on ApiException catch (exception) {
        final error = exception.error;
        final retryable = const {
          'network',
          '408',
          '429',
          '503',
          '1104',
          '1115',
        }.contains(error.code);
        if (attempt != 0 || !retryable || !current()) return false;
        final requested = error.retryAfter ?? const Duration(seconds: 5);
        if (requested > const Duration(seconds: 30)) return false;
        final pause = requested < const Duration(seconds: 5)
            ? const Duration(seconds: 5)
            : requested;
        await _delay(pause);
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  void dispose() {
    _disposed = true;
    _dispatcher.dispose();
  }
}

class CrashReporting {
  CrashReporting._();
  static final status = ValueNotifier(CrashReportingStatus.disabled);
  static const enabled = bool.fromEnvironment(
    'SOUNDCONNECT_DIAGNOSTICS_ENABLED',
  );
  static const environment = String.fromEnvironment('SOUNDCONNECT_ENVIRONMENT');
  static MobileDiagnosticReporter? _reporter;
  static int _frames = 0;
  static int _slowFrames = 0;
  static final Stopwatch _frameWindow = Stopwatch();

  static void initialize({
    required ApiClient api,
    required AuthSessionManager sessions,
  }) {
    if (_reporter != null ||
        !enabled ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (!const {'local', 'staging', 'production'}.contains(environment) ||
        (kDebugMode && environment == 'production')) {
      status.value = CrashReportingStatus.unavailable;
      return;
    }
    _reporter = MobileDiagnosticReporter(
      api: api,
      sessions: sessions,
      environment: environment,
    );
    AppDiagnostics.sink = _reporter!.accept;
    status.value = CrashReportingStatus.ready;
    _frameWindow.start();
    SchedulerBinding.instance.addTimingsCallback(_observeFrames);
  }

  static void _observeFrames(List<FrameTiming> timings) {
    for (final frame in timings) {
      _frames++;
      if (frame.buildDuration.inMilliseconds > 32 ||
          frame.rasterDuration.inMilliseconds > 32) {
        _slowFrames++;
      }
    }
    if (_frameWindow.elapsed < const Duration(minutes: 1)) return;
    if (_frames >= 120 && _slowFrames / _frames >= 0.05) {
      AppDiagnostics.reportRecoverable(
        source: 'frame-timing',
        error: const FrameBudgetExceeded(),
        stackTrace: StackTrace.current,
      );
    }
    _frames = 0;
    _slowFrames = 0;
    _frameWindow.reset();
  }

  /// True requires the same session and an exact API receipt, not just dispatch.
  static Future<bool> reportAcceptanceCheck() async {
    if (status.value != CrashReportingStatus.ready ||
        environment == 'production') {
      return false;
    }
    return _reporter!.report(
      AppDiagnosticEvent(
        severity: AppDiagnosticSeverity.error,
        source: 'diagnostics-check',
        errorType: 'DiagnosticAcceptanceCheck',
        stackTrace: StackTrace.current,
      ),
    );
  }
}

class FrameBudgetExceeded {
  const FrameBudgetExceeded();
}
