import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/listener_profile.dart';
import '../domain/entities/listener_public_profile.dart';
import '../domain/listener_profile_repository.dart';
import 'listener_profile_endpoints.dart';
import 'models/listener_profile_model.dart';
import 'models/listener_public_profile_model.dart';

class ListenerProfileRepositoryImpl implements ListenerProfileRepository {
  final ApiClient _apiClient;

  ListenerProfileRepositoryImpl(this._apiClient);

  @override
  Future<Result<ListenerProfile>> getMyProfile() async {
    try {
      final response = await _apiClient.get<ListenerProfile>(
        ListenerProfileEndpoints.me,
        decoder: ListenerProfileModel.fromJson,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } on FormatException {
      return const Result.failure(_invalidOwnerResponse);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'listener_profile_unknown',
          message: 'Listener profili getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<ListenerPublicProfile>> getPublicProfile(
    String profileId,
  ) async {
    final normalizedId = profileId.trim();
    if (normalizedId.isEmpty) {
      return const Result.failure(
        AppError(
          code: 'listener_profile_validation',
          message: 'Dinleyici profil kimliği eksik.',
        ),
      );
    }
    try {
      final response = await _apiClient.get<ListenerPublicProfile>(
        ListenerProfileEndpoints.publicDetail(normalizedId),
        decoder: ListenerPublicProfileModel.fromJson,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'listener_public_profile_invalid_response',
          message: 'Dinleyici profili beklenen biçimde alınamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'listener_public_profile_unknown',
          message: 'Dinleyici profili getirilemedi.',
        ),
      );
    }
  }

  @override
  Future<Result<ListenerProfile>> updateMyProfile(
    ListenerProfileSaveRequest request,
  ) async {
    try {
      final response = await _apiClient.put<ListenerProfile>(
        ListenerProfileEndpoints.update,
        body: request.toJson(),
        decoder: ListenerProfileModel.fromJson,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } on FormatException {
      return const Result.failure(_invalidOwnerResponse);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'listener_profile_update_unknown',
          message: 'Listener profili güncellenemedi',
        ),
      );
    }
  }

  @override
  Future<Result<ListenerProfile>> updateVisibility(
    ListenerVisibilityUpdateRequest request,
  ) async {
    if (request.expectedVersion < 0) {
      return const Result.failure(
        AppError(
          code: 'listener_profile_validation',
          message: 'Profil sürüm bilgisi geçersiz. Lütfen profili yenileyin.',
        ),
      );
    }
    try {
      final response = await _apiClient.patch<ListenerProfile>(
        ListenerProfileEndpoints.visibility,
        body: request.toJson(),
        decoder: ListenerProfileModel.fromJson,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } on FormatException {
      return const Result.failure(_invalidOwnerResponse);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'listener_visibility_update_unknown',
          message: 'Profil görünürlüğü güncellenemedi.',
        ),
      );
    }
  }

  @override
  Future<Result<ListenerProfile>> updateAvatar(
    ListenerAvatarUpdateRequest request,
  ) async {
    final mediaId = request.profilePictureMediaId;
    if (request.expectedVersion < 0 ||
        (mediaId != null && mediaId.trim().isEmpty)) {
      return const Result.failure(
        AppError(
          code: 'listener_profile_validation',
          message: 'Profil fotoğrafı kimliği geçersiz.',
        ),
      );
    }
    final normalizedRequest = ListenerAvatarUpdateRequest(
      profilePictureMediaId: mediaId?.trim(),
      expectedVersion: request.expectedVersion,
    );
    try {
      final response = await _apiClient.patch<ListenerProfile>(
        ListenerProfileEndpoints.avatar,
        body: normalizedRequest.toJson(),
        decoder: ListenerProfileModel.fromJson,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } on FormatException {
      return const Result.failure(_invalidOwnerResponse);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'listener_avatar_update_unknown',
          message: 'Profil fotoğrafı güncellenemedi.',
        ),
      );
    }
  }
}

const _invalidOwnerResponse = AppError(
  code: 'listener_profile_invalid_response',
  message: 'Dinleyici profili beklenen biçimde alınamadı.',
);
