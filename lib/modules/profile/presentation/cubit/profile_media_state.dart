import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/profile_media.dart';

enum ProfileMediaStatus { idle, loading, success, failure }

class ProfileMediaState {
  final ProfileMediaStatus status;
  final ProfileMedia? media;
  final AppError? error;

  const ProfileMediaState({required this.status, this.media, this.error});

  const ProfileMediaState.idle()
    : status = ProfileMediaStatus.idle,
      media = null,
      error = null;

  ProfileMediaState copyWith({
    ProfileMediaStatus? status,
    Object? media = copyWithUnset,
    Object? error = copyWithUnset,
  }) {
    return ProfileMediaState(
      status: status ?? this.status,
      media: identical(media, copyWithUnset)
          ? this.media
          : media as ProfileMedia?,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
