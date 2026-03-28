import '../../../../core/error/app_error.dart';
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
    VenueOwnerProfile? ownerProfile,
    VenuePublicProfile? publicProfile,
    AppError? error,
  }) {
    return VenueProfileState(
      status: status ?? this.status,
      view: view ?? this.view,
      ownerProfile: ownerProfile ?? this.ownerProfile,
      publicProfile: publicProfile ?? this.publicProfile,
      error: error ?? this.error,
    );
  }
}
