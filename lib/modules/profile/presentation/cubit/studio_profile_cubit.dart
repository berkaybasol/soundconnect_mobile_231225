import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/studio_profile_repository.dart';
import 'studio_profile_state.dart';

class StudioProfileCubit extends Cubit<StudioProfileState> {
  final StudioProfileRepository _repository;

  StudioProfileCubit(this._repository) : super(const StudioProfileState.idle());

  Future<void> loadMyProfile() async {
    emit(state.copyWith(status: StudioProfileStatus.loading, error: null));
    final result = await _repository.getMyProfile();
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: StudioProfileStatus.success,
          profile: result.data,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(status: StudioProfileStatus.failure, error: result.error),
    );
  }

  Future<void> loadPublicProfile(String profileId) async {
    emit(state.copyWith(status: StudioProfileStatus.loading, error: null));
    final result = await _repository.getPublicProfile(profileId);
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: StudioProfileStatus.success,
          profile: result.data,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(status: StudioProfileStatus.failure, error: result.error),
    );
  }

  Future<void> updateMyProfile(StudioProfileSaveRequest request) async {
    emit(state.copyWith(status: StudioProfileStatus.saving, error: null));
    final result = await _repository.updateMyProfile(request);
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: StudioProfileStatus.success,
          profile: result.data,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(status: StudioProfileStatus.failure, error: result.error),
    );
  }
}
