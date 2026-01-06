import '../../../../core/error/app_error.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/district.dart';
import '../../domain/entities/neighborhood.dart';

enum LocationStatus { idle, loading, success, failure }

class LocationState {
  final LocationStatus status;
  final List<City> cities;
  final List<District> districts;
  final List<Neighborhood> neighborhoods;
  final AppError? error;

  const LocationState({
    required this.status,
    required this.cities,
    required this.districts,
    required this.neighborhoods,
    this.error,
  });

  const LocationState.idle()
      : status = LocationStatus.idle,
        cities = const [],
        districts = const [],
        neighborhoods = const [],
        error = null;

  LocationState copyWith({
    LocationStatus? status,
    List<City>? cities,
    List<District>? districts,
    List<Neighborhood>? neighborhoods,
    AppError? error,
  }) {
    return LocationState(
      status: status ?? this.status,
      cities: cities ?? this.cities,
      districts: districts ?? this.districts,
      neighborhoods: neighborhoods ?? this.neighborhoods,
      error: error ?? this.error,
    );
  }
}
