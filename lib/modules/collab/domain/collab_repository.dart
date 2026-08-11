import '../../../core/error/result.dart';
import 'collab_commands.dart';
import 'collab_page.dart';
import 'collab_types.dart';
import 'entities/collab_actor.dart';
import 'entities/collab_application.dart';
import 'entities/collab_job.dart';
import 'entities/collab_listing.dart';
import 'entities/collab_review.dart';

abstract class CollabRepository {
  Future<Result<List<CollabActor>>> getMyActors();

  Future<Result<CollabPage<CollabListing>>> discover(
    CollabDiscoveryQuery query,
  );

  Future<Result<CollabListing>> getListing(String listingId);

  Future<Result<CollabListing>> createDraft(
    CollabListingInput input, {
    required String clientRequestId,
  });

  Future<Result<CollabListing>> updateDraft(
    String listingId,
    CollabListingInput input, {
    required int expectedVersion,
  });

  Future<Result<CollabListing>> publishDraft(
    String listingId, {
    required int expectedVersion,
  });

  Future<Result<void>> deleteDraft(
    String listingId, {
    required int expectedVersion,
  });

  Future<Result<CollabListing>> updateListing(
    String listingId,
    CollabListingInput input, {
    required int expectedVersion,
  });

  Future<Result<CollabListing>> closeListing(
    String listingId, {
    required int expectedVersion,
  });

  Future<Result<CollabPage<CollabListing>>> getMyListings({
    CollabListingStatus? status,
    int page = 0,
    int size = 20,
  });

  Future<Result<CollabPage<CollabListing>>> getSavedListings({
    int page = 0,
    int size = 20,
  });

  Future<Result<void>> saveListing(String listingId);
  Future<Result<void>> unsaveListing(String listingId);

  Future<Result<void>> reportListing(
    String listingId,
    CollabReportInput input, {
    required String clientRequestId,
  });

  Future<Result<CollabApplication>> apply(
    String listingId,
    CollabApplicationInput input, {
    required String clientRequestId,
  });

  Future<Result<CollabPage<CollabApplication>>> getMyApplications({
    CollabApplicationStatus? status,
    int page = 0,
    int size = 20,
  });

  Future<Result<CollabPage<CollabApplication>>> getIncomingApplications(
    String listingId, {
    CollabApplicationStatus? status,
    int page = 0,
    int size = 20,
  });

  Future<Result<CollabJob>> acceptApplication(
    String applicationId, {
    required int expectedVersion,
  });

  Future<Result<CollabApplication>> rejectApplication(
    String applicationId, {
    required int expectedVersion,
  });

  Future<Result<CollabApplication>> withdrawApplication(
    String applicationId, {
    required int expectedVersion,
  });

  Future<Result<CollabPage<CollabJob>>> getMyJobs({
    CollabJobStatus? status,
    int page = 0,
    int size = 20,
  });

  Future<Result<CollabJob>> confirmJobCompletion(
    String jobId, {
    required int expectedVersion,
  });

  Future<Result<CollabReview>> createReview(
    String jobId,
    CollabReviewInput input, {
    required String clientRequestId,
  });

  Future<Result<CollabPage<CollabReview>>> getActorReviews(
    String actorId, {
    int page = 0,
    int size = 20,
  });
}
