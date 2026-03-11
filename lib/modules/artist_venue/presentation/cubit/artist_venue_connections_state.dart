import '../../../../core/error/app_error.dart';

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
    AppError? error,
  }) {
    return ArtistVenueConnectionsState(
      status: status ?? this.status,
      venues: venues ?? this.venues,
      error: error ?? this.error,
    );
  }
}
