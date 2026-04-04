class MusicianSearchOption {
  final String profileId;
  final String displayName;
  final String? secondaryLabel;
  final String? profilePictureUrl;

  const MusicianSearchOption({
    required this.profileId,
    required this.displayName,
    required this.secondaryLabel,
    required this.profilePictureUrl,
  });

  factory MusicianSearchOption.fromJson(Map<String, dynamic> json) {
    final username = json['username']?.toString().trim();
    final stageName = json['stageName']?.toString().trim();
    final displayName = (stageName != null && stageName.isNotEmpty)
        ? stageName
        : (username != null && username.isNotEmpty ? username : 'Sanatci');
    final secondaryLabel =
        (username != null && username.isNotEmpty && username != displayName)
        ? '@$username'
        : null;

    return MusicianSearchOption(
      profileId: json['profileId']?.toString() ?? '',
      displayName: displayName,
      secondaryLabel: secondaryLabel,
      profilePictureUrl: json['profilePictureUrl']?.toString(),
    );
  }
}
