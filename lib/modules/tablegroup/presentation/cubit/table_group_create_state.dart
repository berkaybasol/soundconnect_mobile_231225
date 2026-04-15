import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../../location/domain/entities/city.dart';
import '../../../location/domain/entities/district.dart';
import '../../../location/domain/entities/neighborhood.dart';

enum TableGroupCreateStatus {
  idle,
  loadingLocations,
  submitting,
  success,
  failure,
}

class TableGroupCreateState {
  final TableGroupCreateStatus status;
  final List<City> cities;
  final List<District> districts;
  final List<Neighborhood> neighborhoods;
  final AppError? error;

  const TableGroupCreateState({
    required this.status,
    required this.cities,
    required this.districts,
    required this.neighborhoods,
    this.error,
  });

  const TableGroupCreateState.idle()
    : status = TableGroupCreateStatus.idle,
      cities = const [],
      districts = const [],
      neighborhoods = const [],
      error = null;

  TableGroupCreateState copyWith({
    TableGroupCreateStatus? status,
    List<City>? cities,
    List<District>? districts,
    List<Neighborhood>? neighborhoods,
    Object? error = copyWithUnset,
  }) {
    return TableGroupCreateState(
      status: status ?? this.status,
      cities: cities ?? this.cities,
      districts: districts ?? this.districts,
      neighborhoods: neighborhoods ?? this.neighborhoods,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
