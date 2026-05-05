import '../../../core/error/result.dart';
import '../../profile/domain/entities/artist_venue_application.dart';
import '../../profile/domain/entities/profile_venue_models.dart';

abstract class ArtistVenueConnectionRepository {
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
  });
  Future<Result<void>> createBandRequest({
    required String bandId,
    required String venueId,
    required String message,
  });
  Future<Result<void>> createVenueRequest({
    required String musicianProfileId,
    required String venueId,
    required String message,
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
  Future<Result<void>> acceptRequest(String requestId);
  Future<Result<void>> rejectRequest(String requestId);
  Future<Result<void>> cancelRequest(String requestId);
  Future<Result<void>> disconnect(String requestId);
}
