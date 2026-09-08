import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/di/service_locator.dart';
import 'event_audience_controller.dart';

/// An in-memory navigation request, never a publication command. The profile
/// composer must load current server state and publish only on confirmation.
class EventAudienceProfileDraftArgs {
  const EventAudienceProfileDraftArgs({
    required this.eventId,
    required this.expectedSession,
  });

  final String eventId;
  final AuthSession expectedSession;
}

final _openingDraftProfiles = Expando<bool>('event-audience-profile-draft');

Future<void> openEventAudienceProfileDraft(
  BuildContext context, {
  required String eventId,
  required AuthSession expectedSession,
  AuthSessionManager? sessions,
}) async {
  final manager =
      sessions ??
      (serviceLocator.isRegistered<AuthSessionManager>()
          ? serviceLocator<AuthSessionManager>()
          : null);
  if (!context.mounted ||
      manager == null ||
      eventId.trim().isEmpty ||
      !canPublishAudienceProfile(manager.session) ||
      !sameEventAudienceSession(manager.session, expectedSession) ||
      ModalRoute.of(context)?.isCurrent != true ||
      _openingDraftProfiles[context] == true) {
    return;
  }
  _openingDraftProfiles[context] = true;
  try {
    await Navigator.of(context).pushNamed<void>(
      AppRoutes.listenerProfile,
      arguments: EventAudienceProfileDraftArgs(
        eventId: eventId.trim(),
        expectedSession: expectedSession,
      ),
    );
  } finally {
    _openingDraftProfiles[context] = false;
  }
}
