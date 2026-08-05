import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_error.dart';
import '../../domain/studio_profile_repository.dart';
import 'studio_profile_state.dart';

class StudioProfileCubit extends Cubit<StudioProfileState> {
  final StudioProfileRepository _repository;
  int _loadGeneration = 0;
  Future<void>? _updateQueueTail;

  StudioProfileCubit(this._repository) : super(const StudioProfileState.idle());

  Future<void> loadMyProfile() async {
    final activeUpdate = _updateQueueTail;
    if (activeUpdate != null) await activeUpdate;
    if (isClosed) return;
    final generation = ++_loadGeneration;
    emit(state.copyWith(status: StudioProfileStatus.loading, error: null));
    final result = await _repository.getMyProfile();
    if (isClosed || generation != _loadGeneration) return;
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
    final generation = ++_loadGeneration;
    if (isClosed) return;
    emit(state.copyWith(status: StudioProfileStatus.loading, error: null));
    final result = await _repository.getPublicProfile(profileId);
    if (isClosed || generation != _loadGeneration) return;
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

  Future<void> updateMyProfile(StudioProfileSaveRequest request) {
    final previous = _updateQueueTail;
    final mustRebaseVersion = previous != null;
    final update = (previous ?? Future<void>.value()).then(
      (_) => _performUpdate(request, rebaseVersion: mustRebaseVersion),
    );

    // Keep the serialization chain alive even if an unexpected repository
    // exception reaches one caller. The original [update] future still exposes
    // that exception to the caller that owns the failed request.
    final safeTail = update.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _updateQueueTail = safeTail;
    safeTail.whenComplete(() {
      if (identical(_updateQueueTail, safeTail)) _updateQueueTail = null;
    });
    return update;
  }

  Future<void> _performUpdate(
    StudioProfileSaveRequest request, {
    required bool rebaseVersion,
  }) async {
    if (isClosed) return;
    ++_loadGeneration;
    emit(state.copyWith(status: StudioProfileStatus.saving, error: null));
    final versionedRequest = rebaseVersion || request.version == null
        ? request.copyWithVersion(state.profile?.version)
        : request;
    final result = await _repository.updateMyProfile(versionedRequest);
    if (isClosed) return;
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
    if (_isStaleProfileError(result.error)) {
      final refreshed = await _repository.getMyProfile();
      if (isClosed) return;
      if (refreshed.isSuccess && refreshed.data != null) {
        emit(
          state.copyWith(
            status: StudioProfileStatus.failure,
            profile: refreshed.data,
            error: AppError(
              code: result.error!.code,
              message:
                  'Profil başka bir oturumda değişti. Güncel verileri aldık; değişikliğini kontrol edip tekrar dene.',
              details: result.error!.details,
            ),
          ),
        );
        return;
      }
    }
    emit(
      state.copyWith(status: StudioProfileStatus.failure, error: result.error),
    );
  }

  static bool _isStaleProfileError(AppError? error) {
    final code = error?.code.trim().toUpperCase();
    return code == '9804' || code == 'STUDIO_STALE_UPDATE';
  }
}
