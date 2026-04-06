class PublicProfileArgs {
  final String? profileId;
  final String? viewerUserId;

  const PublicProfileArgs({this.profileId, this.viewerUserId});
}

class VenueProfileArgs {
  final String? venueId;
  final String? viewerUserId;

  const VenueProfileArgs({this.venueId, this.viewerUserId});
}

class VenuePublicProfileArgs {
  final String? venueId;
  final String? viewerUserId;

  const VenuePublicProfileArgs({this.venueId, this.viewerUserId});
}
