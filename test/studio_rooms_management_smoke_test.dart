import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_upload_result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/studio_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_page.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_room.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_room_repository.dart';

import 'support/event_audience_fakes.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    serviceLocator.registerSingleton<ProfileMediaUploadRepository>(
      _ProfileMediaUploadRepositoryFake(),
    );
  });
  tearDown(() async => serviceLocator.reset());

  testWidgets(
    'listener switch hides an already pushed room settings snapshot',
    (tester) async {
      final sessions = _registerSessions();
      var reads = 0;
      serviceLocator.registerSingleton<StudioRoomRepository>(
        _RoomRepositoryFake(() async {
          reads++;
          return Result.success(
            StudioPage<StudioRoom>(
              items: [_scheduledPolicyRoom],
              pageIndex: 0,
              pageSize: 10,
              totalItems: 1,
              totalPages: 1,
              isFirst: true,
              isLast: true,
            ),
          );
        }),
      );
      await _openRooms(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oda Ayarları'));
      await tester.pumpAndSettle();
      expect(find.text('Oda Ayarları'), findsOneWidget);
      // The lazy list starts with tall photo/policy cards; build the actual
      // name input below them before asserting that a cached draft is shown.
      final settingsScroll = find.descendant(
        of: find.byType(Form),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      expect(settingsScroll, findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Oda adı'),
        240,
        scrollable: settingsScroll,
      );
      final nameInput = find.widgetWithText(TextFormField, 'Oda adı');
      expect(nameInput, findsOneWidget);
      expect(
        tester.widget<TextFormField>(nameInput).controller!.text,
        'Planlı Politika Odası',
      );

      final listener = audienceSession();
      sessions.replace(listener);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('studio-listener-info')), findsOneWidget);
      expect(find.byType(TextFormField, skipOffstage: false), findsNothing);
      expect(
        find.text('Planlı Politika Odası', skipOffstage: false),
        findsNothing,
      );
      expect(reads, 1);

      // Each surviving studio route has its own boundary: popping the settings
      // must not reveal the cached rooms list or owner management beneath it.
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(
          find.byKey(const Key('studio-listener-return')),
        );
        await tester.tap(find.byKey(const Key('studio-listener-return')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('studio-listener-info')), findsOneWidget);
        expect(find.text('Oda Yönetimi'), findsNothing);
        expect(find.text('Yönetim Paneli'), findsNothing);
      }
      expect(identical(sessions.session, listener), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('listener switch removes the open studio room creation sheet', (
    tester,
  ) async {
    final sessions = _registerSessions();
    var creates = 0;
    serviceLocator.registerSingleton<StudioRoomRepository>(
      _RoomRepositoryFake(
        () async => Result.success(_emptyPage),
        createRoomCallback: (_, _) async {
          creates++;
          return Result.success(_createdRoom);
        },
      ),
    );
    await _openRooms(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni Oda Oluştur'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Özel oda taslağı',
    );

    sessions.replace(audienceSession());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('studio-listener-info')), findsWidgets);
    expect(find.byType(TextFormField, skipOffstage: false), findsNothing);
    expect(find.text('Özel oda taslağı', skipOffstage: false), findsNothing);
    expect(find.text('Odayı Oluştur'), findsNothing);
    expect(creates, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner room management renders loading then empty state', (
    tester,
  ) async {
    final completer = Completer<Result<StudioPage<StudioRoom>>>();
    serviceLocator.registerSingleton<StudioRoomRepository>(
      _RoomRepositoryFake(() => completer.future),
    );
    await _openRooms(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(Result.success(_emptyPage));
    await tester.pumpAndSettle();

    expect(find.text('Henüz bir oda yok'), findsOneWidget);
    expect(find.text('İlk Odayı Oluştur'), findsOneWidget);
  });

  testWidgets('owner room management exposes retry after a load failure', (
    tester,
  ) async {
    var calls = 0;
    serviceLocator.registerSingleton<StudioRoomRepository>(
      _RoomRepositoryFake(() async {
        calls++;
        if (calls == 1) {
          return const Result.failure(
            AppError(code: 'network', message: 'Bağlantı kurulamadı.'),
          );
        }
        return Result.success(_emptyPage);
      }),
    );
    await _openRooms(tester);
    await tester.pumpAndSettle();

    expect(find.text('Bağlantı kurulamadı.'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);

    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Henüz bir oda yok'), findsOneWidget);
  });

  testWidgets('room create retry reuses one client request id', (tester) async {
    final requestIds = <String>[];
    var createAttempts = 0;
    serviceLocator.registerSingleton<StudioRoomRepository>(
      _RoomRepositoryFake(
        () async => Result.success(_emptyPage),
        createRoomCallback: (draft, clientRequestId) async {
          requestIds.add(clientRequestId);
          createAttempts++;
          if (createAttempts == 1) {
            return const Result.failure(
              AppError(code: 'network', message: 'Geçici bağlantı hatası.'),
            );
          }
          return Result.success(_createdRoom);
        },
      ),
    );
    await _openRooms(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yeni Oda Oluştur'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(0), 'prova odası');
    await tester.enterText(fields.at(2), '6');

    await tester.ensureVisible(find.text('Odayı Oluştur'));
    await tester.tap(find.text('Odayı Oluştur'));
    await tester.pumpAndSettle();
    expect(find.text('Geçici bağlantı hatası.'), findsOneWidget);

    await tester.ensureVisible(find.text('Odayı Oluştur'));
    await tester.tap(find.text('Odayı Oluştur'));
    await tester.pumpAndSettle();

    expect(requestIds, hasLength(2));
    expect(requestIds.first, requestIds.last);
    expect(find.text('Geçici bağlantı hatası.'), findsNothing);
  });

  testWidgets('room creation sends the selected approval policy', (
    tester,
  ) async {
    StudioRoomDraft? submittedDraft;
    serviceLocator.registerSingleton<StudioRoomRepository>(
      _RoomRepositoryFake(
        () async => Result.success(_emptyPage),
        createRoomCallback: (draft, _) async {
          submittedDraft = draft;
          return Result.success(_createdRoom);
        },
      ),
    );
    await _openRooms(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yeni Oda Oluştur'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'anında rezervasyon odası');
    await tester.enterText(fields.at(2), '4');

    final approvalSwitch = find.byKey(
      const Key('studio-room-approval-policy-switch'),
    );
    expect(approvalSwitch, findsOneWidget);
    expect(tester.widget<Switch>(approvalSwitch).value, isTrue);
    await tester.ensureVisible(approvalSwitch);
    await tester.tap(approvalSwitch);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Odayı Oluştur'));
    await tester.tap(find.text('Odayı Oluştur'));
    await tester.pumpAndSettle();

    expect(submittedDraft, isNotNull);
    expect(submittedDraft!.reservationApprovalRequired, isFalse);
  });

  testWidgets('scheduled approval policy label uses the Studio civil date', (
    tester,
  ) async {
    serviceLocator.registerSingleton<StudioRoomRepository>(
      _RoomRepositoryFake(
        () async => Result.success(
          StudioPage<StudioRoom>(
            items: [_scheduledPolicyRoom],
            pageIndex: 0,
            pageSize: 10,
            totalItems: 1,
            totalPages: 1,
            isFirst: true,
            isLast: true,
          ),
        ),
      ),
    );
    await _openRooms(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Oda Ayarları'));
    await tester.pumpAndSettle();

    expect(
      find.text('Planlanan değişiklik 25.07.2026 00:00’da devreye girer.'),
      findsOneWidget,
    );
    expect(find.textContaining('01.01.2035'), findsNothing);
  });
}

AudienceTestSessions _registerSessions() {
  final sessions = AudienceTestSessions(
    audienceSession(role: 'ROLE_STUDIO', user: 'user-1'),
  );
  serviceLocator.registerSingleton<AuthSessionManager>(
    sessions,
    dispose: (value) => value.dispose(),
  );
  serviceLocator.registerSingleton<DmBadgeCubit>(
    _Badge(),
    dispose: (value) => value.close(),
  );
  return sessions;
}

class _Badge extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _Badge() : super(const DmBadgeState.initial());
  @override
  Future<void> ensureStarted() async {}
  @override
  Future<void> stop() async {}
}

Future<void> _openRooms(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: StudioManagementPanelScreen(profile: _profile),
    ),
  );
  await tester.tap(find.text('Odalar'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
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
  activeRoomCount: 0,
  backlineUnitCount: 0,
);

const _emptyPage = StudioPage<StudioRoom>(
  items: [],
  pageIndex: 0,
  pageSize: 10,
  totalItems: 0,
  totalPages: 0,
  isFirst: true,
  isLast: true,
);

final _createdRoom = StudioRoom(
  id: 'room-1',
  studioProfileId: 'studio-1',
  slotIndex: 0,
  name: 'Prova Odası',
  shortDescription: '',
  capacity: 6,
  hourlyPriceMinor: null,
  currency: null,
  reservationApprovalRequired: true,
  features: [],
  photos: [],
  todayLocalDate: DateTime(2026, 7, 24),
  todayReservationCount: 0,
  todayOccupiedHours: 0,
  todayAvailableHours: 14,
  todayAvailabilityStatus: StudioRoomAvailabilityStatus.available,
  version: 0,
);

final _scheduledPolicyRoom = StudioRoom(
  id: 'room-scheduled-policy',
  studioProfileId: 'studio-1',
  slotIndex: 1,
  name: 'Planlı Politika Odası',
  shortDescription: '',
  capacity: 4,
  hourlyPriceMinor: null,
  currency: null,
  reservationApprovalRequired: true,
  pendingReservationApprovalRequired: false,
  // Deliberately unrelated to the Studio civil date: presentation must not
  // derive its calendar label from the device-local projection of this instant.
  reservationApprovalPolicyEffectiveAt: DateTime.utc(2035),
  features: const [],
  photos: const [],
  todayLocalDate: DateTime(2026, 7, 24),
  todayReservationCount: 0,
  todayOccupiedHours: 0,
  todayAvailableHours: 14,
  todayAvailabilityStatus: StudioRoomAvailabilityStatus.available,
  version: 1,
);

class _RoomRepositoryFake implements StudioRoomRepository {
  _RoomRepositoryFake(this._listOwnerRooms, {this.createRoomCallback});

  final Future<Result<StudioPage<StudioRoom>>> Function() _listOwnerRooms;
  final Future<Result<StudioRoom>> Function(
    StudioRoomDraft draft,
    String clientRequestId,
  )?
  createRoomCallback;

  @override
  Future<Result<StudioPage<StudioRoom>>> listOwnerRooms({
    int page = 0,
    int size = 10,
  }) => _listOwnerRooms();

  @override
  Future<Result<StudioRoom>> createRoom(
    StudioRoomDraft draft, {
    required String clientRequestId,
  }) {
    final callback = createRoomCallback;
    if (callback == null) {
      throw StateError('Unexpected createRoom call');
    }
    return callback(draft, clientRequestId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileMediaUploadRepositoryFake
    implements ProfileMediaUploadRepository {
  @override
  Stream<ProfileUploadRecoveryEvent> get recoveryEvents => const Stream.empty();

  @override
  Future<Result<ProfileUploadedMedia>> uploadAsset({
    required ProfileUploadSource source,
    required String ownerType,
    required String ownerId,
    required String mediaKind,
    required String mimeType,
    required String originalFileName,
    String visibility = 'PUBLIC',
    String contentAudience = 'MAINSTAGE',
    ProfileUploadAttachmentIntent attachmentIntent =
        const ProfileUploadAttachmentIntent.none(),
    ProfileUploadProgress? onProgress,
    ProfileUploadStageChanged? onStageChanged,
    ProfileUploadCancellation? cancellation,
  }) async => const Result.failure(
    AppError(code: 'test_upload_disabled', message: 'Upload is disabled.'),
  );

  @override
  Future<Result<void>> deleteOwnedAsset({
    required String assetId,
    required String ownerType,
    required String ownerId,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> persistDraftCleanupIntent({
    required String assetId,
    required String ownerType,
    required String ownerId,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> clearDraftCleanupIntents(
    Iterable<String> assetIds,
  ) async => const Result.success(null);

  @override
  void releaseDraftCleanupLeases(Iterable<String> assetIds) {}

  @override
  Future<void> resumePendingUploads() async {}
}
