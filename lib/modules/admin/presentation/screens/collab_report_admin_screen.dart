import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../collab/domain/collab_types.dart';
import '../../../collab/presentation/widgets/collab_management_widgets.dart';
import '../../data/collab_report_admin_repository.dart';
import '../../domain/collab_report_admin.dart';
import '../../domain/collab_report_admin_access.dart';
import '../widgets/admin_panel_frame.dart';
import '../widgets/admin_report_list.dart';
import 'collab_report_review_screen.dart';

class CollabReportAdminScreen extends StatelessWidget {
  const CollabReportAdminScreen({
    super.key,
    required this.sessions,
    required this.repository,
    this.initialSession,
    this.frame,
  });

  final AuthSessionManager sessions;
  final AuthSession? initialSession;
  final CollabReportAdminRepository repository;
  final AdminSubpageFrame? frame;

  @override
  Widget build(BuildContext context) =>
      AdminReportList<
        CollabReportStatus,
        CollabReportReason,
        CollabAdminReport
      >(
        sessions: sessions,
        initialSession: initialSession,
        frame: frame,
        title: 'Collab şikâyetleri',
        statuses: CollabReportStatus.values,
        statusLabel: (s) => s.label,
        filterTitle: 'Şikâyet nedeni',
        filters: CollabReportReason.values,
        filterLabel: (r) => r.label,
        canRead: canManageCollabReports,
        isAccessError: isCollabReportAccessError,
        accessMessage: collabReportAccessLostMessage,
        load: (status, reason, page) =>
            repository.load(status: status, reason: reason, page: page),
        id: (r) => r.id,
        rowTitle: (r) => r.listingTitle,
        rowSubtitle: (r) =>
            '${r.reason.label} · ${collabShortDate(r.reportedAt)}',
        review: (r, access, deny) => CollabReportReviewScreen(
          reportId: r.id,
          repository: repository,
          access: access,
          onAccessLost: deny,
          frame: frame,
        ),
      );
}
