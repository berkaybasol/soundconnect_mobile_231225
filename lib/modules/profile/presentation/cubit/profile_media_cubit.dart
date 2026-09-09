import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/profile_media.dart';
import '../../domain/profile_media_repository.dart';
import 'profile_media_state.dart';

class ProfileMediaCubit extends Cubit<ProfileMediaState> {
  final ProfileMediaRepository _repository;
  int _generation = 0;
  (String, String)? _target;

  ProfileMediaCubit(this._repository) : super(const ProfileMediaState.idle());

  Future<void> loadMedia({
    required String profileType,
    required String profileId,
  }) async {
    if (isClosed) return;
    final generation = ++_generation;
    final target = (profileType, profileId);
    final changed = _target != target;
    _target = target;
    emit(
      state.copyWith(
        status: ProfileMediaStatus.loading,
        media: changed ? null : state.media,
        error: null,
      ),
    );
    Result<ProfileMedia> result;
    try {
      result = await _repository.getProfileMedia(
        profileType: profileType,
        profileId: profileId,
      );
    } catch (_) {
      result = const Result.failure(
        AppError(
          code: 'profile_media_unexpected',
          message: 'Profil medyası yüklenemedi.',
        ),
      );
    }
    if (isClosed || generation != _generation) return;
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: ProfileMediaStatus.success,
          media: result.data,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: ProfileMediaStatus.failure,
        media: null,
        error: result.error,
      ),
    );
  }
}
