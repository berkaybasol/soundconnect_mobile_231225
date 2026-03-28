import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/artist_venue_connection_repository.dart';
import 'artist_venue_connections_state.dart';

class ArtistVenueConnectionsCubit extends Cubit<ArtistVenueConnectionsState> {
  final ArtistVenueConnectionRepository _repository;

  ArtistVenueConnectionsCubit(this._repository)
    : super(const ArtistVenueConnectionsState.idle());

  Future<void> loadAcceptedVenues(String musicianProfileId) async {
    emit(
      state.copyWith(status: ArtistVenueConnectionsStatus.loading, error: null),
    );
    final result = await _repository.getAcceptedVenues(musicianProfileId);
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: ArtistVenueConnectionsStatus.success,
          venues: result.data!,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: ArtistVenueConnectionsStatus.failure,
        error: result.error,
      ),
    );
  }
}
