import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_action_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_count_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_media.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/studio_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/studio_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/profile_media_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/studio_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/backline_catalog.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_equipment.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_room.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_reservation.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_page.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/backline_catalog_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_equipment_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_room_repository.dart';

const studioTargetReservationId = '90000000-0000-4000-8000-000000000001';
const studioTargetRoomId = '90000000-0000-4000-8000-000000000002';
const studioTargetProfileId = '90000000-0000-4000-8000-000000000003';
const studioTargetOwnerId = '70000000-0000-4000-8000-000000000002';
const studioTargetCustomerId = '70000000-0000-4000-8000-000000000001';

StudioTargetProfiles registerStudioTargetProfileSurface() {
  final studios = StudioTargetProfiles();
  final badge = _BadgeCubit();
  final follows = _FollowRepository();
  serviceLocator
    ..registerSingleton<StudioProfileRepository>(studios)
    ..registerSingleton<StudioRoomRepository>(StudioTargetRooms())
    ..registerSingleton<StudioEquipmentRepository>(_Equipment())
    ..registerSingleton<BacklineCatalogRepository>(_Catalog())
    ..registerSingleton<AudioHandler>(BaseAudioHandler())
    ..registerSingleton<DmBadgeCubit>(badge)
    ..registerFactory<StudioProfileCubit>(() => StudioProfileCubit(studios))
    ..registerFactory<ProfileMediaCubit>(
      () => ProfileMediaCubit(_MediaRepository()),
    )
    ..registerFactory<FollowCountCubit>(() => FollowCountCubit(follows))
    ..registerFactory<FollowActionCubit>(() => FollowActionCubit(follows))
    ..registerFactory<InteractionStatsCubit>(
      () => InteractionStatsCubit(_EngagementRepository()),
    );
  addTearDown(badge.close);
  return studios;
}

class StudioTargetRooms extends Fake implements StudioRoomRepository {
  DateTime today = DateTime(2026, 9, 28);
  StudioReservationStatus status = StudioReservationStatus.cancelledByCustomer;
  String reservationId = studioTargetReservationId;
  Completer<Result<StudioRoom>>? roomPending;
  final roomIds = <String>[],
      customerDates = <DateTime>[],
      ownerDates = <DateTime>[];
  StudioRoom get room => StudioRoom(
    id: studioTargetRoomId,
    studioProfileId: studioTargetProfileId,
    slotIndex: 2,
    name: 'Current verified room',
    shortDescription: '',
    capacity: 3,
    hourlyPriceMinor: 10000,
    currency: 'TRY',
    reservationApprovalRequired: true,
    features: const [],
    photos: const [],
    todayLocalDate: today,
    todayReservationCount: 1,
    todayOccupiedHours: 1,
    todayAvailableHours: 13,
    todayAvailabilityStatus: StudioRoomAvailabilityStatus.partiallyAvailable,
    version: 1,
  );
  StudioReservation get reservation => StudioReservation(
    id: reservationId,
    clientRequestId: studioTargetReservationId,
    roomId: studioTargetRoomId,
    studioProfileId: studioTargetProfileId,
    roomName: 'Current verified room',
    requesterId: studioTargetCustomerId,
    requesterUsername: 'Reservation customer',
    startsAt: DateTime.utc(2026, 9, 28, 12),
    endsAt: DateTime.utc(2026, 9, 28, 13),
    zoneId: 'Europe/Istanbul',
    status: status,
    completed: today.isAfter(DateTime(2026, 9, 28)),
    approvalRequired: true,
    hourlyPriceMinor: 10000,
    totalPriceMinor: 10000,
    currency: 'TRY',
    version: 1,
    localDate: '2026-09-28',
    localStartTime: '15:00',
    localEndTime: '16:00',
  );
  @override
  Future<Result<StudioRoom>> getOwnerRoom(String id) async {
    roomIds.add(id);
    return roomPending?.future ?? Result.success(room);
  }

  @override
  Future<Result<StudioRoom>> getPublicRoom(String profileId, String id) async {
    expect(profileId, studioTargetProfileId);
    roomIds.add(id);
    return roomPending?.future ?? Result.success(room);
  }

  @override
  Future<Result<StudioRoomAvailability>> getPublicAvailability({
    required String studioProfileId,
    required String roomId,
    required DateTime from,
    required DateTime to,
  }) async => Result.success(
    StudioRoomAvailability(
      studioProfileId: studioProfileId,
      roomId: roomId,
      zoneId: 'Europe/Istanbul',
      openingHour: 9,
      closingHour: 23,
      todayLocalDate: today,
      currentLocalTime: '09:00',
      latestBookableLocalDateTime: today.add(const Duration(days: 365)),
      from: from,
      to: to,
      unavailable: const [],
    ),
  );
  @override
  Future<Result<StudioPage<StudioReservation>>>
  listCustomerReservationsForRoomDate({
    required String roomId,
    required DateTime date,
    int page = 0,
    int size = 100,
  }) async {
    expect(roomId, studioTargetRoomId);
    customerDates.add(date);
    return Result.success(
      _page(date == DateTime(2026, 9, 28) ? [reservation] : []),
    );
  }

  @override
  Future<Result<StudioRoomSchedule>> getOwnerSchedule({
    required String roomId,
    required DateTime from,
    required DateTime to,
    int page = 0,
    int size = 100,
  }) async {
    expect(roomId, studioTargetRoomId);
    ownerDates.add(from);
    return Result.success(
      StudioRoomSchedule(
        room: room,
        zoneId: 'Europe/Istanbul',
        todayLocalDate: today,
        currentLocalTime: '09:00',
        latestBookableLocalDateTime: today.add(const Duration(days: 365)),
        from: from,
        to: to,
        reservations: _page([reservation]),
        occupancies: const [],
      ),
    );
  }

  @override
  Future<Result<StudioPage<StudioRoom>>> listPublicRooms(
    String id, {
    int page = 0,
    int size = 10,
  }) async => Result.success(_emptyPage());

  StudioPage<StudioReservation> _page(List<StudioReservation> items) =>
      StudioPage(
        items: items,
        pageIndex: 0,
        pageSize: 100,
        totalItems: items.length,
        totalPages: 1,
        isFirst: true,
        isLast: true,
      );
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
  Future<void> stop() async {}
}

class StudioTargetProfiles extends Fake implements StudioProfileRepository {
  int gets = 0;
  final profileIds = <String>[];
  @override
  Future<Result<StudioProfile>> getPublicProfile(String id) async {
    gets++;
    profileIds.add(id);
    return Result.success(
      StudioProfile(
        id: id,
        userId: studioTargetOwnerId,
        name: 'Current verified studio',
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

class _Equipment extends Fake implements StudioEquipmentRepository {
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
