import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/admin_backline_category_request.dart';
import '../../domain/entities/admin_dashboard_summary.dart';
import '../../domain/entities/admin_venue_application.dart';
import '../../domain/entities/admin_studio_application.dart';

enum AdminPanelStatus { idle, loading, actionLoading, failure }

class AdminPanelState {
  final AdminPanelStatus status;
  final AdminDashboardSummary summary;
  final List<AdminVenueApplication> venueApplications;
  final List<AdminStudioApplication> studioApplications;
  final int studioApplicationsPage;
  final bool studioApplicationsHasNext;
  final bool studioApplicationsLoadingMore;
  final List<AdminBacklineCategoryRequest> backlineCategoryRequests;
  final int backlineCategoryRequestsPage;
  final bool backlineCategoryRequestsHasNext;
  final bool backlineCategoryRequestsLoadingMore;
  final AdminBacklineCategoryRequestStatus?
  selectedBacklineCategoryRequestStatus;
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
    required this.studioApplicationsPage,
    required this.studioApplicationsHasNext,
    required this.studioApplicationsLoadingMore,
    required this.backlineCategoryRequests,
    required this.backlineCategoryRequestsPage,
    required this.backlineCategoryRequestsHasNext,
    required this.backlineCategoryRequestsLoadingMore,
    required this.selectedBacklineCategoryRequestStatus,
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
      studioApplicationsPage = 0,
      studioApplicationsHasNext = false,
      studioApplicationsLoadingMore = false,
      backlineCategoryRequests = const [],
      backlineCategoryRequestsPage = 0,
      backlineCategoryRequestsHasNext = false,
      backlineCategoryRequestsLoadingMore = false,
      selectedBacklineCategoryRequestStatus =
          AdminBacklineCategoryRequestStatus.pending,
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
    int? studioApplicationsPage,
    bool? studioApplicationsHasNext,
    bool? studioApplicationsLoadingMore,
    List<AdminBacklineCategoryRequest>? backlineCategoryRequests,
    int? backlineCategoryRequestsPage,
    bool? backlineCategoryRequestsHasNext,
    bool? backlineCategoryRequestsLoadingMore,
    Object? selectedBacklineCategoryRequestStatus = copyWithUnset,
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
      studioApplicationsPage:
          studioApplicationsPage ?? this.studioApplicationsPage,
      studioApplicationsHasNext:
          studioApplicationsHasNext ?? this.studioApplicationsHasNext,
      studioApplicationsLoadingMore:
          studioApplicationsLoadingMore ?? this.studioApplicationsLoadingMore,
      backlineCategoryRequests:
          backlineCategoryRequests ?? this.backlineCategoryRequests,
      backlineCategoryRequestsPage:
          backlineCategoryRequestsPage ?? this.backlineCategoryRequestsPage,
      backlineCategoryRequestsHasNext:
          backlineCategoryRequestsHasNext ??
          this.backlineCategoryRequestsHasNext,
      backlineCategoryRequestsLoadingMore:
          backlineCategoryRequestsLoadingMore ??
          this.backlineCategoryRequestsLoadingMore,
      selectedBacklineCategoryRequestStatus:
          identical(selectedBacklineCategoryRequestStatus, copyWithUnset)
          ? this.selectedBacklineCategoryRequestStatus
          : selectedBacklineCategoryRequestStatus
                as AdminBacklineCategoryRequestStatus?,
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
