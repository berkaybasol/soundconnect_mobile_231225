import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/studio_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_page.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_room.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_room_repository.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';

void main() {
  late _MediaRepository mediaRepository;

  setUp(() async {
    await serviceLocator.reset();
    mediaRepository = _MediaRepository();
    serviceLocator.registerSingleton<ProfileMediaUploadRepository>(
      mediaRepository,
    );
    serviceLocator.registerSingleton<StudioRoomRepository>(_RoomRepository());
  });

  tearDown(() async => serviceLocator.reset());

  testWidgets('room photo snackbar undo restores the original photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: StudioManagementPanelScreen(profile: _profile),
      ),
    );
    await tester.tap(find.text('Odalar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oda Ayarları'));
    await tester.pumpAndSettle();

    final photo = find.byWidgetPredicate(
      (widget) =>
          widget is AppCachedNetworkImage && widget.imageUrl == _photo.url,
    );
    expect(photo, findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget);

    await tester.tap(find.byTooltip('Fotoğrafı kaldır'));
    await tester.pumpAndSettle();

    expect(photo, findsNothing);
    expect(find.text('0 / 10'), findsOneWidget);
    expect(find.text('Fotoğraf kaldırıldı.'), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 4),
    );
    final undo = find.descendant(
      of: find.byType(SnackBar),
      matching: find.text('Geri Al'),
    );
    await tester.tap(undo);
    await tester.pumpAndSettle();

    expect(photo, findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(photo, findsOneWidget);
    expect(mediaRepository.deletedAssetIds, isEmpty);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

const _profile = StudioProfile(
  id: 'studio-1',
  userId: 'user-1',
  name: 'Test Stüdyo',
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
  activeRoomCount: 1,
  backlineUnitCount: 0,
);

const _photo = StudioRoomPhoto(
  mediaAssetId: 'photo-1',
  // The fallback image keeps this action test independent of network/cache IO.
  url: 'test-room-photo',
  orderIndex: 0,
);

final _room = StudioRoom(
  id: 'room-1',
  studioProfileId: _profile.id,
  slotIndex: 0,
  name: 'Prova Odası',
  shortDescription: '',
  capacity: 6,
  hourlyPriceMinor: null,
  currency: null,
  reservationApprovalRequired: true,
  features: [],
  photos: [_photo],
  todayLocalDate: DateTime(2026, 7, 24),
  todayReservationCount: 0,
  todayOccupiedHours: 0,
  todayAvailableHours: 14,
  todayAvailabilityStatus: StudioRoomAvailabilityStatus.available,
  version: 0,
);

class _RoomRepository implements StudioRoomRepository {
  @override
  Future<Result<StudioPage<StudioRoom>>> listOwnerRooms({
    int page = 0,
    int size = 10,
  }) async => Result.success(
    StudioPage<StudioRoom>(
      items: [_room],
      pageIndex: 0,
      pageSize: 10,
      totalItems: 1,
      totalPages: 1,
      isFirst: true,
      isLast: true,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MediaRepository implements ProfileMediaUploadRepository {
  final deletedAssetIds = <String>[];

  @override
  Future<Result<void>> deleteOwnedAsset({
    required String assetId,
    required String ownerType,
    required String ownerId,
  }) async {
    deletedAssetIds.add(assetId);
    return const Result.success(null);
  }

  @override
  void releaseDraftCleanupLeases(Iterable<String> assetIds) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
