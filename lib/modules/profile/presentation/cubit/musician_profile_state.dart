import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
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
    Object? profile = copyWithUnset,
    Object? error = copyWithUnset,
  }) {
    return MusicianProfileState(
      status: status ?? this.status,
      action: action ?? this.action,
      profile: identical(profile, copyWithUnset)
          ? this.profile
          : profile as MusicianProfile?,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
