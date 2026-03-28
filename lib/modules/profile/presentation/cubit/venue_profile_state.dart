import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/venue_owner_profile.dart';
import '../../domain/entities/venue_public_profile.dart';

enum VenueProfileStatus { idle, loading, success, failure }

enum VenueProfileView { none, owner, public }

class VenueProfileState {
  final VenueProfileStatus status;
  final VenueProfileView view;
  final VenueOwnerProfile? ownerProfile;
  final VenuePublicProfile? publicProfile;
  final AppError? error;

  const VenueProfileState({
    required this.status,
    required this.view,
    this.ownerProfile,
    this.publicProfile,
    this.error,
  });

  const VenueProfileState.idle()
    : status = VenueProfileStatus.idle,
      view = VenueProfileView.none,
      ownerProfile = null,
      publicProfile = null,
      error = null;

  VenueProfileState copyWith({
    VenueProfileStatus? status,
    VenueProfileView? view,
    Object? ownerProfile = copyWithUnset,
    Object? publicProfile = copyWithUnset,
    Object? error = copyWithUnset,
  }) {
    return VenueProfileState(
      status: status ?? this.status,
      view: view ?? this.view,
      ownerProfile: identical(ownerProfile, copyWithUnset)
          ? this.ownerProfile
          : ownerProfile as VenueOwnerProfile?,
      publicProfile: identical(publicProfile, copyWithUnset)
          ? this.publicProfile
          : publicProfile as VenuePublicProfile?,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
