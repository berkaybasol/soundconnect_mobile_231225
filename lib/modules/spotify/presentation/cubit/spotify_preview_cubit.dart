import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/spotify_repository.dart';
import 'spotify_preview_state.dart';

class SpotifyPreviewCubit extends Cubit<SpotifyPreviewState> {
  final SpotifyRepository _repository;

  SpotifyPreviewCubit(this._repository)
      : super(const SpotifyPreviewState.idle());

  Future<void> loadByIds(List<String> ids) async {
    emit(state.copyWith(status: SpotifyPreviewStatus.loading));
    final result = await _repository.getTracksByIds(ids);
    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(
        status: SpotifyPreviewStatus.success,
        tracks: result.data!,
      ));
      return;
    }
    emit(state.copyWith(
      status: SpotifyPreviewStatus.failure,
      error: result.error,
    ));
  }

  Future<void> search(String query, {int limit = 5}) async {
    emit(state.copyWith(status: SpotifyPreviewStatus.loading));
    final result = await _repository.searchTracks(query, limit: limit);
    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(
        status: SpotifyPreviewStatus.success,
        tracks: result.data!,
      ));
      return;
    }
    emit(state.copyWith(
      status: SpotifyPreviewStatus.failure,
      error: result.error,
    ));
  }
}
