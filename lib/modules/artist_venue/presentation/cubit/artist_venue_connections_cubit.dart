import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/artist_venue_connection_repository.dart';
import 'artist_venue_connections_state.dart';

class ArtistVenueConnectionsCubit extends Cubit<ArtistVenueConnectionsState> {
  final ArtistVenueConnectionRepository _repository;
  int _loadGeneration = 0;
  String? _profileId;

  ArtistVenueConnectionsCubit(this._repository)
    : super(const ArtistVenueConnectionsState.idle());

  Future<void> loadAcceptedVenues(String musicianProfileId) async {
    if (isClosed) return;
    final generation = ++_loadGeneration;
    final changedProfile = _profileId != musicianProfileId;
    _profileId = musicianProfileId;
    emit(
      state.copyWith(
        status: ArtistVenueConnectionsStatus.loading,
        venues: changedProfile ? const [] : state.venues,
        error: null,
      ),
    );
    final result = await _repository.getVenueConnectionsByStatus(
      musicianProfileId,
      status: 'ACCEPTED',
    );
    if (isClosed || generation != _loadGeneration) return;
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
