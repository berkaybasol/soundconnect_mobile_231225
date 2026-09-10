import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';

/// A route keeps its original audience for its entire lifetime. Reopening is
/// required after logout/login, even when the account identifier is unchanged.
class OverthinkingSession extends ChangeNotifier {
  OverthinkingSession(this._sessions) : _initial = _sessions?.session {
    _sessions?.addListener(_changed);
  }

  final AuthSessionManager? _sessions;
  final AuthSession? _initial;
  bool _invalidated = false;

  static const error = AppError(
    code: 'overthinking_session_changed',
    message: 'Oturum değişti. Overthinking sayfasını yeniden aç.',
  );

  bool get isCurrent =>
      !_invalidated &&
      (_sessions == null || identical(_sessions.session, _initial));

  bool get canWrite =>
      isCurrent &&
      (_sessions == null ||
          (_initial!.isAuthenticated &&
              _initial.isActive &&
              _initial.userId?.trim().isNotEmpty == true &&
              !_initial.requiresListenerProfileChoice));

  void _changed() {
    if (isCurrent || _invalidated) return;
    _invalidated = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessions?.removeListener(_changed);
    super.dispose();
  }
}
