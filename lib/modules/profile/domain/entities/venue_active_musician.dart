class VenueActiveMusician {
  final String musicianProfileId;
  final String bandId;
  final String displayName;
  final String? profileImageUrl;

  const VenueActiveMusician({
    required this.musicianProfileId,
    this.bandId = '',
    required this.displayName,
    required this.profileImageUrl,
  });
}
