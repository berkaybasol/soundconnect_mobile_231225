import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/auth/listener_profile_publication_access.dart';
import '../../../core/di/service_locator.dart';

/// Navigation only: the profile revalidates eligibility before showing a draft.
class TableGroupProfileDraftArgs {
  const TableGroupProfileDraftArgs({
    required this.tableGroupId,
    required this.expectedSession,
  });

  final String tableGroupId;
  final AuthSession expectedSession;
}

final _openingDraftProfiles = Expando<bool>('table-group-profile-draft');

Future<void> openTableGroupProfileDraft(
  BuildContext context, {
  required String tableGroupId,
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
      tableGroupId.trim().isEmpty ||
      !canPublishListenerProfile(manager.session) ||
      !identical(manager.session, expectedSession) ||
      ModalRoute.of(context)?.isCurrent != true ||
      _openingDraftProfiles[context] == true) {
    return;
  }
  _openingDraftProfiles[context] = true;
  try {
    await Navigator.of(context).pushNamed<void>(
      AppRoutes.listenerProfile,
      arguments: TableGroupProfileDraftArgs(
        tableGroupId: tableGroupId.trim(),
        expectedSession: expectedSession,
      ),
    );
  } finally {
    _openingDraftProfiles[context] = false;
  }
}
