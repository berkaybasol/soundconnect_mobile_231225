import '../../domain/entities/profile_media.dart';
import 'media_asset_model.dart';
import 'track_model.dart';

class ProfileMediaModel extends ProfileMedia {
  const ProfileMediaModel({
    required super.featuredVideo,
    required super.videos,
    required super.audios,
  });

  factory ProfileMediaModel.fromJson(Map<String, dynamic> json) {
    final featuredJson = json['featuredVideo'];
    final videosJson = json['videos'];
    final audiosJson = json['audios'];

    return ProfileMediaModel(
      featuredVideo: featuredJson is Map<String, dynamic>
          ? MediaAssetModel.fromJson(featuredJson)
          : null,
      videos: _parseMediaList(videosJson),
      audios: _parseTrackList(audiosJson),
    );
  }

  static List<MediaAssetModel> _parseMediaList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(MediaAssetModel.fromJson)
        .toList();
  }

  static List<TrackModel> _parseTrackList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(TrackModel.fromJson)
        .toList();
  }
}
