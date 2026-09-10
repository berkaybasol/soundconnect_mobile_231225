import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/auth/listener_profile_publication_access.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Session-fenced transport and reconciliation for listener publications.
/// Source-specific repositories retain responsibility for wire validation.
class ProfileShareApi {
  ProfileShareApi(
    this._api, {
    required AuthSessionManager sessions,
    required AppError sessionError,
    required AppError unavailableError,
    this.definitiveRejectionCodes = const {},
  }) : _sessions = sessions,
       _sessionError = sessionError,
       _unavailable = unavailableError {
    _sessions.addListener(_sessionChanged);
  }

  final ApiClient _api;
  final AuthSessionManager _sessions;
  final AppError _sessionError;
  final AppError _unavailable;
  final Set<String> definitiveRejectionCodes;
  final ValueNotifier<int> _changes = ValueNotifier(0);
  int _sessionEpoch = 0;
  bool _disposed = false;
  bool _pendingReconciliation = false;

  ValueListenable<int> get changes => _changes;

  void _sessionChanged() {
    ++_sessionEpoch;
    _pendingReconciliation = false;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sessions.removeListener(_sessionChanged);
    _changes.dispose();
  }

  bool _current(AuthSession expected, int epoch) =>
      !_disposed &&
      epoch == _sessionEpoch &&
      identical(_sessions.session, expected);

  Future<Result<T>> request<T>({
    required AuthSession expected,
    required ApiHttpMethod method,
    required String Function() path,
    required T Function(Object?) decoder,
    Object? Function()? body,
    Map<String, dynamic>? Function()? query,
    bool listenerOnly = true,
    bool invalidates = false,
    bool reconciles = false,
  }) async {
    final epoch = _sessionEpoch;
    if (!_current(expected, epoch) ||
        !expected.isAuthenticated ||
        !expected.isActive ||
        expected.userId?.trim().isNotEmpty != true ||
        (listenerOnly && !canPublishListenerProfile(expected))) {
      return Result.failure(_sessionError);
    }
    var dispatched = false;
    try {
      final requestPath = path();
      final requestBody = body?.call();
      final requestQuery = query?.call();
      dispatched = true;
      final value = await _api.request<T>(
        method,
        requestPath,
        body: requestBody,
        query: requestQuery,
        decoder: decoder,
        requestContext: ApiRequestContext(
          expectedSessionKey: expected.userId,
          expectedToken: expected.token,
        ),
      );
      if (!_current(expected, epoch)) {
        return Result.failure(_sessionError);
      }
      if (invalidates || (reconciles && _pendingReconciliation)) {
        if (reconciles) _pendingReconciliation = false;
        _changes.value++;
      }
      return _current(expected, epoch)
          ? Result.success(value)
          : Result.failure(_sessionError);
    } on ApiException catch (error) {
      if (invalidates &&
          dispatched &&
          !_definitiveRejection(error.error.code)) {
        _invalidateUncertain(expected, epoch);
      }
      return Result.failure(
        _current(expected, epoch) ? error.error : _sessionError,
      );
    } catch (_) {
      if (invalidates && dispatched) _invalidateUncertain(expected, epoch);
      return Result.failure(
        _current(expected, epoch) ? _unavailable : _sessionError,
      );
    }
  }

  void _invalidateUncertain(AuthSession expected, int epoch) {
    if (!_current(expected, epoch)) return;
    // An HTTP failure or malformed success can follow a committed write. This
    // asks observers to read again; it never invents a publication locally.
    _pendingReconciliation = true;
    _changes.value++;
  }

  bool _definitiveRejection(String code) {
    final status = int.tryParse(code);
    return (status != null && status >= 400 && status < 500 && status != 408) ||
        const {
          '1101',
          '1102',
          '1301',
          '1308',
          'api_session_fence',
        }.contains(code) ||
        definitiveRejectionCodes.contains(code);
  }
}
