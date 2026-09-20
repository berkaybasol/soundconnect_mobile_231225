import '../../../core/error/result.dart';
import 'marketplace_models.dart';

abstract class MarketplaceRepository {
  Future<Result<List<MarketplaceCategory>>> getCategories();
  Future<Result<MarketplacePage>> discover(
    MarketplaceQuery query, {
    int page = 0,
  });
  Future<Result<MarketplacePage>> getMyListings({
    MarketplaceStatus? status,
    int page = 0,
  });
  Future<Result<MarketplacePage>> getSavedListings({int page = 0});
  Future<Result<MarketplaceListing>> getListing(String id);
  Future<Result<MarketplaceListing>> createDraft(String clientRequestId);
  Future<Result<MarketplaceListing>> updateListing(
    String id,
    MarketplaceListingInput input, {
    required int expectedVersion,
  });
  Future<Result<MarketplaceListing>> transition(
    String id,
    String action, {
    required int expectedVersion,
  });
  Future<Result<void>> deleteDraft(String id, {required int expectedVersion});
  Future<Result<void>> setSaved(String id, bool saved);
  Future<Result<void>> report(
    String id, {
    required String reason,
    required String description,
    required String clientRequestId,
  });
}
