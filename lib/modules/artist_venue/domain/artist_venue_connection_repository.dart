import '../../../core/error/result.dart';

abstract class ArtistVenueConnectionRepository {
  Future<Result<List<String>>> getAcceptedVenues(String musicianProfileId);
}
