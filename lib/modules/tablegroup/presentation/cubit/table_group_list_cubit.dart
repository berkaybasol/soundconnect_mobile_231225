import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../location/domain/location_repository.dart';
import '../../domain/table_group_repository.dart';
import 'table_group_list_state.dart';

class TableGroupListCubit extends Cubit<TableGroupListState> {
  final TableGroupRepository _tableGroupRepository;
  final LocationRepository _locationRepository;

  TableGroupListCubit({
    required TableGroupRepository tableGroupRepository,
    required LocationRepository locationRepository,
  }) : _tableGroupRepository = tableGroupRepository,
       _locationRepository = locationRepository,
       super(const TableGroupListState.idle());

  Future<void> initialize() async {
    emit(state.copyWith(status: TableGroupListStatus.loading, error: null));
    final cityResult = await _locationRepository.getCities();
    if (!cityResult.isSuccess) {
      emit(
        state.copyWith(
          status: TableGroupListStatus.failure,
          error: cityResult.error,
        ),
      );
      return;
    }
    final cities = cityResult.data ?? const [];
    final cityId = cities.isNotEmpty ? cities.first.id : null;

    emit(
      state.copyWith(
        status: TableGroupListStatus.idle,
        cities: cities,
        selectedCityId: cityId,
        districts: const [],
        neighborhoods: const [],
        selectedDistrictId: null,
        selectedNeighborhoodId: null,
        error: null,
      ),
    );

    if (cityId != null) {
      await loadDistricts(cityId);
      await reload();
    }
  }

  Future<void> setCity(String? cityId) async {
    emit(
      state.copyWith(
        selectedCityId: cityId,
        selectedDistrictId: null,
        selectedNeighborhoodId: null,
        districts: const [],
        neighborhoods: const [],
      ),
    );
    if (cityId == null || cityId.isEmpty) {
      await reload();
      return;
    }
    await loadDistricts(cityId);
    await reload();
  }

  Future<void> loadDistricts(String cityId) async {
    final result = await _locationRepository.getDistricts(cityId);
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: TableGroupListStatus.failure,
          error: result.error,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        districts: result.data ?? const [],
        neighborhoods: const [],
        selectedDistrictId: null,
        selectedNeighborhoodId: null,
      ),
    );
  }

  Future<void> setDistrict(String? districtId) async {
    emit(
      state.copyWith(
        selectedDistrictId: districtId,
        selectedNeighborhoodId: null,
        neighborhoods: const [],
      ),
    );
    if (districtId != null && districtId.isNotEmpty) {
      final result = await _locationRepository.getNeighborhoods(districtId);
      if (!result.isSuccess) {
        emit(
          state.copyWith(
            status: TableGroupListStatus.failure,
            error: result.error,
          ),
        );
        return;
      }
      emit(state.copyWith(neighborhoods: result.data ?? const []));
    }
    await reload();
  }

  Future<void> setNeighborhood(String? neighborhoodId) async {
    emit(state.copyWith(selectedNeighborhoodId: neighborhoodId));
    await reload();
  }

  Future<void> reload() async {
    final cityId = state.selectedCityId;
    if (cityId == null || cityId.isEmpty) {
      emit(state.copyWith(items: const [], hasNext: false, page: 0));
      return;
    }

    emit(state.copyWith(status: TableGroupListStatus.loading, error: null));
    final result = await _tableGroupRepository.listActiveTableGroups(
      cityId: cityId,
      districtId: state.selectedDistrictId,
      neighborhoodId: state.selectedNeighborhoodId,
      page: 0,
      size: 20,
    );
    if (!result.isSuccess || result.data == null) {
      emit(
        state.copyWith(
          status: TableGroupListStatus.failure,
          error: result.error,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: TableGroupListStatus.idle,
        items: result.data!.items,
        hasNext: result.data!.hasNext,
        page: 0,
        error: null,
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.status == TableGroupListStatus.loadingMore ||
        state.status == TableGroupListStatus.loading ||
        !state.hasNext) {
      return;
    }
    final cityId = state.selectedCityId;
    if (cityId == null || cityId.isEmpty) return;

    emit(state.copyWith(status: TableGroupListStatus.loadingMore, error: null));

    final nextPage = state.page + 1;
    final result = await _tableGroupRepository.listActiveTableGroups(
      cityId: cityId,
      districtId: state.selectedDistrictId,
      neighborhoodId: state.selectedNeighborhoodId,
      page: nextPage,
      size: 20,
    );
    if (!result.isSuccess || result.data == null) {
      emit(
        state.copyWith(
          status: TableGroupListStatus.failure,
          error: result.error,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: TableGroupListStatus.idle,
        items: [...state.items, ...result.data!.items],
        hasNext: result.data!.hasNext,
        page: nextPage,
        error: null,
      ),
    );
  }

  Future<bool> joinTableGroup({
    required String tableGroupId,
    String? note,
  }) async {
    final currentJoining = Set<String>.from(state.joiningIds)
      ..add(tableGroupId);
    emit(state.copyWith(joiningIds: currentJoining));

    final result = await _tableGroupRepository.joinTableGroup(
      tableGroupId: tableGroupId,
      note: note,
    );
    final updatedJoining = Set<String>.from(state.joiningIds)
      ..remove(tableGroupId);
    emit(state.copyWith(joiningIds: updatedJoining));

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: TableGroupListStatus.failure,
          error: result.error,
        ),
      );
      return false;
    }
    await reload();
    return true;
  }
}
