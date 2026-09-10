import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/di/service_locator.dart';
import '../domain/overthinking_profile_share_access.dart';

/// Navigation only. The listener profile loads the original and publication
/// state before allowing the user to publish this in-memory draft.
class OverthinkingProfileDraftArgs {
  const OverthinkingProfileDraftArgs({
    required this.postId,
    required this.expectedSession,
  });

  final String postId;
  final AuthSession expectedSession;
}

final _openingDraftProfiles = Expando<bool>('overthinking-profile-draft');

Future<void> openOverthinkingProfileDraft(
  BuildContext context, {
  required String postId,
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
      postId.trim().isEmpty ||
      !canShareOverthinkingOnProfile(manager.session) ||
      !identical(manager.session, expectedSession) ||
      ModalRoute.of(context)?.isCurrent != true ||
      _openingDraftProfiles[context] == true) {
    return;
  }
  _openingDraftProfiles[context] = true;
  try {
    await Navigator.of(context).pushNamed<void>(
      AppRoutes.listenerProfile,
      arguments: OverthinkingProfileDraftArgs(
        postId: postId.trim(),
        expectedSession: expectedSession,
      ),
    );
  } finally {
    _openingDraftProfiles[context] = false;
  }
}
