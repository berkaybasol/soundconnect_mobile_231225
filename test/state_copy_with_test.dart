import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/login_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_media.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_owner_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/musician_profile_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/profile_media_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/venue_profile_state.dart';

void main() {
  group('copyWith nullable reset support', () {
    test('AuthState clears nullable fields explicitly', () {
      final state = AuthState(
        status: AuthStatus.failure,
        action: AuthAction.login,
        message: 'failed',
        error: const AppError(code: '401', message: 'Unauthorized'),
        loginResult: const LoginResult(token: 'token'),
      );

      final next = state.copyWith(
        status: AuthStatus.success,
        message: null,
        error: null,
        loginResult: null,
      );

      expect(next.status, AuthStatus.success);
      expect(next.message, isNull);
      expect(next.error, isNull);
      expect(next.loginResult, isNull);
    });

    test('MusicianProfileState clears profile and error explicitly', () {
      final state = MusicianProfileState(
        status: MusicianProfileStatus.failure,
        action: MusicianProfileAction.load,
        profile: _musicianProfile,
        error: const AppError(code: 'x', message: 'broken'),
      );

      final next = state.copyWith(
        status: MusicianProfileStatus.loading,
        profile: null,
        error: null,
      );

      expect(next.status, MusicianProfileStatus.loading);
      expect(next.profile, isNull);
      expect(next.error, isNull);
    });

    test('ProfileMediaState clears media and error explicitly', () {
      final state = ProfileMediaState(
        status: ProfileMediaStatus.failure,
        media: const ProfileMedia(featuredVideo: null, videos: [], audios: []),
        error: const AppError(code: 'x', message: 'broken'),
      );

      final next = state.copyWith(
        status: ProfileMediaStatus.loading,
        media: null,
        error: null,
      );

      expect(next.status, ProfileMediaStatus.loading);
      expect(next.media, isNull);
      expect(next.error, isNull);
    });

    test(
      'VenueProfileState clears owner/public profile and error explicitly',
      () {
        final state = VenueProfileState(
          status: VenueProfileStatus.failure,
          view: VenueProfileView.owner,
          ownerProfile: _venueOwnerProfile,
          publicProfile: _venuePublicProfile,
          error: const AppError(code: 'x', message: 'broken'),
        );

        final next = state.copyWith(
          status: VenueProfileStatus.loading,
          ownerProfile: null,
          publicProfile: null,
          error: null,
        );

        expect(next.status, VenueProfileStatus.loading);
        expect(next.ownerProfile, isNull);
        expect(next.publicProfile, isNull);
        expect(next.error, isNull);
      },
    );
  });
}

const _musicianProfile = MusicianProfile(
  id: 'profile-1',
  userId: 'user-1',
  username: 'artist',
  stageName: 'Artist',
  bio: null,
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  spotifyTracks: [],
  instruments: [],
  activeVenues: [],
  bands: [],
);

const _venueOwnerProfile = VenueOwnerProfile(
  venueProfileId: 'vp-1',
  venueId: 'venue-1',
  ownerUserId: 'owner-1',
  venueName: 'Venue',
  bio: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  websiteUrl: null,
  address: null,
  phone: null,
  website: null,
  description: null,
  musicStartTime: null,
  cityId: null,
  cityName: null,
  districtId: null,
  districtName: null,
  neighborhoodId: null,
  neighborhoodName: null,
  status: null,
  activeMusicians: [],
  activeBands: [],
  weeklyEvents: [],
);

const _venuePublicProfile = VenuePublicProfile(
  venueProfileId: 'vp-1',
  venueId: 'venue-1',
  ownerUserId: 'owner-1',
  venueName: 'Venue',
  bio: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  websiteUrl: null,
  address: null,
  phone: null,
  website: null,
  description: null,
  musicStartTime: null,
  cityName: null,
  districtName: null,
  neighborhoodName: null,
  activeMusicians: [],
  activeBands: [],
  weeklyEvents: [],
);
