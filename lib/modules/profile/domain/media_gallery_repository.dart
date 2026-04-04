import '../../../core/error/result.dart';
import 'entities/media_asset.dart';

abstract class MediaGalleryRepository {
  Future<Result<List<MediaAsset>>> listPublicImages({
    required String ownerType,
    required String ownerId,
    int page = 0,
    int size = 50,
  });
}
