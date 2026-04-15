import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../location/domain/location_repository.dart';
import '../../data/models/table_group_create_request.dart';
import '../../domain/table_group_repository.dart';
import 'table_group_create_state.dart';

class TableGroupCreateCubit extends Cubit<TableGroupCreateState> {
  final TableGroupRepository _tableGroupRepository;
  final LocationRepository _locationRepository;

  TableGroupCreateCubit({
    required TableGroupRepository tableGroupRepository,
    required LocationRepository locationRepository,
  }) : _tableGroupRepository = tableGroupRepository,
       _locationRepository = locationRepository,
       super(const TableGroupCreateState.idle());

  Future<void> loadCities() async {
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.loadingLocations,
        error: null,
      ),
    );
    final result = await _locationRepository.getCities();
    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: TableGroupCreateStatus.idle,
          cities: result.data ?? const [],
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.failure,
        error: result.error,
      ),
    );
  }

  Future<void> loadDistricts(String cityId) async {
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.loadingLocations,
        districts: const [],
        neighborhoods: const [],
        error: null,
      ),
    );
    final result = await _locationRepository.getDistricts(cityId);
    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: TableGroupCreateStatus.idle,
          districts: result.data ?? const [],
          neighborhoods: const [],
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.failure,
        error: result.error,
      ),
    );
  }

  Future<void> loadNeighborhoods(String districtId) async {
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.loadingLocations,
        neighborhoods: const [],
        error: null,
      ),
    );
    final result = await _locationRepository.getNeighborhoods(districtId);
    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: TableGroupCreateStatus.idle,
          neighborhoods: result.data ?? const [],
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.failure,
        error: result.error,
      ),
    );
  }

  Future<bool> createTableGroup(TableGroupCreateRequest request) async {
    emit(
      state.copyWith(status: TableGroupCreateStatus.submitting, error: null),
    );
    final result = await _tableGroupRepository.createTableGroup(request);
    if (result.isSuccess) {
      emit(state.copyWith(status: TableGroupCreateStatus.success, error: null));
      return true;
    }
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.failure,
        error: result.error,
      ),
    );
    return false;
  }
}
