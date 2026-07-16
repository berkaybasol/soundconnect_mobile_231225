import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/band_member_summary_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/band_summary_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/listener_profile_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/media_asset_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/musician_profile_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/profile_media_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/track_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_media.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/profile_media_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/profile_media_state.dart';

void main() {
  group('profile data models', () {
    test('musician profile filters unusable venue connections and bands', () {
      final model = MusicianProfileModel.fromJson(<String, dynamic>{
        'id': 'profile-1',
        'userId': 'user-1',
        'username': 'ada',
        'profilePicture': 'fallback.jpg',
        'instruments': <Object?>['guitar', 7],
        'activeVenues': <Object?>['venue-a'],
        'activeVenueConnections': <Object?>[
          <String, dynamic>{
            'venueId': 'venue-a',
            'venueName': 'Hall A',
            'venueProfilePictureUrl': 'hall.jpg',
          },
          <String, dynamic>{'venueId': '', 'venueName': 'Missing id'},
          <String, dynamic>{'venueId': 'venue-b', 'venueName': ''},
          'ignored',
        ],
        'bands': <Object?>[
          <String, dynamic>{'name': 'The Waves'},
          <String, dynamic>{'name': ''},
          'Solo Project',
          null,
        ],
      });

      expect(model.profilePicture, 'fallback.jpg');
      expect(model.instruments, <String>['guitar', '7']);
      expect(model.activeVenueConnections, hasLength(1));
      expect(model.activeVenueConnections.single.requestId, 'venue-a');
      expect(model.activeVenueConnections.single.profileImageUrl, 'hall.jpg');
      expect(model.bands, <String>['The Waves', 'Solo Project']);
    });

    test('band member resolves nested profile id and structured image URL', () {
      final model = BandMemberSummaryModel.fromJson(<String, dynamic>{
        'userId': 'user-4',
        'profileId': ' ',
        'musicianProfile': <String, dynamic>{
          'id': 'profile-4',
          'profilePicture': <String, dynamic>{
            'url': ' ',
            'src': ' avatar.jpg ',
          },
        },
        'username': 'deniz',
        'role': 'MEMBER',
        'status': 'ACTIVE',
      });

      expect(model.profileId, 'profile-4');
      expect(model.profilePictureUrl, 'avatar.jpg');
    });

    test(
      'media models accept aliases, numeric boundaries, and bad list rows',
      () {
        final asset = MediaAssetModel.fromJson(<String, dynamic>{
          'uuid': 77,
          'durationSeconds': 42.9,
        });
        final track = TrackModel.fromJson(<String, dynamic>{
          'id': 9,
          'durationSeconds': 180.8,
          'bpm': 119.7,
        });
        final media = ProfileMediaModel.fromJson(<String, dynamic>{
          'featuredVideo': <String, dynamic>{'id': 'featured'},
          'videos': <Object?>[
            <String, dynamic>{'id': 'video-1'},
            'ignored',
          ],
          'audios': <Object?>[
            <String, dynamic>{'id': 'audio-1', 'title': 'Track'},
            3,
          ],
        });

        expect(asset.id, '77');
        expect(asset.durationSeconds, 42);
        expect(track.id, '9');
        expect(track.mediaAssetId, '9');
        expect(track.durationSeconds, 180);
        expect(track.bpm, 119);
        expect(media.featuredVideo?.id, 'featured');
        expect(media.videos.map((item) => item.id), <String>['video-1']);
        expect(media.audios.map((item) => item.id), <String>['audio-1']);
      },
    );

    test('simple profile models provide stable defaults and aliases', () {
      final listener = ListenerProfileModel.fromJson(<String, dynamic>{
        'id': 3,
        'followerCount': 12.8,
      });
      final band = BandSummaryModel.fromJson(<String, dynamic>{
        'id': 'band-1',
        'name': '  Echoes  ',
        'profilePicture': 'band.jpg',
      });

      expect(listener.id, '3');
      expect(listener.userId, isEmpty);
      expect(listener.followerCount, 12);
      expect(listener.followingCount, 0);
      expect(band.name, 'Echoes');
      expect(band.profilePictureUrl, 'band.jpg');
    });
  });

  group('ProfileMediaCubit', () {
    test('emits success with data and forwards repository arguments', () async {
      const media = ProfileMedia(
        featuredVideo: null,
        videos: <MediaAssetModel>[],
        audios: <TrackModel>[],
      );
      final repository = _ProfileMediaRepositoryFake(
        response: const Result.success(media),
      );
      final cubit = ProfileMediaCubit(repository);
      addTearDown(cubit.close);

      await cubit.loadMedia(profileType: 'MUSICIAN', profileId: 'profile-7');

      expect(cubit.state.status, ProfileMediaStatus.success);
      expect(cubit.state.media, same(media));
      expect(repository.lastProfileType, 'MUSICIAN');
      expect(repository.lastProfileId, 'profile-7');
    });

    test('replaces a prior success with the typed failure', () async {
      const media = ProfileMedia(
        featuredVideo: null,
        videos: <MediaAssetModel>[],
        audios: <TrackModel>[],
      );
      const error = AppError(code: 'offline', message: 'Offline');
      final repository = _ProfileMediaRepositoryFake(
        response: const Result.success(media),
      );
      final cubit = ProfileMediaCubit(repository);
      addTearDown(cubit.close);
      await cubit.loadMedia(profileType: 'BAND', profileId: 'band-1');

      repository.response = const Result.failure(error);
      await cubit.loadMedia(profileType: 'BAND', profileId: 'band-1');

      expect(cubit.state.status, ProfileMediaStatus.failure);
      expect(cubit.state.error, same(error));
      expect(cubit.state.media, same(media));
    });
  });
}

class _ProfileMediaRepositoryFake implements ProfileMediaRepository {
  _ProfileMediaRepositoryFake({required this.response});

  Result<ProfileMedia> response;
  String? lastProfileType;
  String? lastProfileId;

  @override
  Future<Result<ProfileMedia>> getProfileMedia({
    required String profileType,
    required String profileId,
  }) async {
    lastProfileType = profileType;
    lastProfileId = profileId;
    return response;
  }
}
