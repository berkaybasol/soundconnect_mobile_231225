import 'package:flutter/foundation.dart';

import 'app_diagnostics.dart';

/// Installs SoundConnect diagnostics without swallowing Flutter's existing
/// framework reporter. The previous handler is preserved for IDE/error UI.
void installFlutterErrorHandler() {
  final previousHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    AppDiagnostics.reportFlutterError(details);
    if (previousHandler != null) {
      previousHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };
}

/// Preserve the engine's handling decision while observing uncaught root-isolate
/// errors. Child isolate/native process crashes remain outside this Dart seam.
void installPlatformErrorHandler() {
  final previousHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    AppDiagnostics.reportPlatformError(error, stack);
    return previousHandler?.call(error, stack) ?? false;
  };
}
