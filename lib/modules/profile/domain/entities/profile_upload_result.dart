class ProfilePhotoUploadResult {
  final String assetId;
  final String? sourceUrl;
  final String? playbackUrl;

  const ProfilePhotoUploadResult({
    required this.assetId,
    required this.sourceUrl,
    required this.playbackUrl,
  });

  String? get preferredUrl {
    final source = sourceUrl?.trim();
    if (source != null && source.isNotEmpty) return source;
    final playback = playbackUrl?.trim();
    if (playback != null && playback.isNotEmpty) return playback;
    return null;
  }
}

class ProfileUploadedMedia {
  final String uuid;
  final String? sourceUrl;
  final String? playbackUrl;

  const ProfileUploadedMedia({
    required this.uuid,
    required this.sourceUrl,
    required this.playbackUrl,
  });

  factory ProfileUploadedMedia.fromJson(Map<String, dynamic> json) {
    return ProfileUploadedMedia(
      uuid: json['uuid']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString(),
      playbackUrl: json['playbackUrl']?.toString(),
    );
  }
}

class ProfileUploadInitResult {
  final String assetId;
  final String uploadUrl;

  const ProfileUploadInitResult({
    required this.assetId,
    required this.uploadUrl,
  });

  factory ProfileUploadInitResult.fromJson(Map<String, dynamic> json) {
    return ProfileUploadInitResult(
      assetId: json['assetId']?.toString() ?? '',
      uploadUrl: json['uploadUrl']?.toString() ?? '',
    );
  }
}
