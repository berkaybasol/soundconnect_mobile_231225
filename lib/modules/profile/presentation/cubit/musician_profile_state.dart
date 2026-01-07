import '../../../../core/error/app_error.dart';
import '../../domain/entities/musician_profile.dart';

enum MusicianProfileStatus { idle, loading, success, failure }

enum MusicianProfileAction { none, load, update }

class MusicianProfileState {
  final MusicianProfileStatus status;
  final MusicianProfileAction action;
  final MusicianProfile? profile;
  final AppError? error;

  const MusicianProfileState({
    required this.status,
    required this.action,
    this.profile,
    this.error,
  });

  const MusicianProfileState.idle()
      : status = MusicianProfileStatus.idle,
        action = MusicianProfileAction.none,
        profile = null,
        error = null;

  MusicianProfileState copyWith({
    MusicianProfileStatus? status,
    MusicianProfileAction? action,
    MusicianProfile? profile,
    AppError? error,
  }) {
    return MusicianProfileState(
      status: status ?? this.status,
      action: action ?? this.action,
      profile: profile ?? this.profile,
      error: error ?? this.error,
    );
  }
}
