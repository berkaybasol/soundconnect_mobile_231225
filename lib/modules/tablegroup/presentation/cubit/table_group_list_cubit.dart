import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../location/domain/entities/city.dart';
import '../../../location/domain/location_repository.dart';
import '../../domain/entities/table_group.dart';
import '../../domain/table_group_repository.dart';
import 'table_group_list_state.dart';

typedef _MetadataLoadOutcome = ({bool applied, AppError? error});

class TableGroupListCubit extends Cubit<TableGroupListState> {
  final TableGroupRepository _tableGroupRepository;
  final LocationRepository _locationRepository;
  final bool Function() _canCreateOrJoin;
  int _districtRequestGeneration = 0;
  int _neighborhoodRequestGeneration = 0;
  int _listRequestGeneration = 0;
  int _initializeRequestGeneration = 0;
  Future<Result<List<City>>>? _citiesRequest;

  TableGroupListCubit({
    required TableGroupRepository tableGroupRepository,
    required LocationRepository locationRepository,
    bool Function()? canCreateOrJoin,
  }) : _tableGroupRepository = tableGroupRepository,
       _locationRepository = locationRepository,
       _canCreateOrJoin = canCreateOrJoin ?? _allowTableGroupMutation,
       super(const TableGroupListState.idle());

  static bool _allowTableGroupMutation() => true;

  static const AppError _mutationForbiddenError = AppError(
    code: 'table_group_personal_identity_required',
    message:
        'Masa oluşturma ve katılma işlemleri kişisel hesaplarla kullanılabilir.',
  );

  Future<Result<List<City>>> _getCitiesShared() {
    final inFlight = _citiesRequest;
    if (inFlight != null) return inFlight;

    final request = _locationRepository.getCities();
    _citiesRequest = request;
    return request.whenComplete(() {
      if (identical(_citiesRequest, request)) _citiesRequest = null;
    });
  }

  Future<void> initialize() async {
    if (isClosed) return;
    final requestGeneration = ++_initializeRequestGeneration;
    emit(state.copyWith(status: TableGroupListStatus.loading, error: null));
    await _refreshLocationsAndTables(requestGeneration);
  }

  /// Refreshes the visible feed and retries a missing city catalog in
  /// parallel. The table request is deliberately not gated by location
  /// metadata, so a slow catalog cannot hide otherwise available tables.
  Future<void> refresh() async {
    if (isClosed) return;
    final requestGeneration = ++_initializeRequestGeneration;
    await _refreshLocationsAndTables(requestGeneration);
  }

  Future<void> _refreshLocationsAndTables(int requestGeneration) async {
    final cities = _loadCitiesForSelection(requestGeneration);
    await reload();
    final cityError = await cities;
    if (isClosed || requestGeneration != _initializeRequestGeneration) return;
    _surfaceMetadataError(cityError);
  }

  Future<void> setCity(String? cityId) async {
    if (isClosed) return;
    final requestGeneration = ++_initializeRequestGeneration;
    _listRequestGeneration += 1;
    _neighborhoodRequestGeneration += 1;
    final hasCity = cityId != null && cityId.isNotEmpty;
    emit(
      state.copyWith(
        status: TableGroupListStatus.loading,
        selectedCityId: cityId,
        selectedDistrictId: null,
        selectedNeighborhoodId: null,
        districts: const [],
        neighborhoods: const [],
        items: const [],
        totalElements: null,
        hasNext: false,
        page: 0,
        error: null,
      ),
    );
    if (!hasCity) {
      _districtRequestGeneration += 1;
      final cities = _loadCitiesForSelection(requestGeneration);
      await reload();
      final cityError = await cities;
      if (isClosed ||
          requestGeneration != _initializeRequestGeneration ||
          state.selectedCityId != null) {
        return;
      }
      _surfaceMetadataError(cityError);
      return;
    }

    // Location catalogs must not delay the selected city's tables. Sharing the
    // city request also lets a create result safely supersede initialization.
    final cities = _loadCitiesForSelection(requestGeneration);
    final districts = _loadDistricts(cityId, surfaceError: false);
    await reload();
    final cityError = await cities;
    final districtOutcome = await districts;
    if (isClosed ||
        requestGeneration != _initializeRequestGeneration ||
        state.selectedCityId != cityId) {
      return;
    }
    _surfaceMetadataError(cityError ?? districtOutcome.error);
  }

  Future<bool> loadDistricts(String cityId) async {
    final outcome = await _loadDistricts(cityId, surfaceError: true);
    return outcome.applied;
  }

  Future<_MetadataLoadOutcome> _loadDistricts(
    String cityId, {
    required bool surfaceError,
  }) async {
    if (isClosed) return (applied: false, error: null);
    final requestGeneration = ++_districtRequestGeneration;
    final result = await _locationRepository.getDistricts(cityId);
    if (isClosed || requestGeneration != _districtRequestGeneration) {
      return (applied: false, error: null);
    }
    if (state.selectedCityId != cityId) {
      return (applied: false, error: null);
    }
    if (!result.isSuccess) {
      if (surfaceError) _surfaceMetadataError(result.error);
      return (applied: false, error: result.error);
    }
    emit(
      state.copyWith(
        districts: result.data ?? const [],
        neighborhoods: const [],
        selectedDistrictId: null,
        selectedNeighborhoodId: null,
      ),
    );
    return (applied: true, error: null);
  }

  Future<void> setDistrict(String? districtId) async {
    if (isClosed) return;
    if (districtId != null && districtId.isNotEmpty) {
      _districtRequestGeneration += 1;
    }
    _listRequestGeneration += 1;
    final neighborhoodRequestGeneration = ++_neighborhoodRequestGeneration;
    emit(
      state.copyWith(
        selectedDistrictId: districtId,
        selectedNeighborhoodId: null,
        neighborhoods: const [],
      ),
    );
    final neighborhoods = districtId != null && districtId.isNotEmpty
        ? _loadNeighborhoodsForDistrict(
            districtId,
            neighborhoodRequestGeneration,
          )
        : Future<AppError?>.value();
    await reload();
    final neighborhoodError = await neighborhoods;
    if (isClosed ||
        neighborhoodRequestGeneration != _neighborhoodRequestGeneration ||
        state.selectedDistrictId != districtId) {
      return;
    }
    _surfaceMetadataError(neighborhoodError);
  }

  Future<AppError?> _loadCitiesForSelection(int requestGeneration) async {
    final selectedCityId = state.selectedCityId;
    if (state.cities.isNotEmpty &&
        (selectedCityId == null ||
            state.cities.any((city) => city.id == selectedCityId))) {
      return null;
    }
    final result = await _getCitiesShared();
    if (isClosed || requestGeneration != _initializeRequestGeneration) {
      return null;
    }
    if (!result.isSuccess) return result.error;
    emit(state.copyWith(cities: result.data ?? const []));
    return null;
  }

  Future<AppError?> _loadNeighborhoodsForDistrict(
    String districtId,
    int requestGeneration,
  ) async {
    final result = await _locationRepository.getNeighborhoods(districtId);
    if (isClosed ||
        requestGeneration != _neighborhoodRequestGeneration ||
        state.selectedDistrictId != districtId) {
      return null;
    }
    if (!result.isSuccess) return result.error;
    emit(state.copyWith(neighborhoods: result.data ?? const []));
    return null;
  }

  void _surfaceMetadataError(AppError? error) {
    if (isClosed ||
        error == null ||
        state.status == TableGroupListStatus.failure) {
      return;
    }
    emit(state.copyWith(status: TableGroupListStatus.failure, error: error));
  }

  Future<void> setNeighborhood(String? neighborhoodId) async {
    if (isClosed) return;
    _listRequestGeneration += 1;
    emit(state.copyWith(selectedNeighborhoodId: neighborhoodId));
    await reload();
  }

  Future<void> reload() async {
    if (isClosed) return;
    final cityId = state.selectedCityId;

    final requestGeneration = ++_listRequestGeneration;
    final districtId = state.selectedDistrictId;
    final neighborhoodId = state.selectedNeighborhoodId;
    emit(state.copyWith(status: TableGroupListStatus.loading, error: null));
    final result = await _tableGroupRepository.listActiveTableGroups(
      cityId: cityId,
      districtId: districtId,
      neighborhoodId: neighborhoodId,
      page: 0,
      size: 20,
    );
    if (isClosed || requestGeneration != _listRequestGeneration) return;
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
        totalElements: result.data!.totalElements,
        hasNext: result.data!.hasNext,
        page: 0,
        error: null,
      ),
    );
  }

  Future<void> loadMore() async {
    if (isClosed) return;
    if (state.status == TableGroupListStatus.loadingMore ||
        state.status == TableGroupListStatus.loading ||
        !state.hasNext) {
      return;
    }
    final cityId = state.selectedCityId;

    emit(state.copyWith(status: TableGroupListStatus.loadingMore, error: null));

    final nextPage = state.page + 1;
    final requestGeneration = ++_listRequestGeneration;
    final result = await _tableGroupRepository.listActiveTableGroups(
      cityId: cityId,
      districtId: state.selectedDistrictId,
      neighborhoodId: state.selectedNeighborhoodId,
      page: nextPage,
      size: 20,
    );
    if (isClosed || requestGeneration != _listRequestGeneration) return;
    if (!result.isSuccess || result.data == null) {
      emit(
        state.copyWith(
          status: TableGroupListStatus.failure,
          error: result.error,
        ),
      );
      return;
    }

    final seenIds = state.items.map((item) => item.id).toSet();
    final mergedItems = <TableGroup>[...state.items];
    for (final item in result.data!.items) {
      if (seenIds.add(item.id)) mergedItems.add(item);
    }

    emit(
      state.copyWith(
        status: TableGroupListStatus.idle,
        items: mergedItems,
        totalElements: result.data!.totalElements ?? state.totalElements,
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
    if (isClosed) return false;
    if (!_mutationAllowed()) {
      emit(
        state.copyWith(
          status: TableGroupListStatus.failure,
          error: _mutationForbiddenError,
        ),
      );
      return false;
    }
    if (state.joiningIds.contains(tableGroupId)) return false;
    final currentJoining = Set<String>.from(state.joiningIds)
      ..add(tableGroupId);
    emit(state.copyWith(joiningIds: currentJoining));

    final result = await _tableGroupRepository.joinTableGroup(
      tableGroupId: tableGroupId,
      note: note,
    );
    if (isClosed) return false;
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
    return !isClosed;
  }

  bool _mutationAllowed() {
    try {
      return _canCreateOrJoin();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() {
    _initializeRequestGeneration += 1;
    _districtRequestGeneration += 1;
    _neighborhoodRequestGeneration += 1;
    _listRequestGeneration += 1;
    return super.close();
  }
}
