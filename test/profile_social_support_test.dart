import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/musician_profile_save_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_social_support.dart';

void main() {
  group('profile social support', () {
    const profile = MusicianProfile(
      id: 'musician-1',
      userId: 'user-1',
      username: 'test-artist',
      stageName: 'Test Artist',
      bio: 'Bio',
      profilePicture: null,
      instruments: [],
      activeVenues: [],
      bands: [],
      soundcloudUrl: 'https://soundcloud.com/test',
      instagramUrl: 'https://instagram.com/test',
      youtubeUrl: 'https://youtube.com/@test',
      spotifyEmbedUrl: 'https://open.spotify.com/artist/test',
      spotifyArtistId: 'artist-1',
      spotifyTrackIds: [],
      spotifyTracks: [],
    );

    test('reads social urls by platform', () {
      expect(
        socialUrlForMusicianProfile(profile, ProfileSocialPlatform.soundcloud),
        profile.soundcloudUrl,
      );
      expect(
        socialUrlForMusicianProfile(profile, ProfileSocialPlatform.instagram),
        profile.instagramUrl,
      );
      expect(
        socialUrlForMusicianProfile(profile, ProfileSocialPlatform.youtube),
        profile.youtubeUrl,
      );
      expect(
        socialUrlForMusicianProfile(profile, ProfileSocialPlatform.spotify),
        profile.spotifyEmbedUrl,
      );
    });

    test('builds musician social request for the selected platform', () {
      const url = 'https://example.com/value';

      final soundcloud = buildMusicianSocialLinkRequest(
        ProfileSocialPlatform.soundcloud,
        url,
      );
      final instagram = buildMusicianSocialLinkRequest(
        ProfileSocialPlatform.instagram,
        url,
      );
      final youtube = buildMusicianSocialLinkRequest(
        ProfileSocialPlatform.youtube,
        url,
      );
      final spotify = buildMusicianSocialLinkRequest(
        ProfileSocialPlatform.spotify,
        url,
      );

      expect(soundcloud, isA<MusicianProfileSaveRequest>());
      expect(soundcloud.soundcloudUrl, url);
      expect(instagram.instagramUrl, url);
      expect(youtube.youtubeUrl, url);
      expect(spotify.spotifyEmbedUrl, url);
    });
  });
}
