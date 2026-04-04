import '../../../core/error/result.dart';

abstract class TrackManagementRepository {
  Future<Result<void>> createTrack({
    required String profileId,
    required String ownerType,
    required String mediaAssetId,
    required String title,
  });
}
