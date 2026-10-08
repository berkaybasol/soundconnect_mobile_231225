import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_direct_open.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/backline_catalog.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_equipment.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_room.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_page.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/backline_catalog_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_equipment_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_room_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/studio_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/studio_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/studio_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/venue_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_public_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_listener_info_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_public_profile_screen.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_connection_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_action_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_count_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_media.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/musician_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/profile_media_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_public_profile_screen.dart';

import 'support/event_audience_fakes.dart';

import 'dart:async';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_user_profile_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_user_profile_resolver_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/custom_notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/follow_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/custom_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/band_follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/domain/spotify_repository.dart';
import 'support/recording_api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/venue_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/artist_venue_application.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_application_page.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_management_panel_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/band_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_received_invitation.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_invite_decision_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/my_bands_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_owner_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_venue_models.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_search_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_directory_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_profile_screen.dart';

part 'follow_notification_open_test_register_follow_notification_open1.dart';
part 'follow_notification_open_test_register_follow_notification_open2.dart';
part 'follow_notification_open_test_cases.dart';
part 'follow_notification_owner_profile_cases.dart';

const recipient = '10000000-0000-0000-0000-000000000001';

const follower = '20000000-0000-0000-0000-000000000001';

const profileId = '30000000-0000-0000-0000-000000000001';

const bandId = '40000000-0000-0000-0000-000000000001';

const notificationId = '50000000-0000-0000-0000-000000000001';

const siblingId = '50000000-0000-0000-0000-000000000002';

const fail = AppError(
  code: 'unavailable',
  message: 'Fixture temporarily unavailable',
);

void main() {
  _FollowNotificationOpenCases().register();
}

const _wrongProfile = MusicianProfile(
  id: bandId,
  userId: follower,
  username: 'public-artist',
  stageName: null,
  bio: 'Public musician biography.',
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

const _profile = MusicianProfile(
  id: profileId,
  userId: follower,
  username: 'public-artist',
  stageName: null,
  bio: 'Public musician biography.',
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

class _ProfileRepository extends Fake implements MusicianProfileRepository {
  final requestedIds = <String>[];
  Completer<Result<MusicianProfile>>? pending;
  bool failure = false, wrong = false;

  @override
  Future<Result<MusicianProfile>> getMyProfile() async => const Result.success(
    MusicianProfile(
      id: '40000000-0000-4000-8000-000000000001',
      userId: recipient,
      username: 'recipient-artist',
      stageName: null,
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
    ),
  );

  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async {
    requestedIds.add(profileId);
    if (pending != null) return pending!.future;
    if (failure) return const Result.failure(fail);
    if (wrong) return Result.success(_wrongProfile);
    return const Result.success(_profile);
  }
}

class _MediaRepository extends Fake implements ProfileMediaRepository {
  @override
  Future<Result<ProfileMedia>> getProfileMedia({
    required String profileType,
    required String profileId,
  }) async => const Result.success(
    ProfileMedia(featuredVideo: null, videos: [], audios: []),
  );
}

class _ConnectionRepository extends Fake
    implements ArtistVenueConnectionRepository {
  @override
  Future<Result<List<VenueConnection>>> getVenueConnectionsByStatus(
    String musicianProfileId, {
    required String status,
  }) async => const Result.success([]);
  List<ArtistVenueApplication> items = [];
  int pageReads = 0;
  ArtistVenueApplicationTarget? target;
  String? targetId, sessionKey;
  bool? incoming;
  @override
  Future<Result<ArtistVenueApplicationPage>> listApplicationPage({
    required ArtistVenueApplicationTarget target,
    required String targetId,
    required bool incoming,
    bool connectionsOnly = false,
    int page = 0,
    int size = 20,
    String? expectedSessionKey,
  }) async {
    pageReads++;
    this.target = target;
    this.targetId = targetId;
    this.incoming = incoming;
    sessionKey = expectedSessionKey;
    return Result.success(
      ArtistVenueApplicationPage(
        items: items,
        page: page,
        size: size,
        totalElements: items.length,
        totalPages: items.isEmpty ? 0 : 1,
        last: true,
      ),
    );
  }
}

class _FollowRepository extends Fake implements FollowRepository {
  @override
  Future<Result<int>> getFollowersCount(String userId) async =>
      const Result.success(0);

  @override
  Future<Result<int>> getFollowingCount(String userId) async =>
      const Result.success(0);

  @override
  Future<Result<bool>> isFollowing({
    required String followerId,
    required String followingId,
  }) async => const Result.success(false);
}

class _EngagementRepository extends Fake implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));
}

class _BadgeCubit extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _BadgeCubit() : super(const DmBadgeState.initial());

  @override
  Future<void> ensureStarted() async {}

  @override
  Future<void> reconcileAfterResume() async {}

  @override
  Future<void> reconcileAfterRead() async {}

  @override
  Future<void> stop() async {}
}

AppNotification _item(String id, {bool band = false}) => AppNotification(
  id: id,
  recipientId: recipient,
  type: band ? 'SOCIAL_NEW_BAND_FOLLOWER' : 'SOCIAL_NEW_FOLLOWER',
  title: id == notificationId ? 'Target fixture' : 'Sibling fixture',
  message: 'Fixture',
  read: false,
  createdAt: DateTime.utc(2026, 9, 28),
  payload: {
    'action': band ? 'NEW_BAND_FOLLOWER' : 'NEW_FOLLOWER',
    'followerId': follower,
    if (band) 'bandId': bandId,
  },
);

class _Repository extends Fake implements NotificationRepository {
  List<AppNotification> items = [_item(notificationId), _item(siblingId)];
  final readIds = <String>[];
  bool failRead = false;
  Completer<Result<void>>? pendingRead;

  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async => Result.success(Page(items: items, hasNext: false));

  @override
  Future<Result<int>> getUnreadCount() async =>
      Result.success(items.where((item) => !item.read).length);

  @override
  Future<Result<void>> markAsRead({required String notificationId}) async {
    readIds.add(notificationId);
    final result =
        await (pendingRead?.future ??
            Future.value(
              failRead
                  ? const Result<void>.failure(
                      AppError(code: 'unavailable', message: 'ACK unavailable'),
                    )
                  : const Result<void>.success(null),
            ));
    if (result.isSuccess) {
      items = items
          .map(
            (item) =>
                item.id == notificationId ? item.copyWith(read: true) : item,
          )
          .toList();
    }
    return result;
  }
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => null;
}

class _Realtime extends NotificationRealtimeClient {
  @override
  Stream<AppNotification> get notificationStream => const Stream.empty();
  @override
  Stream<int> get badgeStream => const Stream.empty();
  @override
  Stream<void> get connectionStream => const Stream.empty();
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({required String userId, required String token}) async {}
  @override
  Future<void> disconnect() async {}
}

const _band = BandProfile(
  id: bandId,
  name: 'Fresh band',
  description: 'Current band',
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundCloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  members: [],
);

const _bandInvitationId = '60000000-0000-0000-0000-000000000001';

class _Bands extends Fake implements BandRepository {
  BandProfile? ownerProfile;
  Completer<Result<BandProfile>>? ownerPending;
  String currentInvitationId = _bandInvitationId;
  final decisionIds = <String?>[];
  bool activeAgain = false;
  Completer<Result<List<BandSummary>>>? pendingMyBands;
  @override
  Future<Result<BandReceivedInvitation>> getCurrentReceivedInvitation({
    required String bandId,
    required String expectedSessionKey,
  }) async => Result.success(
    BandReceivedInvitation(
      bandId: bandId,
      bandName: 'Fresh band',
      invitationId: currentInvitationId,
    ),
  );
  @override
  Future<Result<void>> rejectInvite({
    required String bandId,
    String? expectedSessionKey,
    String? invitationId,
  }) async {
    decisionIds.add(invitationId);
    return const Result.success(null);
  }

  @override
  Future<Result<List<BandSummary>>> getMyBands() async =>
      pendingMyBands?.future ??
      (failure ? const Result.failure(fail) : const Result.success([]));
  @override
  Future<Result<BandReceivedInvitationPage>> getReceivedInvitations({
    int page = 0,
    int size = 20,
    required String expectedSessionKey,
  }) async => Result.success(
    BandReceivedInvitationPage(
      items: const [],
      page: page,
      size: size,
      totalElements: 0,
      hasNext: false,
    ),
  );
  int ownerGets = 0, publicGets = 0;
  bool failure = false;
  Completer<Result<BandProfile>>? pending;
  @override
  Future<Result<BandProfile>> getBandById(String id) async {
    ownerGets++;
    if (ownerPending != null) return ownerPending!.future;
    if (ownerProfile != null) return Result.success(ownerProfile!);
    return const Result.failure(fail);
  }

  @override
  Future<Result<BandProfile>> getPublicBandById(String id) async {
    publicGets++;
    return pending?.future ??
        (failure ? const Result.failure(fail) : const Result.success(_band));
  }
}

class _BandFollow extends Fake implements BandFollowRepository {
  @override
  Future<Result<int>> getFollowersCount(String id) async =>
      const Result.success(0);
  @override
  Future<Result<bool>> isFollowingBand(String id) async =>
      const Result.success(false);
}

class _Spotify extends Fake implements SpotifyRepository {}

class _Listeners extends Fake implements ListenerProfileRepository {
  _Listeners({required this.ghost});
  final bool ghost;
  int gets = 0;
  @override
  Future<Result<ListenerPublicProfile>> getPublicProfile(String id) async {
    gets++;
    return Result.success(
      ListenerPublicProfile(
        id: id,
        userId: follower,
        username: ghost ? 'Ghost listener' : 'Public listener',
        visibilityMode: ghost
            ? ListenerVisibilityMode.ghost
            : ListenerVisibilityMode.standard,
        bio: null,
        profilePictureMediaId: null,
        profilePictureUrl: null,
        followerCount: ghost ? null : 0,
        followingCount: ghost ? null : 0,
        restricted: ghost,
        canFollow: !ghost,
        canMessage: !ghost,
      ),
    );
  }
}

class _Venues extends Fake implements VenueProfileRepository {
  int gets = 0;
  @override
  Future<Result<VenuePublicProfile>> getPublicVenueProfile({
    String? venueId,
  }) async {
    gets++;
    return Result.success(
      VenuePublicProfile(
        venueProfileId: bandId,
        venueId: venueId!,
        ownerUserId: follower,
        venueName: 'Public venue',
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
      ),
    );
  }
}

class _Studios extends Fake implements StudioProfileRepository {
  int gets = 0;
  @override
  Future<Result<StudioProfile>> getPublicProfile(String id) async {
    gets++;
    return Result.success(
      StudioProfile(
        id: id,
        userId: follower,
        name: 'Public studio',
        description: null,
        profilePictureMediaId: null,
        profilePictureUrl: null,
        address: null,
        phone: null,
        website: null,
        facilities: [],
        instagramUrl: null,
        youtubeUrl: null,
        timeZone: 'Europe/Istanbul',
        version: 0,
        spotifyTrackIds: [],
        spotifyTracks: [],
        activeRoomCount: 0,
        backlineUnitCount: 0,
      ),
    );
  }
}

StudioPage<T> _emptyPage<T>() => StudioPage(
  items: [],
  pageIndex: 0,
  pageSize: 20,
  totalItems: 0,
  totalPages: 0,
  isFirst: true,
  isLast: true,
);

class _Rooms extends Fake implements StudioRoomRepository {
  @override
  Future<Result<StudioPage<StudioRoom>>> listOwnerRooms({
    int page = 0,
    int size = 10,
  }) async => Result.success(_emptyPage());

  @override
  Future<Result<StudioPage<StudioRoom>>> listPublicRooms(
    String id, {
    int page = 0,
    int size = 10,
  }) async => Result.success(_emptyPage());
}

class _Equipment extends Fake implements StudioEquipmentRepository {
  @override
  Future<Result<StudioPage<StudioEquipment>>> listOwnerEquipment({
    String? query,
    String? categoryId,
    StudioEquipmentAvailabilityBucket? availabilityBucket,
    required int page,
    required int size,
  }) async => Result.success(_emptyPage());

  @override
  Future<Result<StudioPage<StudioEquipment>>> listPublicEquipment({
    required String studioProfileId,
    String? query,
    String? categoryId,
    StudioEquipmentAvailabilityBucket? availabilityBucket,
    required int page,
    required int size,
  }) async => Result.success(_emptyPage());
}

class _Catalog extends Fake implements BacklineCatalogRepository {
  @override
  Future<Result<StudioPage<BacklineCatalogCategory>>> listCatalog({
    required int page,
    required int size,
  }) async => Result.success(_emptyPage());
}
