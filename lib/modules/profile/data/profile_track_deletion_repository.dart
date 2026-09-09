import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class ProfileTrackDeletionRepository {
  final ApiClient api;
  final AuthSessionManager sessions;
  ProfileTrackDeletionRepository(this.api, this.sessions);

  static bool supports(String ownerType) =>
      const ['MUSICIAN_PROFILE', 'BAND', 'STUDIO_PROFILE'].contains(ownerType);

  Future<Result<void>> delete({
    required String ownerType,
    required String ownerId,
    required String trackId,
  }) async {
    final session = sessions.session;
    if (!session.isAuthenticated ||
        !session.isActive ||
        session.userId == null ||
        !supports(ownerType) ||
        ownerId.trim().isEmpty ||
        trackId.trim().isEmpty) {
      return const Result.failure(
        AppError(
          code: 'track_delete_invalid',
          message: 'Ses silinemedi. Profil ve oturum bilgilerini kontrol et.',
        ),
      );
    }
    final resource = switch (ownerType) {
      'MUSICIAN_PROFILE' => 'musician-profiles',
      'BAND' => 'bands',
      _ => 'studio-profiles',
    };
    try {
      await api.request<Object?>(
        ApiHttpMethod.delete,
        '/api/v1/$resource/${Uri.encodeComponent(ownerId)}/tracks/${Uri.encodeComponent(trackId)}',
        requestContext: ApiRequestContext(expectedSessionKey: session.userId),
        decoder: (_) => null,
      );
      if (!identical(session, sessions.session)) {
        return const Result.failure(
          AppError(
            code: 'track_delete_session_changed',
            message: 'Oturum değişti. Profili yeniden aç.',
          ),
        );
      }
      return const Result.success(null);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'track_delete_failed',
          message: 'Ses silinemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }
}
