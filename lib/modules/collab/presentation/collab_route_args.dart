enum CollabDeepLinkTarget {
  discovery,
  listing,
  incomingApplications,
  myApplications,
  jobs,
  reviews,
}

class CollabDiscoveryRouteArgs {
  const CollabDiscoveryRouteArgs({
    this.initialListingId,
    this.action,
    this.applicationId,
    this.jobId,
    this.reviewId,
  });

  factory CollabDiscoveryRouteArgs.fromNotificationPayload(
    Map<String, dynamic> payload,
  ) => CollabDiscoveryRouteArgs(
    initialListingId: _normalized(payload['listingId']),
    action: _normalized(payload['action'])?.toUpperCase(),
    applicationId: _normalized(payload['applicationId']),
    jobId: _normalized(payload['jobId']),
    reviewId: _normalized(payload['reviewId']),
  );

  final String? initialListingId;
  final String? action;
  final String? applicationId;
  final String? jobId;
  final String? reviewId;

  CollabDeepLinkTarget get target {
    final normalizedAction = action?.trim().toUpperCase() ?? '';
    // A reporter is not necessarily the listing owner or an applicant. Once
    // moderation removes the listing, its private closed detail may correctly
    // return 404 for that reporter; keep this notification on an accessible
    // Collab surface instead of creating a dead-end deep link.
    if (normalizedAction == 'REPORT_RESOLVED') {
      return CollabDeepLinkTarget.discovery;
    }
    if ((reviewId?.isNotEmpty ?? false) ||
        normalizedAction == 'REVIEW_RECEIVED') {
      return CollabDeepLinkTarget.reviews;
    }
    if (normalizedAction == 'APPLICATION_RECEIVED' ||
        normalizedAction == 'APPLICATION_WITHDRAWN') {
      return initialListingId?.isNotEmpty == true
          ? CollabDeepLinkTarget.incomingApplications
          : CollabDeepLinkTarget.discovery;
    }
    if ((jobId?.isNotEmpty ?? false) || normalizedAction.startsWith('JOB_')) {
      return CollabDeepLinkTarget.jobs;
    }
    if ((applicationId?.isNotEmpty ?? false) ||
        normalizedAction.startsWith('APPLICATION_')) {
      return CollabDeepLinkTarget.myApplications;
    }
    if (initialListingId?.isNotEmpty == true) {
      return CollabDeepLinkTarget.listing;
    }
    return CollabDeepLinkTarget.discovery;
  }

  String get signature => <String?>[
    target.name,
    initialListingId,
    action,
    applicationId,
    jobId,
    reviewId,
  ].join('|');

  static String? _normalized(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
