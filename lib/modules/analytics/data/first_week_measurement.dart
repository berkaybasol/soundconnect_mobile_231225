import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_session_manager.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

const firstActionTypes = {
  'table_join_requested',
  'table_created',
  'overthinking_published',
  'profile_share_published',
  'comment_published',
  'profile_media_uploaded',
  'spotify_track_added',
  'band_created',
  'band_joined',
  'venue_musician_connected',
  'venue_band_connected',
  'collab_published',
  'market_listing_published',
  'collab_applied',
  'venue_event_published',
  'studio_room_created',
  'backline_equipment_added',
};

class FirstWeekMeasurement {
  FirstWeekMeasurement(this.api, this.sessions);
  final ApiClient api;
  final AuthSessionManager sessions;

  ApiRequestContext get _context => ApiRequestContext(
    expectedSessionKey: sessions.session.userId,
    expectedToken: sessions.session.token,
    expectedCredentialRevision: sessions.credentialRevision,
  );

  Future<bool> duration(
    String identity,
    DateTime start,
    int milliseconds,
    bool Function() stillActive,
  ) async {
    final context = _context;
    final body = {
      'analyticsUserId': identity,
      'sampleId': const Uuid().v4(),
      'startedAt': start.toUtc().toIso8601String(),
      'durationMs': milliseconds,
    };
    Future<bool> send() => api.request(
      ApiHttpMethod.post,
      '/api/v1/users/me/analytics-first-week-duration',
      requestContext: context,
      body: body,
      decoder: (data) {
        if (data is! Map || data['windowOpen'] is! bool) {
          throw const FormatException();
        }
        return data['windowOpen'] as bool;
      },
    );
    try {
      return await send();
    } on ApiException catch (e) {
      if (e.error.code != 'network') rethrow;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!stillActive()) rethrow;
      return send();
    }
  }

  Future<({String action, String profile, DateTime occurredAt})?> claim(
    String identity,
  ) => api.request(
    ApiHttpMethod.post,
    '/api/v1/users/me/analytics-first-action/claim',
    requestContext: _context,
    body: {'analyticsUserId': identity},
    decoder: (data) {
      if (data == null) return null;
      if (data is! Map ||
          data['actionType'] is! String ||
          !firstActionTypes.contains(data['actionType']) ||
          data['profileType'] is! String ||
          data['occurredAt'] is! String) {
        throw const FormatException();
      }
      return (
        action: data['actionType'] as String,
        profile: (data['profileType'] as String).toLowerCase(),
        occurredAt: DateTime.parse(data['occurredAt'] as String).toUtc(),
      );
    },
  );
}
