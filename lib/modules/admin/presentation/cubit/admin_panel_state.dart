import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/admin_dashboard_summary.dart';
import '../../domain/entities/admin_venue_application.dart';

enum AdminPanelStatus { idle, loading, actionLoading, failure }

class AdminPanelState {
  final AdminPanelStatus status;
  final AdminDashboardSummary summary;
  final List<AdminVenueApplication> venueApplications;
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
      selectedStatus = AdminVenueApplicationStatus.pending,
      actionIds = const <String>{},
      summaryError = null,
      applicationsError = null,
      actionError = null;

  AdminPanelState copyWith({
    AdminPanelStatus? status,
    AdminDashboardSummary? summary,
    List<AdminVenueApplication>? venueApplications,
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
