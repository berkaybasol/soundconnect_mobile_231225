import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_session_manager.dart';
import '../../../core/network/api_client.dart';
import 'analytics_consent_store.dart';

/// Sends one present-time observation per verified foreground refresh.
/// Nothing is queued, replayed or sent after the foreground grant ends.
class AnalyticsLiveActivity {
  AnalyticsLiveActivity(this._api, this._sessions);

  static bool get enabled =>
      const bool.fromEnvironment('SOUNDCONNECT_LIVE_ANALYTICS_ENABLED') &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;
  final ApiClient _api;
  final AuthSessionManager _sessions;
  Completer<void>? _inFlight;
  String? _identity;

  void stop() {
    _inFlight?.complete();
    _inFlight = null;
    _identity = null;
  }

  Future<void> record(AnalyticsPreference preference) async {
    final session = _sessions.session;
    final guest = !session.isAuthenticated;
    final id = guest ? preference.guestLiveId : preference.identity;
    if (preference.choice != ConsentChoice.granted || id == null) {
      stop();
      return;
    }
    if (_identity != id) stop();
    if (_inFlight != null) return;
    _identity = id;
    final cancellation = Completer<void>();
    _inFlight = cancellation;
    try {
      await _api.request<void>(
        ApiHttpMethod.post,
        '/api/v1/analytics/live-activity/${guest ? 'guest' : 'member'}',
        body: {
          (guest ? 'installationId' : 'analyticsUserId'): id,
          'policyVersion': AnalyticsPreference.policy,
        },
        requestContext: ApiRequestContext(
          requireGuestSession: guest,
          expectedSessionKey: guest ? null : session.userId,
          expectedToken: guest ? null : session.token,
          expectedCredentialRevision: _sessions.credentialRevision,
          cancelOn: cancellation.future,
        ),
        decoder: (_) {},
      );
      if (kDebugMode && identical(_inFlight, cancellation)) {
        debugPrint(
          'SoundConnect live activity accepted (${guest ? 'guest' : 'member'})',
        );
      }
    } catch (_) {
      // A later foreground check may send a fresh observation.
    } finally {
      if (identical(_inFlight, cancellation)) _inFlight = null;
    }
  }
}
