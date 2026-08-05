import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/musician_profile_save_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/studio_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_contact_uri.dart';
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

    test('reads and updates supported studio social links', () {
      const studio = StudioProfile(
        id: 'studio-1',
        userId: 'user-1',
        name: 'test studio',
        description: null,
        profilePictureMediaId: null,
        profilePictureUrl: null,
        address: null,
        phone: null,
        website: null,
        facilities: [],
        instagramUrl: 'https://instagram.com/studio',
        youtubeUrl: 'https://youtube.com/@studio',
        timeZone: 'Europe/Istanbul',
        version: 0,
        spotifyTrackIds: [],
        spotifyTracks: [],
        activeRoomCount: 0,
        backlineUnitCount: 0,
      );
      const url = 'https://example.com/studio';

      expect(
        socialUrlForStudioProfile(studio, ProfileSocialPlatform.instagram),
        studio.instagramUrl,
      );
      expect(
        socialUrlForStudioProfile(studio, ProfileSocialPlatform.youtube),
        studio.youtubeUrl,
      );
      expect(
        buildStudioSocialLinkRequest(
          ProfileSocialPlatform.instagram,
          url,
        ).instagramUrl,
        url,
      );
      expect(
        buildStudioSocialLinkRequest(
          ProfileSocialPlatform.youtube,
          url,
        ).youtubeUrl,
        url,
      );
      expect(
        buildStudioSocialLinkRequest(
          ProfileSocialPlatform.instagram,
          '',
        ).instagramUrl,
        isEmpty,
      );
    });

    testWidgets('Studio social dialog distinguishes remove from cancel', (
      tester,
    ) async {
      String? result = 'not-completed';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await promptForSocialLink(
                  context,
                  platform: ProfileSocialPlatform.instagram,
                  initialValue: 'https://instagram.com/studio',
                  allowRemoval: true,
                );
              },
              child: const Text('Düzenle'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Düzenle'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-social-remove')));
      await tester.pumpAndSettle();

      expect(result, '');
    });

    test('accepts only absolute HTTP(S) launch targets', () {
      expect(profileHttpUri('https://example.com/studio')?.host, 'example.com');
      expect(profileHttpUri('http://example.com'), isNotNull);
      expect(profileHttpUri('javascript:alert(1)'), isNull);
      expect(profileHttpUri('https://'), isNull);
      expect(profileHttpUri('https://user@example.com'), isNull);
      expect(profileHttpUri('www.example.com'), isNull);
      expect(
        normalizeProfileHttpUrl('www.example.com', assumeHttps: true),
        'https://www.example.com',
      );
    });

    test('canonicalizes only safe dialable phone values', () {
      expect(canonicalProfilePhoneDigits('+90 (555) 111-22-33'), '05551112233');
      expect(
        profilePhoneUri('+90 (555) 111-22-33').toString(),
        'tel:05551112233',
      );
      expect(
        profileWhatsAppUri('+90 (555) 111-22-33').toString(),
        'https://wa.me/905551112233',
      );
      expect(canonicalProfilePhoneDigits('555 111 22 33'), '05551112233');
      expect(canonicalProfilePhoneDigits('0555 111 22 33'), '05551112233');
      expect(profilePhoneUri('555;postd=1234'), isNull);
      expect(profilePhoneUri('123'), isNull);
      expect(profilePhoneUri('2125551122'), isNull);
      expect(profilePhoneUri('90555111223'), isNull);
      expect(profileWhatsAppUri('123'), isNull);
    });
  });
}
