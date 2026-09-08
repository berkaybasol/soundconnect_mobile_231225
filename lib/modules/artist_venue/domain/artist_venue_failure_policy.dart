import '../../../core/error/app_error.dart';

/// These errors revoke the currently displayed private management snapshot.
bool artistVenueAccessLost(AppError? error) => const {
  '401',
  '403',
  '1101',
  '1102',
  '1103',
  'api_session_fence',
  '1001',
  '1301',
  '7001',
  '9203',
}.contains(error?.code);

/// A decision from another screen/device must not leave actionable stale rows.
bool artistVenueDecisionChanged(AppError? error) => const {
  '404',
  '409',
  '1501',
  '1502',
  '1503',
  '1504',
  '1507',
  '1510',
}.contains(error?.code);
