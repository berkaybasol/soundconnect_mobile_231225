import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/venue_profile_save_request.dart';
import '../../domain/venue_profile_repository.dart';
import 'venue_profile_state.dart';

class VenueProfileCubit extends Cubit<VenueProfileState> {
  final VenueProfileRepository _repository;

  VenueProfileCubit(this._repository) : super(const VenueProfileState.idle());

  Future<void> loadOwner({String? venueId}) async {
    emit(
      state.copyWith(
        status: VenueProfileStatus.loading,
        view: VenueProfileView.owner,
        error: null,
      ),
    );
    final result = await _repository.getMyVenueProfileDetail(venueId: venueId);
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: VenueProfileStatus.success,
          view: VenueProfileView.owner,
          ownerProfile: result.data,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: VenueProfileStatus.failure,
        view: VenueProfileView.owner,
        error: result.error,
      ),
    );
  }

  Future<void> loadPublic({String? venueId}) async {
    emit(
      state.copyWith(
        status: VenueProfileStatus.loading,
        view: VenueProfileView.public,
        error: null,
      ),
    );
    final result = await _repository.getPublicVenueProfile(venueId: venueId);
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: VenueProfileStatus.success,
          view: VenueProfileView.public,
          publicProfile: result.data,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: VenueProfileStatus.failure,
        view: VenueProfileView.public,
        error: result.error,
      ),
    );
  }

  Future<void> updateOwnerProfile(
    VenueProfileSaveRequest request, {
    String? venueId,
  }) async {
    emit(
      state.copyWith(
        status: VenueProfileStatus.loading,
        view: VenueProfileView.owner,
        error: null,
      ),
    );
    final result = await _repository.updateMyVenueProfileDetail(
      request,
      venueId: venueId,
    );
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: VenueProfileStatus.success,
          view: VenueProfileView.owner,
          ownerProfile: result.data,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: VenueProfileStatus.failure,
        view: VenueProfileView.owner,
        error: result.error,
      ),
    );
  }
}
