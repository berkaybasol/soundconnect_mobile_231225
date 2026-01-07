import '../../../../core/error/app_error.dart';
import '../../domain/entities/profile_media.dart';

enum ProfileMediaStatus { idle, loading, success, failure }

class ProfileMediaState {
  final ProfileMediaStatus status;
  final ProfileMedia? media;
  final AppError? error;

  const ProfileMediaState({
    required this.status,
    this.media,
    this.error,
  });

  const ProfileMediaState.idle()
      : status = ProfileMediaStatus.idle,
        media = null,
        error = null;

  ProfileMediaState copyWith({
    ProfileMediaStatus? status,
    ProfileMedia? media,
    AppError? error,
  }) {
    return ProfileMediaState(
      status: status ?? this.status,
      media: media ?? this.media,
      error: error ?? this.error,
    );
  }
}
