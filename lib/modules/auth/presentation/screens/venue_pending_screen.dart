import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/studio_rejection_error.dart';
import '../widgets/membership_pending_view.dart';
import 'venue_application_decision_screen.dart';

export '../widgets/membership_pending_view.dart' show PendingMembershipType;

class VenuePendingScreen extends StatelessWidget {
  const VenuePendingScreen({
    super.key,
    this.membershipType = PendingMembershipType.venue,
    this.statusAction,
    this.studioDecision,
    this.onReturnToLogin,
  });

  final PendingMembershipType membershipType;
  final Widget? statusAction;
  final StudioRejectionError? studioDecision;
  final VoidCallback? onReturnToLogin;

  @override
  Widget build(BuildContext context) {
    if (membershipType == PendingMembershipType.venue &&
        serviceLocator.isRegistered<AuthSessionManager>() &&
        serviceLocator<AuthSessionManager>()
            .session
            .isVenueApplicationSession) {
      return const VenueApplicationDecisionScreen();
    }
    return MembershipPendingView(
      membershipType: membershipType,
      statusAction: statusAction,
      studioDecision: studioDecision,
      onReturnToLogin:
          onReturnToLogin ??
          () async {
            await serviceLocator<AuthSessionManager>().logout();
            if (!context.mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (route) => false,
            );
          },
    );
  }
}
