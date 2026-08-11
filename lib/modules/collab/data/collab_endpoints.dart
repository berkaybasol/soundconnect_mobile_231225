abstract final class CollabEndpoints {
  static const String root = '/api/v1/collabs';
  static const String actorsMe = '$root/actors/me';
  static const String drafts = '$root/drafts';
  static const String myListings = '$root/me/listings';
  static const String myApplications = '$root/me/applications';
  static const String myJobs = '$root/me/jobs';
  static const String savedListings = '$root/me/saved';

  static String listing(String listingId) => '$root/$listingId';
  static String draft(String listingId) => '$drafts/$listingId';
  static String publishDraft(String listingId) =>
      '${listing(listingId)}/publish';
  static String closeListing(String listingId) => '${listing(listingId)}/close';
  static String listingSaved(String listingId) => '${listing(listingId)}/saved';
  static String listingApplications(String listingId) =>
      '${listing(listingId)}/applications';
  static String listingReport(String listingId) =>
      '${listing(listingId)}/reports';
  static String incomingApplications(String listingId) =>
      '$myListings/$listingId/applications';
  static String applicationAction(String applicationId, String action) =>
      '$root/applications/$applicationId/$action';
  static String jobCompletion(String jobId) =>
      '$root/jobs/$jobId/confirm-completion';
  static String jobReviews(String jobId) => '$root/jobs/$jobId/reviews';
  static String actorReviews(String actorId) => '$root/actors/$actorId/reviews';
}
