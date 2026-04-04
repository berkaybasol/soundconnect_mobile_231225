import 'package:dio/dio.dart';

import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/profile_upload_result.dart';
import '../domain/profile_media_upload_repository.dart';

class ProfileMediaUploadRepositoryImpl implements ProfileMediaUploadRepository {
  final ApiClient _apiClient;

  ProfileMediaUploadRepositoryImpl(this._apiClient);

  @override
  Future<Result<ProfileUploadedMedia>> uploadAsset({
    required List<int> bytes,
    required String ownerType,
    required String ownerId,
    required String mediaKind,
    required String mimeType,
    required String originalFileName,
  }) async {
    if (bytes.isEmpty) {
      return Result.failure(
        const AppError(
          code: 'profile_upload_empty',
          message: 'Yuklenecek dosya bos olamaz',
        ),
      );
    }

    try {
      final initResult = await _apiClient.post<ProfileUploadInitResult>(
        '/api/v1/user/media/init-upload',
        body: {
          'ownerType': ownerType,
          'ownerId': ownerId,
          'kind': mediaKind,
          'visibility': 'PUBLIC',
          'mimeType': mimeType,
          'sizeBytes': bytes.length,
          'originalFileName': originalFileName,
        },
        decoder: (json) =>
            ProfileUploadInitResult.fromJson(json as Map<String, dynamic>),
      );

      await Dio().put(
        initResult.uploadUrl,
        data: bytes,
        options: Options(
          headers: {'Content-Type': mimeType},
          contentType: mimeType,
        ),
      );

      final completed = await _apiClient.post<ProfileUploadedMedia>(
        '/api/v1/user/media/complete-upload',
        body: {'assetId': initResult.assetId},
        decoder: (json) =>
            ProfileUploadedMedia.fromJson(json as Map<String, dynamic>),
      );

      return Result.success(completed);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'profile_upload_unknown',
          message: 'Medya yüklenemedi',
        ),
      );
    }
  }
}
