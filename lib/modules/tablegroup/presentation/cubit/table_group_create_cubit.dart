import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_error.dart';
import '../../../location/domain/location_repository.dart';
import '../../data/models/table_group_create_request.dart';
import '../../domain/entities/table_group_venue_option.dart';
import '../../domain/table_group_repository.dart';
import '../../domain/table_group_venue_option_repository.dart';
import 'table_group_create_state.dart';

class TableGroupCreateCubit extends Cubit<TableGroupCreateState> {
  final TableGroupRepository _tableGroupRepository;
  final LocationRepository _locationRepository;
  final TableGroupVenueOptionRepository _venueOptionRepository;
  final bool Function() _canCreateOrJoin;
  final Duration _venueSearchDebounce;
  int _locationRequestGeneration = 0;
  int _createRequestGeneration = 0;
  int _venueSearchGeneration = 0;
  String? _selectedCityId;
  String? _selectedDistrictId;
  TableGroupCreateRequest? _activeCreateRequest;
  Timer? _venueSearchTimer;

  TableGroupCreateCubit({
    required TableGroupRepository tableGroupRepository,
    required LocationRepository locationRepository,
    required TableGroupVenueOptionRepository venueOptionRepository,
    bool Function()? canCreateOrJoin,
    Duration venueSearchDebounce = const Duration(milliseconds: 300),
  }) : _tableGroupRepository = tableGroupRepository,
       _locationRepository = locationRepository,
       _venueOptionRepository = venueOptionRepository,
       _canCreateOrJoin = canCreateOrJoin ?? _allowTableGroupMutation,
       _venueSearchDebounce = venueSearchDebounce,
       super(const TableGroupCreateState.idle());

  static bool _allowTableGroupMutation() => true;

  static const AppError _mutationForbiddenError = AppError(
    code: 'table_group_personal_identity_required',
    message:
        'Masa oluşturma ve katılma işlemleri kişisel hesaplarla kullanılabilir.',
  );

  static const AppError _venueIdentityInvalidError = AppError(
    code: 'table_group_venue_identity_invalid',
    message: 'Mekân seçimi formdaki açık/kapalı durumuyla eşleşmiyor.',
  );

  static const AppError _descriptionInvalidError = AppError(
    code: 'table_group_description_invalid',
    message: 'Masa açıklaması 1-280 karakter arasında olmalı.',
  );

  void enableSpecificVenue() {
    if (!_pickerMutationAllowed || state.hasSpecificVenue) return;
    _venueSearchTimer?.cancel();
    _venueSearchGeneration += 1;
    emit(
      state.copyWith(
        venueMode: TableGroupVenueMode.custom,
        selectedVenue: null,
        venueOptions: const <TableGroupVenueOption>[],
        venueQuery: '',
        venueSearchLoading: false,
        venueSuggestionsVisible: false,
        venueSearchError: null,
      ),
    );
  }

  void disableSpecificVenue() {
    if (!_pickerMutationAllowed || !state.hasSpecificVenue) return;
    final leavingRegisteredVenue =
        state.venueMode == TableGroupVenueMode.registered;
    _venueSearchTimer?.cancel();
    _venueSearchGeneration += 1;
    if (leavingRegisteredVenue) {
      _selectedCityId = null;
      _selectedDistrictId = null;
      _locationRequestGeneration += 1;
    }
    emit(
      state.copyWith(
        status: leavingRegisteredVenue
            ? TableGroupCreateStatus.idle
            : state.status,
        error: leavingRegisteredVenue ? null : state.error,
        venueMode: TableGroupVenueMode.none,
        selectedVenue: null,
        venueOptions: const <TableGroupVenueOption>[],
        venueQuery: '',
        venueSearchLoading: false,
        venueSuggestionsVisible: false,
        venueSearchError: null,
        locationError: leavingRegisteredVenue ? null : state.locationError,
        cities: leavingRegisteredVenue ? const [] : state.cities,
        districts: leavingRegisteredVenue ? const [] : state.districts,
        neighborhoods: leavingRegisteredVenue ? const [] : state.neighborhoods,
      ),
    );
    if (leavingRegisteredVenue) unawaited(loadCities());
  }

  void venueTextChanged(String value) {
    if (!_venuePickerMutationAllowed) return;
    _switchToCustom(query: value.trim(), search: true);
  }

  void detachRegisteredVenue(String currentText) {
    if (!_venuePickerMutationAllowed) return;
    _switchToCustom(query: currentText.trim(), search: true);
  }

  void useCustomVenue(String currentText) {
    if (!_venuePickerMutationAllowed) return;
    _switchToCustom(query: currentText.trim(), search: false);
  }

  void selectRegisteredVenue(TableGroupVenueOption option) {
    if (!_venuePickerMutationAllowed) return;
    _venueSearchTimer?.cancel();
    _venueSearchGeneration += 1;
    _locationRequestGeneration += 1;
    _selectedCityId = option.cityId;
    _selectedDistrictId = option.districtId;
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.idle,
        error: null,
        venueMode: TableGroupVenueMode.registered,
        selectedVenue: option,
        venueOptions: const <TableGroupVenueOption>[],
        venueQuery: option.name,
        venueSearchLoading: false,
        venueSuggestionsVisible: false,
        venueSearchError: null,
        locationError: null,
        districts: const [],
        neighborhoods: const [],
      ),
    );
  }

  void _switchToCustom({required String query, required bool search}) {
    final leavingRegisteredVenue =
        state.venueMode == TableGroupVenueMode.registered;
    _venueSearchTimer?.cancel();
    final requestGeneration = ++_venueSearchGeneration;
    if (leavingRegisteredVenue) {
      _selectedCityId = null;
      _selectedDistrictId = null;
      _locationRequestGeneration += 1;
    }
    emit(
      state.copyWith(
        status: leavingRegisteredVenue
            ? TableGroupCreateStatus.idle
            : state.status,
        error: leavingRegisteredVenue ? null : state.error,
        venueMode: TableGroupVenueMode.custom,
        selectedVenue: null,
        venueOptions: const <TableGroupVenueOption>[],
        venueQuery: query,
        venueSearchLoading: false,
        venueSuggestionsVisible:
            search && query.length >= 2 && query.length <= 64,
        venueSearchError: null,
        locationError: leavingRegisteredVenue ? null : state.locationError,
        cities: leavingRegisteredVenue ? const [] : state.cities,
        districts: leavingRegisteredVenue ? const [] : state.districts,
        neighborhoods: leavingRegisteredVenue ? const [] : state.neighborhoods,
      ),
    );
    if (leavingRegisteredVenue) unawaited(loadCities());
    if (!search || query.length < 2 || query.length > 64) return;
    _venueSearchTimer = Timer(
      _venueSearchDebounce,
      () => unawaited(_searchVenueOptions(query, requestGeneration)),
    );
  }

  Future<void> _searchVenueOptions(String query, int requestGeneration) async {
    if (!_ownsVenueSearch(requestGeneration) || !_venuePickerMutationAllowed) {
      return;
    }
    emit(state.copyWith(venueSearchLoading: true, venueSearchError: null));
    final result = await _venueOptionRepository.search(query: query, limit: 8);
    if (!_ownsVenueSearch(requestGeneration) || !_venuePickerMutationAllowed) {
      return;
    }
    emit(
      state.copyWith(
        venueOptions: result.isSuccess
            ? result.data ?? const <TableGroupVenueOption>[]
            : const <TableGroupVenueOption>[],
        venueSearchLoading: false,
        venueSearchError: result.isSuccess ? null : result.error,
      ),
    );
  }

  Future<void> loadCities() async {
    if (isClosed || _activeCreateRequest != null) return;
    final requestGeneration = ++_locationRequestGeneration;
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.loadingLocations,
        locationError: null,
        error: null,
      ),
    );
    final result = await _locationRepository.getCities();
    if (!_ownsLocationRequest(requestGeneration)) return;
    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: TableGroupCreateStatus.idle,
          cities: result.data ?? const [],
          locationError: null,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.idle,
        locationError: result.error,
        error: null,
      ),
    );
  }

  Future<void> loadDistricts(String cityId) async {
    if (isClosed || _activeCreateRequest != null) return;
    _selectedCityId = cityId;
    _selectedDistrictId = null;
    final requestGeneration = ++_locationRequestGeneration;
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.loadingLocations,
        districts: const [],
        neighborhoods: const [],
        locationError: null,
        error: null,
      ),
    );
    final result = await _locationRepository.getDistricts(cityId);
    if (!_ownsLocationRequest(requestGeneration) || _selectedCityId != cityId) {
      return;
    }
    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: TableGroupCreateStatus.idle,
          districts: result.data ?? const [],
          neighborhoods: const [],
          locationError: null,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.idle,
        locationError: result.error,
        error: null,
      ),
    );
  }

  Future<void> loadNeighborhoods(String districtId) async {
    if (isClosed || _activeCreateRequest != null) return;
    _selectedDistrictId = districtId;
    final requestGeneration = ++_locationRequestGeneration;
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.loadingLocations,
        neighborhoods: const [],
        locationError: null,
        error: null,
      ),
    );
    final result = await _locationRepository.getNeighborhoods(districtId);
    if (!_ownsLocationRequest(requestGeneration) ||
        _selectedDistrictId != districtId) {
      return;
    }
    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: TableGroupCreateStatus.idle,
          neighborhoods: result.data ?? const [],
          locationError: null,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.idle,
        locationError: result.error,
        error: null,
      ),
    );
  }

  Future<void> selectCity(String? cityId) async {
    if (isClosed ||
        _activeCreateRequest != null ||
        state.venueMode == TableGroupVenueMode.registered) {
      return;
    }
    if (cityId == null || cityId.isEmpty) {
      _selectedCityId = null;
      _selectedDistrictId = null;
      _locationRequestGeneration += 1;
      emit(
        state.copyWith(
          status: TableGroupCreateStatus.idle,
          districts: const [],
          neighborhoods: const [],
          locationError: null,
          error: null,
        ),
      );
      return;
    }
    await loadDistricts(cityId);
  }

  Future<void> selectDistrict(String? districtId) async {
    if (isClosed ||
        _activeCreateRequest != null ||
        state.venueMode == TableGroupVenueMode.registered) {
      return;
    }
    if (districtId == null || districtId.isEmpty) {
      _selectedDistrictId = null;
      _locationRequestGeneration += 1;
      emit(
        state.copyWith(
          status: TableGroupCreateStatus.idle,
          neighborhoods: const [],
          locationError: null,
          error: null,
        ),
      );
      return;
    }
    await loadNeighborhoods(districtId);
  }

  Future<void> retryLocations() async {
    if (isClosed ||
        _activeCreateRequest != null ||
        state.venueMode == TableGroupVenueMode.registered) {
      return;
    }
    final districtId = _selectedDistrictId;
    if (districtId != null && districtId.isNotEmpty) {
      await loadNeighborhoods(districtId);
      return;
    }
    final cityId = _selectedCityId;
    if (cityId != null && cityId.isNotEmpty) {
      await loadDistricts(cityId);
      return;
    }
    await loadCities();
  }

  Future<bool> createTableGroup(TableGroupCreateRequest request) async {
    if (isClosed || _activeCreateRequest != null) return false;
    if (!_mutationAllowed()) {
      emit(
        state.copyWith(
          status: TableGroupCreateStatus.failure,
          error: _mutationForbiddenError,
        ),
      );
      return false;
    }
    if (!request.hasValidVenueIdentity ||
        !_venueSelectionMatchesState(request)) {
      emit(
        state.copyWith(
          status: TableGroupCreateStatus.failure,
          error: _venueIdentityInvalidError,
        ),
      );
      return false;
    }
    if (!request.hasValidDescription) {
      emit(
        state.copyWith(
          status: TableGroupCreateStatus.failure,
          error: _descriptionInvalidError,
        ),
      );
      return false;
    }
    final requestGeneration = ++_createRequestGeneration;
    _activeCreateRequest = request;
    _locationRequestGeneration += 1;
    _venueSearchTimer?.cancel();
    _venueSearchGeneration += 1;
    emit(
      state.copyWith(
        status: TableGroupCreateStatus.submitting,
        venueSearchLoading: false,
        error: null,
      ),
    );
    final result = await _tableGroupRepository.createTableGroup(request);
    if (isClosed ||
        requestGeneration != _createRequestGeneration ||
        !identical(_activeCreateRequest, request)) {
      return false;
    }
    _activeCreateRequest = null;
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

  bool _mutationAllowed() {
    try {
      return _canCreateOrJoin();
    } catch (_) {
      return false;
    }
  }

  bool _venueSelectionMatchesState(TableGroupCreateRequest request) {
    final venueId = request.venueId?.trim();
    final venueName = request.venueName?.trim();
    final hasVenueId = venueId?.isNotEmpty == true;
    final hasVenueName = venueName?.isNotEmpty == true;

    return switch (state.venueMode) {
      TableGroupVenueMode.none => !hasVenueId && !hasVenueName,
      TableGroupVenueMode.custom => !hasVenueId && hasVenueName,
      TableGroupVenueMode.registered =>
        hasVenueId &&
            !hasVenueName &&
            state.selectedVenue != null &&
            venueId == state.selectedVenue!.id.trim(),
    };
  }

  bool get _pickerMutationAllowed => !isClosed && _activeCreateRequest == null;

  bool get _venuePickerMutationAllowed =>
      _pickerMutationAllowed && state.hasSpecificVenue;

  bool _ownsVenueSearch(int requestGeneration) =>
      !isClosed && requestGeneration == _venueSearchGeneration;

  bool _ownsLocationRequest(int requestGeneration) {
    return !isClosed && requestGeneration == _locationRequestGeneration;
  }

  @override
  Future<void> close() {
    _locationRequestGeneration += 1;
    _createRequestGeneration += 1;
    _venueSearchGeneration += 1;
    _venueSearchTimer?.cancel();
    _activeCreateRequest = null;
    return super.close();
  }
}
