import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/location_repository.dart';
import 'location_state.dart';

class LocationCubit extends Cubit<LocationState> {
  final LocationRepository _repository;
  int _districtRequest = 0;
  int _neighborhoodRequest = 0;

  LocationCubit(this._repository) : super(const LocationState.idle());

  Future<void> loadCities() async {
    emit(state.copyWith(status: LocationStatus.loading, error: null));
    final result = await _repository.getCities();
    if (isClosed) return;
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: LocationStatus.success,
          cities: result.data!,
          error: null,
        ),
      );
      return;
    }
    emit(state.copyWith(status: LocationStatus.failure, error: result.error));
  }

  Future<void> loadDistricts(String cityId) async {
    final request = ++_districtRequest;
    _neighborhoodRequest++;
    emit(
      state.copyWith(
        status: LocationStatus.loading,
        districts: const [],
        neighborhoods: const [],
        error: null,
      ),
    );
    final result = await _repository.getDistricts(cityId);
    if (isClosed || request != _districtRequest) return;
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: LocationStatus.success,
          districts: result.data!,
          error: null,
        ),
      );
      return;
    }
    emit(state.copyWith(status: LocationStatus.failure, error: result.error));
  }

  Future<void> loadNeighborhoods(String districtId) async {
    final request = ++_neighborhoodRequest;
    emit(
      state.copyWith(
        status: LocationStatus.loading,
        neighborhoods: const [],
        error: null,
      ),
    );
    final result = await _repository.getNeighborhoods(districtId);
    if (isClosed || request != _neighborhoodRequest) return;
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: LocationStatus.success,
          neighborhoods: result.data!,
          error: null,
        ),
      );
      return;
    }
    emit(state.copyWith(status: LocationStatus.failure, error: result.error));
  }

  void resetDistricts() {
    _districtRequest++;
    _neighborhoodRequest++;
    emit(
      state.copyWith(districts: const [], neighborhoods: const [], error: null),
    );
  }
}
