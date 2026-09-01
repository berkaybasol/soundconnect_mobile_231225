import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../../location/domain/entities/city.dart';
import '../../../location/domain/entities/district.dart';
import '../../../location/domain/entities/neighborhood.dart';
import '../../domain/entities/table_group_venue_option.dart';

enum TableGroupVenueMode { none, custom, registered }

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
  final TableGroupVenueMode venueMode;
  final TableGroupVenueOption? selectedVenue;
  final List<TableGroupVenueOption> venueOptions;
  final String venueQuery;
  final bool venueSearchLoading;
  final bool venueSuggestionsVisible;
  final AppError? venueSearchError;
  final AppError? locationError;
  final AppError? error;

  const TableGroupCreateState({
    required this.status,
    required this.cities,
    required this.districts,
    required this.neighborhoods,
    required this.venueMode,
    required this.selectedVenue,
    required this.venueOptions,
    required this.venueQuery,
    required this.venueSearchLoading,
    required this.venueSuggestionsVisible,
    required this.venueSearchError,
    required this.locationError,
    this.error,
  });

  const TableGroupCreateState.idle()
    : status = TableGroupCreateStatus.idle,
      cities = const [],
      districts = const [],
      neighborhoods = const [],
      venueMode = TableGroupVenueMode.none,
      selectedVenue = null,
      venueOptions = const [],
      venueQuery = '',
      venueSearchLoading = false,
      venueSuggestionsVisible = false,
      venueSearchError = null,
      locationError = null,
      error = null;

  bool get hasSpecificVenue => venueMode != TableGroupVenueMode.none;

  TableGroupCreateState copyWith({
    TableGroupCreateStatus? status,
    List<City>? cities,
    List<District>? districts,
    List<Neighborhood>? neighborhoods,
    TableGroupVenueMode? venueMode,
    Object? selectedVenue = copyWithUnset,
    List<TableGroupVenueOption>? venueOptions,
    String? venueQuery,
    bool? venueSearchLoading,
    bool? venueSuggestionsVisible,
    Object? venueSearchError = copyWithUnset,
    Object? locationError = copyWithUnset,
    Object? error = copyWithUnset,
  }) {
    return TableGroupCreateState(
      status: status ?? this.status,
      cities: cities ?? this.cities,
      districts: districts ?? this.districts,
      neighborhoods: neighborhoods ?? this.neighborhoods,
      venueMode: venueMode ?? this.venueMode,
      selectedVenue: identical(selectedVenue, copyWithUnset)
          ? this.selectedVenue
          : selectedVenue as TableGroupVenueOption?,
      venueOptions: venueOptions ?? this.venueOptions,
      venueQuery: venueQuery ?? this.venueQuery,
      venueSearchLoading: venueSearchLoading ?? this.venueSearchLoading,
      venueSuggestionsVisible:
          venueSuggestionsVisible ?? this.venueSuggestionsVisible,
      venueSearchError: identical(venueSearchError, copyWithUnset)
          ? this.venueSearchError
          : venueSearchError as AppError?,
      locationError: identical(locationError, copyWithUnset)
          ? this.locationError
          : locationError as AppError?,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
