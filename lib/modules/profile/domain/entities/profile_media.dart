import 'media_asset.dart';
import 'track.dart';

class ProfileMedia {
  final MediaAsset? featuredVideo;
  final List<MediaAsset> videos;
  final List<Track> audios;

  const ProfileMedia({
    required this.featuredVideo,
    required this.videos,
    required this.audios,
  });
}
