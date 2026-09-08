import '../../../core/error/result.dart';
import 'entities/band_profile.dart';
import 'entities/band_summary.dart';
import 'entities/band_member_summary.dart';
import 'entities/band_pending_invitation.dart';
import 'entities/band_received_invitation.dart';

abstract class BandRepository {
  Future<Result<BandReceivedInvitation>> getCurrentReceivedInvitation({
    required String bandId,
    required String expectedSessionKey,
  });
  Future<Result<BandReceivedInvitationPage>> getReceivedInvitations({
    int page = 0,
    int size = 20,
    required String expectedSessionKey,
  });
  Future<Result<List<BandSummary>>> getMyBands();

  Future<Result<BandProfile>> getBandById(String bandId);
  Future<Result<BandProfile>> getPublicBandById(String bandId);

  Future<Result<BandPendingInvitationPage>> getPendingInvitations({
    required String bandId,
    int page = 0,
    int size = 20,
    required String expectedSessionKey,
  });

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
    String? expectedSessionKey,
  });

  Future<Result<void>> acceptInvite({
    required String bandId,
    String? expectedSessionKey,
    String? invitationId,
  });

  Future<Result<void>> rejectInvite({
    required String bandId,
    String? expectedSessionKey,
    String? invitationId,
  });

  Future<Result<void>> removeMember({
    required String bandId,
    required String userId,
    String? expectedSessionKey,
    int? expectedTitleVersion,
  });

  Future<Result<void>> leaveBand({
    required String bandId,
    String? expectedSessionKey,
    int? expectedTitleVersion,
  });

  Future<Result<BandMemberSummary>> updateMemberTitle({
    required String bandId,
    required String userId,
    required String? memberTitle,
    required int expectedTitleVersion,
    required String expectedSessionKey,
  });

  Future<Result<void>> deleteBand({required String bandId});
}
