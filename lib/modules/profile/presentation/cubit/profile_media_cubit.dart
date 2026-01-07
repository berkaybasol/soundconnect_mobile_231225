import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/profile_media_repository.dart';
import 'profile_media_state.dart';

class ProfileMediaCubit extends Cubit<ProfileMediaState> {
  final ProfileMediaRepository _repository;

  ProfileMediaCubit(this._repository) : super(const ProfileMediaState.idle());

  Future<void> loadMedia({
    required String profileType,
    required String profileId,
  }) async {
    emit(state.copyWith(status: ProfileMediaStatus.loading));
    final result = await _repository.getProfileMedia(
      profileType: profileType,
      profileId: profileId,
    );
    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(
        status: ProfileMediaStatus.success,
        media: result.data,
      ));
      return;
    }
    emit(state.copyWith(
      status: ProfileMediaStatus.failure,
      error: result.error,
    ));
  }
}
