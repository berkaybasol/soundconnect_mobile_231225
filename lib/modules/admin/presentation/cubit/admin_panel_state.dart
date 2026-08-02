import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/admin_dashboard_summary.dart';
import '../../domain/entities/admin_venue_application.dart';
import '../../domain/entities/admin_studio_application.dart';

enum AdminPanelStatus { idle, loading, actionLoading, failure }

class AdminPanelState {
  final AdminPanelStatus status;
  final AdminDashboardSummary summary;
  final List<AdminVenueApplication> venueApplications;
  final List<AdminStudioApplication> studioApplications;
  final AdminVenueApplicationStatus selectedStatus;
  final Set<String> actionIds;
  final AppError? summaryError;
  final AppError? applicationsError;
  final AppError? actionError;

  AppError? get error => actionError ?? applicationsError ?? summaryError;

  const AdminPanelState({
    required this.status,
    required this.summary,
    required this.venueApplications,
    required this.studioApplications,
    required this.selectedStatus,
    required this.actionIds,
    this.summaryError,
    this.applicationsError,
    this.actionError,
  });

  const AdminPanelState.initial()
    : status = AdminPanelStatus.idle,
      summary = const AdminDashboardSummary.empty(),
      venueApplications = const [],
      studioApplications = const [],
      selectedStatus = AdminVenueApplicationStatus.pending,
      actionIds = const <String>{},
      summaryError = null,
      applicationsError = null,
      actionError = null;

  AdminPanelState copyWith({
    AdminPanelStatus? status,
    AdminDashboardSummary? summary,
    List<AdminVenueApplication>? venueApplications,
    List<AdminStudioApplication>? studioApplications,
    AdminVenueApplicationStatus? selectedStatus,
    Set<String>? actionIds,
    Object? summaryError = copyWithUnset,
    Object? applicationsError = copyWithUnset,
    Object? actionError = copyWithUnset,
  }) {
    return AdminPanelState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      venueApplications: venueApplications ?? this.venueApplications,
      studioApplications: studioApplications ?? this.studioApplications,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      actionIds: actionIds ?? this.actionIds,
      summaryError: identical(summaryError, copyWithUnset)
          ? this.summaryError
          : summaryError as AppError?,
      applicationsError: identical(applicationsError, copyWithUnset)
          ? this.applicationsError
          : applicationsError as AppError?,
      actionError: identical(actionError, copyWithUnset)
          ? this.actionError
          : actionError as AppError?,
    );
  }
}
