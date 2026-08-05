import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/profile_media_management_repository_impl.dart';

import 'support/recording_api_client.dart';

void main() {
  group('ProfileMediaManagementRepositoryImpl', () {
    test('posts the canonical gallery association body', () async {
      final api = RecordingApiClient((_) => null);
      final repository = ProfileMediaManagementRepositoryImpl(api);

      final result = await repository.addGalleryMedia(
        profileType: 'MUSICIAN',
        profileId: 'profile-1',
        mediaAssetId: 'asset-1',
        orderIndex: 3,
      );

      expect(result.isSuccess, isTrue);
      expect(api.lastRequest.method, RecordedHttpMethod.post);
      expect(api.lastRequest.path, '/api/v1/profile-media');
      expect(api.lastRequest.body, <String, dynamic>{
        'profileType': 'MUSICIAN',
        'profileId': 'profile-1',
        'mediaAssetId': 'asset-1',
        'role': 'GALLERY',
        'orderIndex': 3,
      });
    });

    test('keeps typed errors distinct from unknown failures', () async {
      const typed = AppError(code: 'forbidden', message: 'Forbidden');
      final typedResult =
          await ProfileMediaManagementRepositoryImpl(
            RecordingApiClient((_) => throw ApiException(typed)),
          ).addGalleryMedia(
            profileType: 'MUSICIAN',
            profileId: 'profile-1',
            mediaAssetId: 'asset-1',
          );
      final unknownResult =
          await ProfileMediaManagementRepositoryImpl(
            RecordingApiClient((_) => throw StateError('broken')),
          ).addGalleryMedia(
            profileType: 'MUSICIAN',
            profileId: 'profile-1',
            mediaAssetId: 'asset-1',
          );

      expect(typedResult.error, same(typed));
      expect(unknownResult.error?.code, 'profile_media_add_unknown');
    });
  });
}
