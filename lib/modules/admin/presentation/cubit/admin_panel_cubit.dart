import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../domain/admin_repository.dart';
import '../../domain/entities/admin_venue_application.dart';
import 'admin_panel_state.dart';

class AdminPanelCubit extends Cubit<AdminPanelState> {
  AdminPanelCubit(this._adminRepository)
    : super(const AdminPanelState.initial());

  final AdminRepository _adminRepository;
  int _reloadGeneration = 0;
  int _applicationsGeneration = 0;

  Future<void> initialize() => _reloadAll();

  Future<void> refresh() => _reloadAll();

  Future<void> _reloadAll() async {
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
    await loadVenueApplications(state.selectedStatus);
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
}
