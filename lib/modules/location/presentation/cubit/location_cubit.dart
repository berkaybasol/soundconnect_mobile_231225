import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/location_repository.dart';
import 'location_state.dart';

class LocationCubit extends Cubit<LocationState> {
  final LocationRepository _repository;

  LocationCubit(this._repository) : super(const LocationState.idle());

  Future<void> loadCities() async {
    emit(state.copyWith(status: LocationStatus.loading));
    final result = await _repository.getCities();
    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(
        status: LocationStatus.success,
        cities: result.data!,
      ));
      return;
    }
    emit(state.copyWith(status: LocationStatus.failure, error: result.error));
  }

  Future<void> loadDistricts(String cityId) async {
    emit(state.copyWith(status: LocationStatus.loading, districts: const []));
    final result = await _repository.getDistricts(cityId);
    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(
        status: LocationStatus.success,
        districts: result.data!,
      ));
      return;
    }
    emit(state.copyWith(status: LocationStatus.failure, error: result.error));
  }

  Future<void> loadNeighborhoods(String districtId) async {
    emit(
      state.copyWith(status: LocationStatus.loading, neighborhoods: const []),
    );
    final result = await _repository.getNeighborhoods(districtId);
    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(
        status: LocationStatus.success,
        neighborhoods: result.data!,
      ));
      return;
    }
    emit(state.copyWith(status: LocationStatus.failure, error: result.error));
  }

  void resetDistricts() {
    emit(state.copyWith(districts: const [], neighborhoods: const []));
  }
}
