import '../../../core/error/result.dart';
import '../data/models/venue_profile_save_request.dart';
import 'entities/venue_owner_profile.dart';
import 'entities/venue_profile_summary.dart';
import 'entities/venue_public_profile.dart';

abstract class VenueProfileRepository {
  Future<Result<List<VenueProfileSummary>>> getMyVenueProfiles();

  Future<Result<VenueOwnerProfile>> getMyVenueProfileDetail({String? venueId});

  Future<Result<VenueOwnerProfile>> updateMyVenueProfileDetail(
    VenueProfileSaveRequest request, {
    String? venueId,
  });

  Future<Result<VenuePublicProfile>> getPublicVenueProfile({String? venueId});
}
