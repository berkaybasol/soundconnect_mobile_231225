import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../domain/admin_repository.dart';
import '../../domain/entities/admin_backline_category_request.dart';
import '../../domain/entities/admin_collab_report.dart';
import '../../domain/entities/admin_venue_application.dart';
import '../../domain/entities/admin_studio_application.dart';
import 'admin_panel_state.dart';

class AdminPanelCubit extends Cubit<AdminPanelState> {
  AdminPanelCubit(this._adminRepository)
    : super(const AdminPanelState.initial());

  final AdminRepository _adminRepository;
  int _reloadGeneration = 0;
  int _applicationsGeneration = 0;

  Future<void> initialize() => _reloadAll(
    loadStudio: false,
    loadBacklineCategoryRequests: false,
    loadCollabReports: false,
  );

  Future<void> refresh({
    bool loadStudio = false,
    bool loadBacklineCategoryRequests = false,
    bool loadCollabReports = false,
  }) => _reloadAll(
    loadStudio: loadStudio,
    loadBacklineCategoryRequests: loadBacklineCategoryRequests,
    loadCollabReports: loadCollabReports,
  );

  Future<void> _reloadAll({
    required bool loadStudio,
    required bool loadBacklineCategoryRequests,
    required bool loadCollabReports,
  }) async {
    assert(
      <bool>[
            loadStudio,
            loadBacklineCategoryRequests,
            loadCollabReports,
          ].where((selected) => selected).length <=
          1,
    );
    final generation = ++_reloadGeneration;
    _applicationsGeneration += 1;
    emit(
      state.copyWith(
        status: AdminPanelStatus.loading,
        summaryError: null,
        applicationsError: null,
        actionError: null,
      ),
    );
    await _loadSummary(generation);
    if (generation != _reloadGeneration || isClosed) return;
    if (loadCollabReports) {
      await loadCollabReportsList(
        state.selectedCollabReportStatus,
        state.selectedCollabReportReason,
      );
    } else if (loadBacklineCategoryRequests) {
      await loadBacklineCategoryRequestsList(
        state.selectedBacklineCategoryRequestStatus,
      );
    } else if (loadStudio) {
      await loadStudioApplications(state.selectedStatus);
    } else {
      await loadVenueApplications(state.selectedStatus);
    }
  }

  Future<void> loadVenueApplications(AdminVenueApplicationStatus status) async {
    final generation = ++_applicationsGeneration;
    emit(
      state.copyWith(
        status: AdminPanelStatus.loading,
        selectedStatus: status,
        applicationsError: null,
        actionError: null,
      ),
    );
    final result = await _adminRepository.getVenueApplicationsByStatus(status);
    if (generation != _applicationsGeneration || isClosed) return;

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: AdminPanelStatus.failure,
          applicationsError: result.error,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: state.summaryError == null
            ? AdminPanelStatus.idle
            : AdminPanelStatus.failure,
        venueApplications: result.data ?? const [],
        applicationsError: null,
      ),
    );
  }

  Future<void> approveVenueApplication(String id) async {
    await _runApplicationAction(
      id,
      () => _adminRepository.approveVenueApplication(id),
    );
  }

  Future<void> rejectVenueApplication({
    required String id,
    required String reason,
  }) async {
    await _runApplicationAction(
      id,
      () => _adminRepository.rejectVenueApplication(id: id, reason: reason),
    );
  }

  Future<void> loadStudioApplications(
    AdminVenueApplicationStatus status, {
    bool loadMore = false,
  }) async {
    if (loadMore &&
        (state.studioApplicationsLoadingMore ||
            !state.studioApplicationsHasNext)) {
      return;
    }
    final generation = ++_applicationsGeneration;
    final requestedPage = loadMore ? state.studioApplicationsPage + 1 : 0;
    emit(
      state.copyWith(
        status: loadMore ? state.status : AdminPanelStatus.loading,
        selectedStatus: status,
        applicationsError: null,
        actionError: null,
        studioApplicationsLoadingMore: loadMore,
      ),
    );
    final result = await _adminRepository.getStudioApplicationsByStatus(
      status,
      page: requestedPage,
    );
    if (generation != _applicationsGeneration || isClosed) return;
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: AdminPanelStatus.failure,
          applicationsError: result.error,
          studioApplicationsLoadingMore: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: state.summaryError == null
            ? AdminPanelStatus.idle
            : AdminPanelStatus.failure,
        studioApplications: loadMore
            ? _mergeStudioApplications(
                state.studioApplications,
                result.data?.items ?? const <AdminStudioApplication>[],
              )
            : result.data?.items ?? const <AdminStudioApplication>[],
        studioApplicationsPage: requestedPage,
        studioApplicationsHasNext: result.data?.hasNext ?? false,
        studioApplicationsLoadingMore: false,
        applicationsError: null,
      ),
    );
  }

  Future<void> loadMoreStudioApplications() =>
      loadStudioApplications(state.selectedStatus, loadMore: true);

  List<AdminStudioApplication> _mergeStudioApplications(
    List<AdminStudioApplication> current,
    List<AdminStudioApplication> next,
  ) {
    final byId = <String, AdminStudioApplication>{
      for (final application in current) application.id: application,
      for (final application in next) application.id: application,
    };
    return List<AdminStudioApplication>.unmodifiable(byId.values);
  }

  Future<void> approveStudioApplication(String id) async {
    await _runStudioApplicationAction(
      id,
      () => _adminRepository.approveStudioApplication(id),
    );
  }

  Future<void> rejectStudioApplication({
    required String id,
    required String reason,
  }) async {
    await _runStudioApplicationAction(
      id,
      () => _adminRepository.rejectStudioApplication(id: id, reason: reason),
    );
  }

  Future<void> loadBacklineCategoryRequestsList(
    AdminBacklineCategoryRequestStatus? status, {
    bool loadMore = false,
  }) async {
    if (loadMore &&
        (state.backlineCategoryRequestsLoadingMore ||
            !state.backlineCategoryRequestsHasNext)) {
      return;
    }
    final generation = ++_applicationsGeneration;
    final requestedPage = loadMore ? state.backlineCategoryRequestsPage + 1 : 0;
    emit(
      state.copyWith(
        status: loadMore ? state.status : AdminPanelStatus.loading,
        selectedBacklineCategoryRequestStatus: status,
        applicationsError: null,
        actionError: null,
        backlineCategoryRequestsLoadingMore: loadMore,
      ),
    );
    final result = await _adminRepository.getBacklineCategoryRequests(
      status: status,
      page: requestedPage,
    );
    if (generation != _applicationsGeneration || isClosed) return;
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: AdminPanelStatus.failure,
          applicationsError: result.error,
          backlineCategoryRequestsLoadingMore: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: state.summaryError == null
            ? AdminPanelStatus.idle
            : AdminPanelStatus.failure,
        backlineCategoryRequests: loadMore
            ? _mergeBacklineCategoryRequests(
                state.backlineCategoryRequests,
                result.data?.items ?? const <AdminBacklineCategoryRequest>[],
              )
            : result.data?.items ?? const <AdminBacklineCategoryRequest>[],
        backlineCategoryRequestsPage: requestedPage,
        backlineCategoryRequestsHasNext: result.data?.hasNext ?? false,
        backlineCategoryRequestsLoadingMore: false,
        applicationsError: null,
      ),
    );
  }

  Future<void> loadMoreBacklineCategoryRequests() =>
      loadBacklineCategoryRequestsList(
        state.selectedBacklineCategoryRequestStatus,
        loadMore: true,
      );

  Future<void> loadCollabReportsList(
    AdminCollabReportStatus? status,
    AdminCollabReportReason? reason, {
    bool loadMore = false,
  }) async {
    if (loadMore &&
        (state.collabReportsLoadingMore || !state.collabReportsHasNext)) {
      return;
    }
    final generation = ++_applicationsGeneration;
    final requestedPage = loadMore ? state.collabReportsPage + 1 : 0;
    emit(
      state.copyWith(
        status: loadMore ? state.status : AdminPanelStatus.loading,
        selectedCollabReportStatus: status,
        selectedCollabReportReason: reason,
        applicationsError: null,
        actionError: null,
        collabReportsLoadingMore: loadMore,
      ),
    );
    final result = await _adminRepository.getCollabReports(
      status: status,
      reason: reason,
      page: requestedPage,
    );
    if (generation != _applicationsGeneration || isClosed) return;
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: AdminPanelStatus.failure,
          applicationsError: result.error,
          collabReportsLoadingMore: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: state.summaryError == null
            ? AdminPanelStatus.idle
            : AdminPanelStatus.failure,
        collabReports: loadMore
            ? _mergeCollabReports(
                state.collabReports,
                result.data?.items ?? const <AdminCollabReport>[],
              )
            : result.data?.items ?? const <AdminCollabReport>[],
        collabReportsPage: requestedPage,
        collabReportsHasNext: result.data?.hasNext ?? false,
        collabReportsLoadingMore: false,
        applicationsError: null,
      ),
    );
  }

  Future<void> loadMoreCollabReports() => loadCollabReportsList(
    state.selectedCollabReportStatus,
    state.selectedCollabReportReason,
    loadMore: true,
  );

  List<AdminCollabReport> _mergeCollabReports(
    List<AdminCollabReport> current,
    List<AdminCollabReport> next,
  ) {
    final byId = <String, AdminCollabReport>{
      for (final report in current) report.id: report,
      for (final report in next) report.id: report,
    };
    return List<AdminCollabReport>.unmodifiable(byId.values);
  }

  Future<void> dismissCollabReport({
    required String id,
    required int expectedVersion,
    required String resolutionNote,
  }) => _runCollabReportAction(
    id,
    () => _adminRepository.reviewCollabReport(
      id: id,
      expectedVersion: expectedVersion,
      decision: AdminCollabReportDecision.dismiss,
      resolutionNote: resolutionNote,
    ),
  );

  Future<void> removeReportedCollabListing({
    required String id,
    required int expectedVersion,
    required String resolutionNote,
  }) => _runCollabReportAction(
    id,
    () => _adminRepository.reviewCollabReport(
      id: id,
      expectedVersion: expectedVersion,
      decision: AdminCollabReportDecision.removeListing,
      resolutionNote: resolutionNote,
    ),
  );

  List<AdminBacklineCategoryRequest> _mergeBacklineCategoryRequests(
    List<AdminBacklineCategoryRequest> current,
    List<AdminBacklineCategoryRequest> next,
  ) {
    final byId = <String, AdminBacklineCategoryRequest>{
      for (final request in current) request.id: request,
      for (final request in next) request.id: request,
    };
    return List<AdminBacklineCategoryRequest>.unmodifiable(byId.values);
  }

  Future<void> approveBacklineCategoryRequest({
    required String id,
    String? note,
  }) => _runBacklineCategoryRequestAction(
    id,
    () => _adminRepository.reviewBacklineCategoryRequest(
      id: id,
      decision: AdminBacklineCategoryReviewDecision.approve,
      note: note,
    ),
  );

  Future<void> rejectBacklineCategoryRequest({
    required String id,
    required String reason,
  }) => _runBacklineCategoryRequestAction(
    id,
    () => _adminRepository.reviewBacklineCategoryRequest(
      id: id,
      decision: AdminBacklineCategoryReviewDecision.reject,
      note: reason,
    ),
  );

  Future<void> _loadSummary(int generation) async {
    final result = await _adminRepository.getDashboardSummary();
    if (generation != _reloadGeneration || isClosed) return;

    final summary = result.data;
    if (!result.isSuccess || summary == null) {
      emit(
        state.copyWith(
          status: AdminPanelStatus.failure,
          summaryError: result.error,
        ),
      );
      return;
    }
    emit(state.copyWith(summary: summary, summaryError: null));
  }

  Future<void> _runApplicationAction(
    String id,
    Future<Result<AdminVenueApplication>> Function() action,
  ) async {
    final nextActionIds = Set<String>.from(state.actionIds)..add(id);
    emit(
      state.copyWith(
        status: AdminPanelStatus.actionLoading,
        actionIds: nextActionIds,
        actionError: null,
      ),
    );
    final result = await action();
    if (isClosed) return;
    final updatedActionIds = Set<String>.from(state.actionIds)..remove(id);

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: AdminPanelStatus.failure,
          actionIds: updatedActionIds,
          actionError: result.error,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: updatedActionIds.isEmpty
            ? AdminPanelStatus.idle
            : AdminPanelStatus.actionLoading,
        actionIds: updatedActionIds,
        actionError: null,
      ),
    );
    await refresh();
  }

  Future<void> _runStudioApplicationAction(
    String id,
    Future<Result<AdminStudioApplication>> Function() action,
  ) async {
    final nextActionIds = Set<String>.from(state.actionIds)..add(id);
    emit(
      state.copyWith(
        status: AdminPanelStatus.actionLoading,
        actionIds: nextActionIds,
        actionError: null,
      ),
    );
    final result = await action();
    if (isClosed) return;
    final updatedActionIds = Set<String>.from(state.actionIds)..remove(id);
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: AdminPanelStatus.failure,
          actionIds: updatedActionIds,
          actionError: result.error,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: updatedActionIds.isEmpty
            ? AdminPanelStatus.idle
            : AdminPanelStatus.actionLoading,
        actionIds: updatedActionIds,
        actionError: null,
      ),
    );
    await refresh(loadStudio: true);
  }

  Future<void> _runBacklineCategoryRequestAction(
    String id,
    Future<Result<AdminBacklineCategoryRequest>> Function() action,
  ) async {
    final nextActionIds = Set<String>.from(state.actionIds)..add(id);
    emit(
      state.copyWith(
        status: AdminPanelStatus.actionLoading,
        actionIds: nextActionIds,
        actionError: null,
      ),
    );
    final result = await action();
    if (isClosed) return;
    final updatedActionIds = Set<String>.from(state.actionIds)..remove(id);
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: AdminPanelStatus.failure,
          actionIds: updatedActionIds,
          actionError: result.error,
        ),
      );
      if (const <String>{'409', '9834'}.contains(result.error?.code)) {
        await loadBacklineCategoryRequestsList(
          state.selectedBacklineCategoryRequestStatus,
        );
      }
      return;
    }
    emit(
      state.copyWith(
        status: updatedActionIds.isEmpty
            ? AdminPanelStatus.idle
            : AdminPanelStatus.actionLoading,
        actionIds: updatedActionIds,
        actionError: null,
      ),
    );
    await loadBacklineCategoryRequestsList(
      state.selectedBacklineCategoryRequestStatus,
    );
  }

  Future<void> _runCollabReportAction(
    String id,
    Future<Result<AdminCollabReport>> Function() action,
  ) async {
    final nextActionIds = Set<String>.from(state.actionIds)..add(id);
    emit(
      state.copyWith(
        status: AdminPanelStatus.actionLoading,
        actionIds: nextActionIds,
        actionError: null,
      ),
    );
    final result = await action();
    if (isClosed) return;
    final updatedActionIds = Set<String>.from(state.actionIds)..remove(id);
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: AdminPanelStatus.failure,
          actionIds: updatedActionIds,
          actionError: result.error,
        ),
      );
      if (const <String>{'409', '9317', '9324'}.contains(result.error?.code)) {
        await loadCollabReportsList(
          state.selectedCollabReportStatus,
          state.selectedCollabReportReason,
        );
      }
      return;
    }
    emit(
      state.copyWith(
        status: updatedActionIds.isEmpty
            ? AdminPanelStatus.idle
            : AdminPanelStatus.actionLoading,
        actionIds: updatedActionIds,
        actionError: null,
      ),
    );
    await loadCollabReportsList(
      state.selectedCollabReportStatus,
      state.selectedCollabReportReason,
    );
  }
}
