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
  final String? Function()? sessionKeyProvider;

  ListenerProfileRepositoryImpl(this._apiClient, {this.sessionKeyProvider});

  Future<ListenerProfile> _ownerRequest(
    ApiHttpMethod method,
    String path, {
    Object? body,
  }) async {
    final session = sessionKeyProvider?.call()?.trim();
    const error = AppError(
      code: 'listener_profile_session_changed',
      message: 'Oturum değişti. Dinleyici profilini yeniden aç.',
    );
    if (sessionKeyProvider != null && session?.isNotEmpty != true) {
      throw ApiException(error);
    }
    final response = await _apiClient.request<ListenerProfile>(
      method,
      path,
      body: body,
      decoder: ListenerProfileModel.fromJson,
      requestContext: sessionKeyProvider == null
          ? null
          : ApiRequestContext(expectedSessionKey: session),
    );
    if (sessionKeyProvider != null &&
        (session != sessionKeyProvider?.call()?.trim() ||
            response.userId != session)) {
      throw ApiException(error);
    }
    return response;
  }

  @override
  Future<Result<ListenerProfile>> getMyProfile() async {
    try {
      final response = await _ownerRequest(
        ApiHttpMethod.get,
        ListenerProfileEndpoints.me,
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
      final response = await _ownerRequest(
        ApiHttpMethod.put,
        ListenerProfileEndpoints.update,
        body: request.toJson(),
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
      final response = await _ownerRequest(
        ApiHttpMethod.patch,
        ListenerProfileEndpoints.visibility,
        body: request.toJson(),
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
      final response = await _ownerRequest(
        ApiHttpMethod.patch,
        ListenerProfileEndpoints.avatar,
        body: normalizedRequest.toJson(),
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

  @override
  Future<Result<ListenerProfile>> replacePlaylists(
    ListenerPlaylistsReplaceRequest request,
  ) async {
    final body = request.toValidatedJson();
    if (body == null) {
      return const Result.failure(
        AppError(
          code: 'listener_playlist_validation',
          message:
              'En fazla 4 farklı ve geçerli Spotify çalma listesi ekleyebilirsin.',
        ),
      );
    }
    try {
      final response = await _ownerRequest(
        ApiHttpMethod.put,
        ListenerProfileEndpoints.playlists,
        body: body,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } on FormatException {
      return const Result.failure(_invalidOwnerResponse);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'listener_playlists_update_unknown',
          message: 'Çalma listeleri güncellenemedi.',
        ),
      );
    }
  }
}

const _invalidOwnerResponse = AppError(
  code: 'listener_profile_invalid_response',
  message: 'Dinleyici profili beklenen biçimde alınamadı.',
);
