import '../../../core/error/result.dart';
import 'entities/band_profile.dart';
import 'entities/band_summary.dart';

abstract class BandRepository {
  Future<Result<List<BandSummary>>> getMyBands();

  Future<Result<BandProfile>> getBandById(String bandId);
  Future<Result<BandProfile>> getPublicBandById(String bandId);

  Future<Result<BandSummary>> createBand({
    required String name,
    String? description,
  });

  Future<Result<BandProfile>> updateBand({
    required String bandId,
    String? name,
    String? description,
    String? profilePicture,
    String? instagramUrl,
    String? youtubeUrl,
    String? soundCloudUrl,
    String? spotifyEmbedUrl,
    String? spotifyArtistId,
    List<String>? spotifyTrackIds,
  });

  Future<Result<void>> inviteMember({
    required String bandId,
    required String invitedUserId,
    String? message,
  });

  Future<Result<void>> acceptInvite({required String bandId});

  Future<Result<void>> rejectInvite({required String bandId});

  Future<Result<void>> removeMember({
    required String bandId,
    required String userId,
  });

  Future<Result<void>> leaveBand({required String bandId});

  Future<Result<void>> deleteBand({required String bandId});
}
