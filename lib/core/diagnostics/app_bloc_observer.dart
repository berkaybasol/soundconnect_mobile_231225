import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_diagnostics.dart';

class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    AppDiagnostics.reportBlocError(bloc, error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}
