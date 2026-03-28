import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';

enum ArtistVenueConnectionsStatus { idle, loading, success, failure }

class ArtistVenueConnectionsState {
  final ArtistVenueConnectionsStatus status;
  final List<String> venues;
  final AppError? error;

  const ArtistVenueConnectionsState({
    required this.status,
    required this.venues,
    this.error,
  });

  const ArtistVenueConnectionsState.idle()
    : status = ArtistVenueConnectionsStatus.idle,
      venues = const [],
      error = null;

  ArtistVenueConnectionsState copyWith({
    ArtistVenueConnectionsStatus? status,
    List<String>? venues,
    Object? error = copyWithUnset,
  }) {
    return ArtistVenueConnectionsState(
      status: status ?? this.status,
      venues: venues ?? this.venues,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
