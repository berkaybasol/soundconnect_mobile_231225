import 'package:flutter/foundation.dart';

typedef AppDiagnosticSink = void Function(AppDiagnosticEvent event);

enum AppDiagnosticSeverity { error, fatal }

@immutable
class AppDiagnosticEvent {
  const AppDiagnosticEvent({
    required this.severity,
    required this.source,
    required this.errorType,
    required this.stackTrace,
  });

  final AppDiagnosticSeverity severity;
  final String source;
  final String errorType;
  final StackTrace stackTrace;
}

/// Minimal crash-reporting seam. It deliberately records only error types and
/// stack traces, never exception messages, state values, tokens or payloads.
class AppDiagnostics {
  AppDiagnostics._();

  static AppDiagnosticSink? sink;

  static void reportFlutterError(FlutterErrorDetails details) {
    report(
      severity: AppDiagnosticSeverity.error,
      source: 'flutter-framework',
      errorType: details.exception.runtimeType.toString(),
      stackTrace: details.stack ?? StackTrace.current,
    );
  }

  static void reportUnhandled(Object error, StackTrace stackTrace) {
    report(
      severity: AppDiagnosticSeverity.fatal,
      source: 'unhandled-zone',
      errorType: error.runtimeType.toString(),
      stackTrace: stackTrace,
    );
  }

  static void reportBlocError(
    Object bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    report(
      severity: AppDiagnosticSeverity.error,
      source: 'bloc:${bloc.runtimeType}',
      errorType: error.runtimeType.toString(),
      stackTrace: stackTrace,
    );
  }

  @visibleForTesting
  static void report({
    required AppDiagnosticSeverity severity,
    required String source,
    required String errorType,
    required StackTrace stackTrace,
  }) {
    final event = AppDiagnosticEvent(
      severity: severity,
      source: source,
      errorType: errorType,
      stackTrace: stackTrace,
    );
    try {
      sink?.call(event);
    } catch (_) {
      // Diagnostics must never create a secondary application failure.
    }
    if (kDebugMode) {
      debugPrint('[${severity.name}] $source ($errorType)');
    }
  }
}
