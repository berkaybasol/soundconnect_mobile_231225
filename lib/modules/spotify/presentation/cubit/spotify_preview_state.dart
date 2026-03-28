import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/spotify_track_preview.dart';

enum SpotifyPreviewStatus { idle, loading, success, failure }

class SpotifyPreviewState {
  final SpotifyPreviewStatus status;
  final List<SpotifyTrackPreview> tracks;
  final AppError? error;

  const SpotifyPreviewState({
    required this.status,
    required this.tracks,
    this.error,
  });

  const SpotifyPreviewState.idle()
    : status = SpotifyPreviewStatus.idle,
      tracks = const [],
      error = null;

  SpotifyPreviewState copyWith({
    SpotifyPreviewStatus? status,
    List<SpotifyTrackPreview>? tracks,
    Object? error = copyWithUnset,
  }) {
    return SpotifyPreviewState(
      status: status ?? this.status,
      tracks: tracks ?? this.tracks,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
