import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/studio_profile.dart';

enum StudioProfileStatus { idle, loading, saving, success, failure }

class StudioProfileState {
  final StudioProfileStatus status;
  final StudioProfile? profile;
  final AppError? error;

  const StudioProfileState({
    required this.status,
    this.profile,
    this.error,
  });

  const StudioProfileState.idle()
    : status = StudioProfileStatus.idle,
      profile = null,
      error = null;

  StudioProfileState copyWith({
    StudioProfileStatus? status,
    Object? profile = copyWithUnset,
    Object? error = copyWithUnset,
  }) {
    return StudioProfileState(
      status: status ?? this.status,
      profile: identical(profile, copyWithUnset)
          ? this.profile
          : profile as StudioProfile?,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
