import '../../../core/error/result.dart';
import 'entities/profile_upload_result.dart';

abstract class ProfileMediaUploadRepository {
  Future<Result<ProfileUploadedMedia>> uploadAsset({
    required List<int> bytes,
    required String ownerType,
    required String ownerId,
    required String mediaKind,
    required String mimeType,
    required String originalFileName,
  });
}
