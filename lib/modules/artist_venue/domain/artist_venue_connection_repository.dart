import '../../../core/error/result.dart';
import 'artist_venue_application_page.dart';
import '../../profile/domain/entities/artist_venue_application.dart';
import '../../profile/domain/entities/profile_venue_models.dart';

abstract class ArtistVenueConnectionRepository {
  /// Connections use ACCEPTED across both directions; otherwise [incoming]
  /// selects the request history. Filtering/pagination happen on the server.
  Future<Result<ArtistVenueApplicationPage>> listApplicationPage({
    required ArtistVenueApplicationTarget target,
    required String targetId,
    required bool incoming,
    bool connectionsOnly = false,
    int page = 0,
    int size = 20,
    String? expectedSessionKey,
  });
  Future<Result<List<String>>> getAcceptedVenues(String musicianProfileId);
  Future<Result<List<VenueConnection>>> getVenueConnectionsByStatus(
    String musicianProfileId, {
    required String status,
  });
  Future<Result<List<MusicianConnection>>> getMusicianConnectionsByStatus(
    String venueId, {
    required String status,
  });
  Future<Result<void>> createArtistRequest({
    required String musicianProfileId,
    required String venueId,
    required String message,
    String? expectedSessionKey,
  });
  Future<Result<void>> createBandRequest({
    required String bandId,
    required String venueId,
    required String message,
    String? expectedSessionKey,
  });
  Future<Result<void>> createVenueRequest({
    required String musicianProfileId,
    required String venueId,
    required String message,
    String? expectedSessionKey,
  });
  Future<Result<void>> createVenueBandRequest({
    required String bandId,
    required String venueId,
    required String message,
    String? expectedSessionKey,
  });
  Future<Result<List<VenueConnection>>> getVenueConnectionsByBandStatus(
    String bandId, {
    required String status,
  });
  Future<Result<List<ArtistVenueApplication>>> listVenueApplications(
    String venueId,
  );
  Future<Result<List<ArtistVenueApplication>>> listMusicianVenueApplications(
    String musicianProfileId,
  );
  Future<Result<List<ArtistVenueApplication>>> listBandVenueApplications(
    String bandId,
  );
  Future<Result<void>> acceptRequest(
    String requestId, {
    String? expectedSessionKey,
  });
  Future<Result<void>> rejectRequest(
    String requestId, {
    String? expectedSessionKey,
  });
  Future<Result<void>> cancelRequest(
    String requestId, {
    String? expectedSessionKey,
  });
  Future<Result<void>> disconnect(
    String requestId, {
    String? expectedSessionKey,
  });
}
