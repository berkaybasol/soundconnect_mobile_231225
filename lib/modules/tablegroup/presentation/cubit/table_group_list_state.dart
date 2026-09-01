import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../../location/domain/entities/city.dart';
import '../../../location/domain/entities/district.dart';
import '../../../location/domain/entities/neighborhood.dart';
import '../../domain/entities/table_group.dart';

enum TableGroupListStatus { idle, loading, loadingMore, failure }

class TableGroupListState {
  final TableGroupListStatus status;
  final List<City> cities;
  final List<District> districts;
  final List<Neighborhood> neighborhoods;
  final String? selectedCityId;
  final String? selectedDistrictId;
  final String? selectedNeighborhoodId;
  final List<TableGroup> items;
  final int? totalElements;
  final bool hasNext;
  final int page;
  final Set<String> joiningIds;
  final AppError? error;

  const TableGroupListState({
    required this.status,
    required this.cities,
    required this.districts,
    required this.neighborhoods,
    required this.selectedCityId,
    required this.selectedDistrictId,
    required this.selectedNeighborhoodId,
    required this.items,
    required this.totalElements,
    required this.hasNext,
    required this.page,
    required this.joiningIds,
    this.error,
  });

  const TableGroupListState.idle()
    : status = TableGroupListStatus.idle,
      cities = const [],
      districts = const [],
      neighborhoods = const [],
      selectedCityId = null,
      selectedDistrictId = null,
      selectedNeighborhoodId = null,
      items = const [],
      totalElements = null,
      hasNext = false,
      page = 0,
      joiningIds = const <String>{},
      error = null;

  TableGroupListState copyWith({
    TableGroupListStatus? status,
    List<City>? cities,
    List<District>? districts,
    List<Neighborhood>? neighborhoods,
    Object? selectedCityId = copyWithUnset,
    Object? selectedDistrictId = copyWithUnset,
    Object? selectedNeighborhoodId = copyWithUnset,
    List<TableGroup>? items,
    Object? totalElements = copyWithUnset,
    bool? hasNext,
    int? page,
    Set<String>? joiningIds,
    Object? error = copyWithUnset,
  }) {
    return TableGroupListState(
      status: status ?? this.status,
      cities: cities ?? this.cities,
      districts: districts ?? this.districts,
      neighborhoods: neighborhoods ?? this.neighborhoods,
      selectedCityId: identical(selectedCityId, copyWithUnset)
          ? this.selectedCityId
          : selectedCityId as String?,
      selectedDistrictId: identical(selectedDistrictId, copyWithUnset)
          ? this.selectedDistrictId
          : selectedDistrictId as String?,
      selectedNeighborhoodId: identical(selectedNeighborhoodId, copyWithUnset)
          ? this.selectedNeighborhoodId
          : selectedNeighborhoodId as String?,
      items: items ?? this.items,
      totalElements: identical(totalElements, copyWithUnset)
          ? this.totalElements
          : totalElements as int?,
      hasNext: hasNext ?? this.hasNext,
      page: page ?? this.page,
      joiningIds: joiningIds ?? this.joiningIds,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
