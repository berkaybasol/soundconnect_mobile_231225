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
  bool _updating = false;

  MusicianProfileCubit(this._repository)
    : super(const MusicianProfileState.idle());

  Future<void> loadMyProfile() async {
    await _run(_repository.getMyProfile, ownerRead: true);
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
    if (_updating) {
      return const Result.failure(
        AppError(
          code: 'musician_profile_busy',
          message: 'Devam eden profil işlemini bekle.',
        ),
      );
    }
    final expectedAccount =
        expectedSessionKey ??
        (serviceLocator.isRegistered<AuthSessionManager>()
            ? serviceLocator<AuthSessionManager>().session.userId
            : null);
    _updating = true;
    try {
      return await _run(
        () => _repository.updateMyProfile(
          request,
          expectedSessionKey: expectedAccount,
        ),
        action: MusicianProfileAction.update,
        expectedSessionKey: expectedAccount,
        targetProfileId: state.profile?.id,
      );
    } finally {
      _updating = false;
    }
  }

  Future<Result<MusicianProfile>> _run(
    Future<Result<MusicianProfile>> Function() operation, {
    MusicianProfileAction action = MusicianProfileAction.load,
    bool ownerRead = false,
    String? expectedSessionKey,
    String? targetProfileId,
  }) async {
    const stale = Result<MusicianProfile>.failure(
      AppError(
        code: 'musician_profile_stale',
        message: 'Profil değişti. Sayfayı yeniden aç.',
      ),
    );
    if (isClosed) return stale;
    final manager = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
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
    final generation = ++_generation;
    bool current() =>
        !isClosed &&
        generation == _generation &&
        identical(manager?.session, session);
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
    if (!current()) return stale;
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
    return result;
  }
}
