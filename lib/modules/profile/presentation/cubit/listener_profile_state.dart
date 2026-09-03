import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/listener_profile.dart';
import '../../domain/entities/listener_public_profile.dart';

enum ListenerProfileStatus { idle, loading, saving, success, failure }

enum ListenerProfileView { owner, public }

enum ListenerProfileAction { load, updateVisibility, updateAvatar }

class ListenerProfileState {
  final ListenerProfileStatus status;
  final ListenerProfile? profile;
  final ListenerPublicProfile? publicProfile;
  final ListenerProfileView view;
  final ListenerProfileAction action;
  final AppError? error;

  const ListenerProfileState({
    required this.status,
    this.profile,
    this.publicProfile,
    this.view = ListenerProfileView.owner,
    this.action = ListenerProfileAction.load,
    this.error,
  });

  const ListenerProfileState.idle()
    : status = ListenerProfileStatus.idle,
      profile = null,
      publicProfile = null,
      view = ListenerProfileView.owner,
      action = ListenerProfileAction.load,
      error = null;

  ListenerProfileState copyWith({
    ListenerProfileStatus? status,
    Object? profile = copyWithUnset,
    Object? publicProfile = copyWithUnset,
    ListenerProfileView? view,
    ListenerProfileAction? action,
    Object? error = copyWithUnset,
  }) {
    return ListenerProfileState(
      status: status ?? this.status,
      profile: identical(profile, copyWithUnset)
          ? this.profile
          : profile as ListenerProfile?,
      publicProfile: identical(publicProfile, copyWithUnset)
          ? this.publicProfile
          : publicProfile as ListenerPublicProfile?,
      view: view ?? this.view,
      action: action ?? this.action,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
