import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../data/models/musician_profile_save_request.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/musician_profile_repository.dart';
import 'musician_profile_state.dart';

class MusicianProfileCubit extends Cubit<MusicianProfileState> {
  final MusicianProfileRepository _repository;
  int _generation = 0;
  Future<Result<MusicianProfile>>? _update;
  final AuthSessionManager? _sessions;

  MusicianProfileCubit(this._repository, {AuthSessionManager? sessions})
    : _sessions =
          sessions ??
          (serviceLocator.isRegistered<AuthSessionManager>()
              ? serviceLocator<AuthSessionManager>()
              : null),
      super(const MusicianProfileState.idle()) {
    _sessions?.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (isClosed) return;
    ++_generation;
    emit(const MusicianProfileState.idle());
  }

  @override
  Future<void> close() {
    _sessions?.removeListener(_sessionChanged);
    return super.close();
  }

  Future<void> loadMyProfile() async {
    if (isClosed) return;
    // Reserve presentation before waiting: a later navigation must not be
    // replaced when this owner refresh resumes after the write commits.
    final generation = ++_generation;
    final session = _sessions?.session;
    final update = _update;
    if (update != null) await update;
    if (isClosed ||
        generation != _generation ||
        !identical(_sessions?.session, session)) {
      return;
    }
    await _run(
      _repository.getMyProfile,
      ownerRead: true,
      reservedGeneration: generation,
    );
  }

  Future<void> loadPublicProfile(String profileId) async {
    await _run(
      () => _repository.getPublicProfileByProfileId(profileId),
      targetProfileId: profileId,
    );
  }

  Future<Result<MusicianProfile>> updateProfile(
    MusicianProfileSaveRequest request, {
    String? expectedSessionKey,
  }) async {
    if (_update != null) {
      return const Result.failure(
        AppError(
          code: 'musician_profile_busy',
          message: 'Devam eden profil işlemini bekle.',
        ),
      );
    }
    final expectedAccount = expectedSessionKey ?? _sessions?.session.userId;
    final operation = _run(
      () => _repository.updateMyProfile(
        request,
        expectedSessionKey: expectedAccount,
      ),
      action: MusicianProfileAction.update,
      expectedSessionKey: expectedAccount,
      targetProfileId: state.profile?.id,
    );
    _update = operation;
    try {
      return await operation;
    } finally {
      _update = null;
    }
  }

  Future<Result<MusicianProfile>> _run(
    Future<Result<MusicianProfile>> Function() operation, {
    MusicianProfileAction action = MusicianProfileAction.load,
    bool ownerRead = false,
    String? expectedSessionKey,
    String? targetProfileId,
    int? reservedGeneration,
  }) async {
    const stale = Result<MusicianProfile>.failure(
      AppError(
        code: 'musician_profile_stale',
        message: 'Profil değişti. Sayfayı yeniden aç.',
      ),
    );
    if (isClosed) return stale;
    final manager = _sessions;
    final session = manager?.session;
    if (action == MusicianProfileAction.update &&
        manager != null &&
        (session?.isAuthenticated != true ||
            session?.isActive != true ||
            !session!.hasAnyRole(const ['MUSICIAN', 'ROLE_MUSICIAN']) ||
            (expectedSessionKey != null &&
                session.userId != expectedSessionKey) ||
            (state.profile != null &&
                state.profile!.userId != session.userId))) {
      return stale;
    }
    final generation = reservedGeneration ?? ++_generation;
    emit(
      state.copyWith(
        status: MusicianProfileStatus.loading,
        action: action,
        profile: targetProfileId != null && state.profile?.id != targetProfileId
            ? null
            : state.profile,
        error: null,
      ),
    );
    Result<MusicianProfile> result;
    try {
      result = await operation();
    } catch (_) {
      result = const Result.failure(
        AppError(
          code: 'musician_profile_failed',
          message: 'Profil işlemi tamamlanamadı.',
        ),
      );
    }
    if (isClosed || !identical(manager?.session, session)) return stale;
    if (generation != _generation && action != MusicianProfileAction.update) {
      return stale;
    }
    final profile = result.data;
    final expectedUser =
        expectedSessionKey ??
        (ownerRead || action == MusicianProfileAction.update
            ? session?.userId
            : null);
    if (result.isSuccess &&
        (profile == null ||
            profile.id.trim().isEmpty ||
            profile.userId.trim().isEmpty ||
            (targetProfileId != null && profile.id != targetProfileId) ||
            (expectedUser != null && profile.userId != expectedUser))) {
      result = const Result.failure(
        AppError(
          code: 'musician_profile_identity',
          message: 'Profil yanıtı doğrulanamadı.',
        ),
      );
    }
    // A newer view owns presentation, but the editor still needs the actual
    // mutation result instead of treating a committed write as a failure.
    if (generation == _generation) {
      emit(
        state.copyWith(
          status: result.isSuccess
              ? MusicianProfileStatus.success
              : MusicianProfileStatus.failure,
          action: action,
          profile: result.isSuccess ? result.data : state.profile,
          error: result.error,
        ),
      );
    }
    return result;
  }
}
