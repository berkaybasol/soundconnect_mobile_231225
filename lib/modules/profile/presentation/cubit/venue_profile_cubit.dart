import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../data/models/venue_profile_save_request.dart';
import '../../domain/entities/venue_owner_profile.dart';
import '../../domain/entities/venue_public_profile.dart';
import '../../domain/venue_profile_repository.dart';
import 'venue_profile_state.dart';

class VenueProfileCubit extends Cubit<VenueProfileState> {
  final VenueProfileRepository _repository;
  int _generation = 0;
  Future<Result<VenueOwnerProfile>>? _update;
  final AuthSessionManager? _sessions;

  VenueProfileCubit(this._repository, {AuthSessionManager? sessions})
    : _sessions =
          sessions ??
          (serviceLocator.isRegistered<AuthSessionManager>()
              ? serviceLocator<AuthSessionManager>()
              : null),
      super(const VenueProfileState.idle()) {
    _sessions?.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (isClosed) return;
    ++_generation;
    emit(const VenueProfileState.idle());
  }

  @override
  Future<void> close() {
    _sessions?.removeListener(_sessionChanged);
    return super.close();
  }

  static const _stale = AppError(
    code: 'venue_profile_stale',
    message: 'Profil veya oturum değişti. Sayfayı yeniden aç.',
  );
  static const _invalid = AppError(
    code: 'venue_profile_identity',
    message: 'Mekân profili yanıtı doğrulanamadı.',
  );

  Future<void> loadOwner({String? venueId}) async {
    if (isClosed) return;
    final generation = ++_generation;
    final sessions = _sessions;
    final session = sessions?.session;
    // Read the committed update. Reserve the generation before waiting so a
    // newer navigation always owns presentation.
    final update = _update;
    if (update != null) await update;
    bool current() =>
        !isClosed &&
        generation == _generation &&
        identical(sessions?.session, session);
    if (!current()) return;
    final target = venueId?.trim();
    emit(
      state.copyWith(
        status: VenueProfileStatus.loading,
        view: VenueProfileView.owner,
        ownerProfile:
            state.ownerProfile?.venueId == target &&
                (session == null ||
                    state.ownerProfile?.ownerUserId == session.userId)
            ? state.ownerProfile
            : null,
        publicProfile: null,
        error: null,
      ),
    );
    var result = await _safe(
      () => _repository.getMyVenueProfileDetail(venueId: venueId),
    );
    if (!current()) return;
    if (result.isSuccess &&
        !_validOwner(result.data, target, session?.userId)) {
      result = const Result.failure(_invalid);
    }
    emit(
      state.copyWith(
        status: result.isSuccess
            ? VenueProfileStatus.success
            : VenueProfileStatus.failure,
        ownerProfile: result.isSuccess ? result.data : null,
        error: result.error,
      ),
    );
  }

  Future<void> loadPublic({String? venueId}) async {
    if (isClosed) return;
    final generation = ++_generation;
    final sessions = _sessions;
    final session = sessions?.session;
    final target = venueId?.trim();
    emit(
      state.copyWith(
        status: VenueProfileStatus.loading,
        view: VenueProfileView.public,
        ownerProfile: null,
        publicProfile: state.publicProfile?.venueId == target
            ? state.publicProfile
            : null,
        error: null,
      ),
    );
    var result = await _safe(
      () => _repository.getPublicVenueProfile(venueId: venueId),
    );
    if (isClosed ||
        generation != _generation ||
        !identical(sessions?.session, session)) {
      return;
    }
    final profile = result.data;
    if (result.isSuccess &&
        (profile == null ||
            profile.venueProfileId.trim().isEmpty ||
            profile.venueId.trim().isEmpty ||
            profile.ownerUserId.trim().isEmpty ||
            (target?.isNotEmpty == true && profile.venueId != target))) {
      result = const Result<VenuePublicProfile>.failure(_invalid);
    }
    emit(
      state.copyWith(
        status: result.isSuccess
            ? VenueProfileStatus.success
            : VenueProfileStatus.failure,
        publicProfile: result.isSuccess ? result.data : null,
        error: result.error,
      ),
    );
  }

  Future<Result<VenueOwnerProfile>> updateOwnerProfile(
    VenueProfileSaveRequest request, {
    String? venueId,
    String? expectedSessionKey,
  }) async {
    if (_update != null) {
      return const Result.failure(
        AppError(
          code: 'venue_profile_busy',
          message: 'Devam eden profil işlemini bekle.',
        ),
      );
    }
    final operation = _performUpdate(request, venueId, expectedSessionKey);
    _update = operation;
    try {
      return await operation;
    } finally {
      _update = null;
    }
  }

  Future<Result<VenueOwnerProfile>> _performUpdate(
    VenueProfileSaveRequest request,
    String? venueId,
    String? expectedSessionKey,
  ) async {
    final sessions = _sessions;
    final session = sessions?.session;
    final target = venueId?.trim() ?? state.ownerProfile?.venueId;
    if (isClosed ||
        (sessions != null &&
            (session?.isAuthenticated != true ||
                session?.isActive != true ||
                !session!.hasAnyRole(const ['VENUE', 'ROLE_VENUE']) ||
                (expectedSessionKey != null &&
                    expectedSessionKey != session.userId) ||
                (state.ownerProfile != null &&
                    state.ownerProfile!.ownerUserId != session.userId)))) {
      return const Result.failure(_stale);
    }
    final generation = ++_generation;
    emit(
      state.copyWith(
        status: VenueProfileStatus.loading,
        view: VenueProfileView.owner,
        ownerProfile: state.ownerProfile?.venueId == target
            ? state.ownerProfile
            : null,
        publicProfile: null,
        error: null,
      ),
    );
    var result = await _safe(
      () => _repository.updateMyVenueProfileDetail(request, venueId: target),
    );
    if (isClosed || !identical(sessions?.session, session)) {
      return const Result.failure(_stale);
    }
    if (result.isSuccess &&
        !_validOwner(result.data, target, session?.userId)) {
      result = const Result.failure(_invalid);
    }
    // A newer view owns presentation; the caller still needs the write result.
    if (generation == _generation) {
      emit(
        state.copyWith(
          status: result.isSuccess
              ? VenueProfileStatus.success
              : VenueProfileStatus.failure,
          ownerProfile: result.isSuccess ? result.data : state.ownerProfile,
          error: result.error,
        ),
      );
    }
    return result;
  }

  static bool _validOwner(
    VenueOwnerProfile? profile,
    String? target,
    String? userId,
  ) =>
      profile != null &&
      profile.venueProfileId.trim().isNotEmpty &&
      profile.venueId.trim().isNotEmpty &&
      profile.ownerUserId.trim().isNotEmpty &&
      (target?.isNotEmpty != true || profile.venueId == target) &&
      (userId == null || profile.ownerUserId == userId);

  static Future<Result<T>> _safe<T>(
    Future<Result<T>> Function() request,
  ) async {
    try {
      return await request();
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'venue_profile_unexpected',
          message: 'Mekân profili işlemi tamamlanamadı.',
        ),
      );
    }
  }
}
