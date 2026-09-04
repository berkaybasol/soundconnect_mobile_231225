import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/listener_profile.dart';
import '../../domain/entities/listener_public_profile.dart';
import '../../domain/entities/listener_visibility_mode.dart';
import '../../domain/listener_profile_repository.dart';
import 'listener_profile_state.dart';

class ListenerProfileCubit extends Cubit<ListenerProfileState> {
  final ListenerProfileRepository _repository;
  int _loadGeneration = 0;
  Future<void>? _ownerMutationTail;

  ListenerProfileCubit(this._repository)
    : super(const ListenerProfileState.idle());

  Future<void> loadMyProfile() async {
    final activeMutation = _ownerMutationTail;
    if (activeMutation != null) await activeMutation;
    if (isClosed) return;
    final generation = ++_loadGeneration;
    emit(
      state.copyWith(
        status: ListenerProfileStatus.loading,
        view: ListenerProfileView.owner,
        action: ListenerProfileAction.load,
        error: null,
      ),
    );
    final result = await _safeOwnerRequest(_repository.getMyProfile);
    if (isClosed || generation != _loadGeneration) return;
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: ListenerProfileStatus.success,
          profile: result.data,
          publicProfile: null,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: ListenerProfileStatus.failure,
        error: result.error,
      ),
    );
  }

  Future<void> loadPublicProfile(String profileId) async {
    if (isClosed) return;
    final generation = ++_loadGeneration;
    emit(
      state.copyWith(
        status: ListenerProfileStatus.loading,
        publicProfile: null,
        view: ListenerProfileView.public,
        action: ListenerProfileAction.load,
        error: null,
      ),
    );
    final result = await _safePublicRequest(
      () => _repository.getPublicProfile(profileId),
    );
    if (isClosed || generation != _loadGeneration) return;
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: ListenerProfileStatus.success,
          publicProfile: result.data,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: ListenerProfileStatus.failure,
        error: result.error,
      ),
    );
  }

  Future<void> updateVisibility(ListenerVisibilityMode visibilityMode) {
    return _enqueueOwnerMutation(
      ListenerProfileAction.updateVisibility,
      (profile) => _repository.updateVisibility(
        ListenerVisibilityUpdateRequest(
          visibilityMode: visibilityMode,
          expectedVersion: profile.version,
        ),
      ),
    );
  }

  Future<void> updateAvatar(String? profilePictureMediaId) {
    return _enqueueOwnerMutation(
      ListenerProfileAction.updateAvatar,
      (profile) => _repository.updateAvatar(
        ListenerAvatarUpdateRequest(
          profilePictureMediaId: profilePictureMediaId,
          expectedVersion: profile.version,
        ),
      ),
    );
  }

  Future<void> replacePlaylists(List<String> spotifyUrls) {
    return _enqueueOwnerMutation(
      ListenerProfileAction.updatePlaylists,
      (profile) => _repository.replacePlaylists(
        ListenerPlaylistsReplaceRequest(
          spotifyUrls: spotifyUrls,
          expectedVersion: profile.version,
        ),
      ),
    );
  }

  Future<void> _enqueueOwnerMutation(
    ListenerProfileAction action,
    Future<Result<ListenerProfile>> Function(ListenerProfile profile) request,
  ) {
    final previous = _ownerMutationTail;
    final mutation = (previous ?? Future<void>.value()).then(
      (_) => _performOwnerMutation(action, request),
    );
    final safeTail = mutation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _ownerMutationTail = safeTail;
    safeTail.whenComplete(() {
      if (identical(_ownerMutationTail, safeTail)) _ownerMutationTail = null;
    });
    return mutation;
  }

  Future<void> _performOwnerMutation(
    ListenerProfileAction action,
    Future<Result<ListenerProfile>> Function(ListenerProfile profile) request,
  ) async {
    if (isClosed) return;
    final profile = state.profile;
    if (profile == null) {
      emit(
        state.copyWith(
          status: ListenerProfileStatus.failure,
          view: ListenerProfileView.owner,
          action: action,
          error: const AppError(
            code: 'listener_profile_not_loaded',
            message: 'Profil henüz yüklenmedi. Lütfen tekrar deneyin.',
          ),
        ),
      );
      return;
    }

    final generation = ++_loadGeneration;
    emit(
      state.copyWith(
        status: ListenerProfileStatus.saving,
        view: ListenerProfileView.owner,
        action: action,
        error: null,
      ),
    );
    final result = await _safeOwnerRequest(() => request(profile));
    if (isClosed) return;
    if (generation != _loadGeneration) {
      // Keep the owner cache current without replacing a newer public/load
      // presentation state that was selected while this request was running.
      if (result.isSuccess && result.data != null) {
        emit(state.copyWith(profile: result.data));
      }
      return;
    }
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: ListenerProfileStatus.success,
          profile: result.data,
          publicProfile: null,
          error: null,
        ),
      );
      return;
    }

    if (_isVersionConflict(result.error)) {
      final refreshed = await _safeOwnerRequest(_repository.getMyProfile);
      if (isClosed || generation != _loadGeneration) return;
      if (refreshed.isSuccess && refreshed.data != null) {
        emit(
          state.copyWith(
            status: ListenerProfileStatus.failure,
            profile: refreshed.data,
            publicProfile: null,
            error: AppError(
              code: result.error!.code,
              message:
                  'Profil başka bir oturumda değişti. Güncel profili aldık; seçimini kontrol edip tekrar dene.',
              details: result.error!.details,
            ),
          ),
        );
        return;
      }
    }

    emit(
      state.copyWith(
        status: ListenerProfileStatus.failure,
        error: result.error,
      ),
    );
  }

  static bool _isVersionConflict(AppError? error) {
    final code = error?.code.trim().toUpperCase();
    return code == '1304' || code == 'LISTENER_PROFILE_VERSION_CONFLICT';
  }

  static Future<Result<ListenerProfile>> _safeOwnerRequest(
    Future<Result<ListenerProfile>> Function() request,
  ) async {
    try {
      return await request();
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'listener_profile_unexpected',
          message: 'Dinleyici profili işlemi tamamlanamadı.',
        ),
      );
    }
  }

  static Future<Result<ListenerPublicProfile>> _safePublicRequest(
    Future<Result<ListenerPublicProfile>> Function() request,
  ) async {
    try {
      return await request();
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'listener_profile_unexpected',
          message: 'Dinleyici profili işlemi tamamlanamadı.',
        ),
      );
    }
  }
}
