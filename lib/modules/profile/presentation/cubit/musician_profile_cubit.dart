import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/musician_profile_save_request.dart';
import '../../domain/musician_profile_repository.dart';
import 'musician_profile_state.dart';

class MusicianProfileCubit extends Cubit<MusicianProfileState> {
  final MusicianProfileRepository _repository;

  MusicianProfileCubit(this._repository)
      : super(const MusicianProfileState.idle());

  Future<void> loadMyProfile() async {
    emit(state.copyWith(
      status: MusicianProfileStatus.loading,
      action: MusicianProfileAction.load,
    ));
    final result = await _repository.getMyProfile();
    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(
        status: MusicianProfileStatus.success,
        action: MusicianProfileAction.load,
        profile: result.data,
      ));
      return;
    }
    emit(state.copyWith(
      status: MusicianProfileStatus.failure,
      action: MusicianProfileAction.load,
      error: result.error,
    ));
  }

  Future<void> updateProfile(MusicianProfileSaveRequest request) async {
    emit(state.copyWith(
      status: MusicianProfileStatus.loading,
      action: MusicianProfileAction.update,
    ));
    final result = await _repository.updateMyProfile(request);
    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(
        status: MusicianProfileStatus.success,
        action: MusicianProfileAction.update,
        profile: result.data,
      ));
      return;
    }
    emit(state.copyWith(
      status: MusicianProfileStatus.failure,
      action: MusicianProfileAction.update,
      error: result.error,
    ));
  }
}
