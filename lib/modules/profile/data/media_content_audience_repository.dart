import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/media_asset.dart';
import '../domain/entities/media_content_audience.dart';
import 'models/media_asset_model.dart';

class MediaContentAudienceRepository {
  final ApiClient api;
  final AuthSessionManager sessions;
  MediaContentAudienceRepository(this.api, this.sessions);

  Future<Result<MediaAsset>> update({
    required String assetId,
    required String ownerType,
    required String contentAudience,
  }) async {
    const stale = AppError(
      code: 'media_audience_session',
      message: 'Oturum değişti. Medyayı yeniden aç.',
    );
    const invalid = AppError(
      code: 'media_audience_invalid',
      message: 'Hedef kitle güncellenemedi.',
    );
    final session = sessions.session;
    if (!session.isAuthenticated ||
        !session.isActive ||
        session.userId?.isNotEmpty != true ||
        session.token?.isNotEmpty != true ||
        session.requiresListenerProfileChoice) {
      return const Result.failure(stale);
    }
    if (!MediaContentAudience.canChoose(ownerType) ||
        !MediaContentAudience.isValid(contentAudience) ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(assetId)) {
      return const Result.failure(invalid);
    }
    var revoked = false;
    void observe() {
      if (!identical(session, sessions.session)) revoked = true;
    }

    sessions.addListener(observe);
    try {
      final asset = await api.request<MediaAsset>(
        ApiHttpMethod.patch,
        '/api/v1/user/media/$assetId/content-audience',
        body: {'contentAudience': contentAudience},
        requestContext: ApiRequestContext(
          expectedSessionKey: session.userId,
          expectedToken: session.token,
        ),
        decoder: (json) {
          if (json is! Map<String, dynamic> ||
              json['contentAudience'] != contentAudience ||
              json['ownerType'] != ownerType.trim().toUpperCase()) {
            throw const FormatException('Unexpected media audience');
          }
          final value = MediaAssetModel.fromJson(json);
          if (value.id != assetId) {
            throw const FormatException('Unexpected media identity');
          }
          return value;
        },
      );
      return revoked ? const Result.failure(stale) : Result.success(asset);
    } on ApiException catch (error) {
      return Result.failure(revoked ? stale : error.error);
    } catch (_) {
      return Result.failure(revoked ? stale : invalid);
    } finally {
      sessions.removeListener(observe);
    }
  }
}
