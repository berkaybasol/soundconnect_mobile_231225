import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/diagnostics/app_bloc_observer.dart';
import 'package:soundconnect_23_12_25codx/core/diagnostics/app_diagnostics.dart';
import 'package:soundconnect_23_12_25codx/core/diagnostics/app_error_handlers.dart';

void main() {
  tearDown(() {
    AppDiagnostics.sink = null;
  });

  test(
    'bloc observer reports sanitized metadata without error messages',
    () async {
      AppDiagnosticEvent? captured;
      AppDiagnostics.sink = (event) => captured = event;
      final cubit = _TestCubit();
      final stackTrace = StackTrace.fromString('sanitized-test-stack');

      const AppBlocObserver().onError(
        cubit,
        StateError('secret-token-must-not-be-recorded'),
        stackTrace,
      );

      expect(captured, isNotNull);
      final AppDiagnosticEvent event = captured!;
      expect(event.severity, AppDiagnosticSeverity.error);
      expect(event.source, 'bloc:_TestCubit');
      expect(event.errorType, 'StateError');
      expect(event.stackTrace, same(stackTrace));
      expect(
        <String>[
          event.source,
          event.errorType,
          event.stackTrace.toString(),
        ].join('|'),
        isNot(contains('secret-token-must-not-be-recorded')),
      );
      await cubit.close();
    },
  );

  test('a failing diagnostics sink never escapes into the application', () {
    AppDiagnostics.sink = (_) => throw StateError('sink failed');

    expect(
      () => AppDiagnostics.report(
        severity: AppDiagnosticSeverity.fatal,
        source: 'test',
        errorType: 'StateError',
        stackTrace: StackTrace.current,
      ),
      returnsNormally,
    );
  });

  test('Flutter handler reports and preserves the previous handler', () {
    final originalHandler = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalHandler);
    var previousHandlerCalls = 0;
    var diagnosticCalls = 0;
    FlutterError.onError = (_) => previousHandlerCalls += 1;
    AppDiagnostics.sink = (_) => diagnosticCalls += 1;

    installFlutterErrorHandler();
    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('framework failure')),
    );

    expect(previousHandlerCalls, 1);
    expect(diagnosticCalls, 1);
  });
}

class _TestCubit extends Cubit<int> {
  _TestCubit() : super(0);
}
