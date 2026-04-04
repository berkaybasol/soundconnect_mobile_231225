import '../../../core/error/result.dart';

abstract class ProfileMediaManagementRepository {
  Future<Result<void>> addGalleryMedia({
    required String profileType,
    required String profileId,
    required String mediaAssetId,
    int? orderIndex,
  });
}
