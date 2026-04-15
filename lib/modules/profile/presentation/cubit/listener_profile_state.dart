import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/listener_profile.dart';

enum ListenerProfileStatus { idle, loading, success, failure }

class ListenerProfileState {
  final ListenerProfileStatus status;
  final ListenerProfile? profile;
  final AppError? error;

  const ListenerProfileState({required this.status, this.profile, this.error});

  const ListenerProfileState.idle()
    : status = ListenerProfileStatus.idle,
      profile = null,
      error = null;

  ListenerProfileState copyWith({
    ListenerProfileStatus? status,
    Object? profile = copyWithUnset,
    Object? error = copyWithUnset,
  }) {
    return ListenerProfileState(
      status: status ?? this.status,
      profile: identical(profile, copyWithUnset)
          ? this.profile
          : profile as ListenerProfile?,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
