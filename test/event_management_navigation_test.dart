import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/domain/entities/promotion_item.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/domain/promotion_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_calendar.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_performer_request_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_calendar_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_calendar_repository_factory.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_management_panel_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_requests_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_owner_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_management_panel_screen.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    serviceLocator.registerSingleton<PromotionRepository>(_Promotions());
  });
  tearDown(() => serviceLocator.reset());

  testWidgets('musician management has no independent event creation entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const MusicianManagementPanelScreen(musicianProfile: _musician),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Etkinlik Davetleri'), findsNothing);
    expect(find.text('Etkinliklerim'), findsNothing);
    expect(find.text('Bandlerim'), findsOneWidget);
    expect(find.text('Etkinlik Yönetimi'), findsOneWidget);
    expect(find.text('Etkinlik Onayları'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Etkinlik Yönetimi')).dy,
      greaterThan(
        tester.getTopLeft(find.text('Mekan Bağlantılarını Yönet')).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.text('Etkinlik Yönetimi')).dy,
      lessThan(tester.getTopLeft(find.text('Yorumlar ve Geri Bildirimler')).dy),
    );
    expect(
      find.byKey(const Key('musician-calendar-visibility-switch')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final visible in [false, true]) {
    testWidgets(
      'musician management opens invitations regardless of calendar: $visible',
      (tester) async {
        final calendar = _Calendar(visible);
        final invitations = _Invitations();
        serviceLocator
          ..registerSingleton<AuthSessionManager>(_Auth())
          ..registerSingleton<MusicianProfileRepository>(_Profile())
          ..registerSingleton<MusicianCalendarRepository>(calendar)
          ..registerSingleton<EventPerformerRequestRepository>(invitations);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const MusicianManagementPanelScreen(
              musicianProfile: _musician,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Etkinlik Yönetimi'));
        await tester.tap(find.text('Etkinlik Yönetimi'));
        await tester.pumpAndSettle();
        expect(calendar.reads, 0);
        expect(calendar.updates, 0);
        expect(invitations.calls, 0);
        expect(
          find.byKey(const Key('event-management-events')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('event-management-rejected')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('event-management-invitations')));
        await tester.pumpAndSettle();
        expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
        expect(invitations.calls, 1);
        expect(invitations.targetType, EventPerformerTargetType.musician);
        expect(invitations.targetId, _musician.id);
        expect(find.text('Etkinlik Ekle'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'venue event action directly opens editor and propagates change',
    (tester) async {
      var editorCalls = 0;
      var returned = false;
      bool? panelResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  panelResult = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => VenueManagementPanelScreen(
                        ownerProfile: _venue,
                        openWeeklyCalendar: (_) async {
                          editorCalls++;
                          return true;
                        },
                        openConnectedArtists: (_) async {},
                      ),
                    ),
                  );
                  returned = true;
                },
                child: const Text('Yönetimi aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Yönetimi aç'));
      await tester.pumpAndSettle();
      expect(editorCalls, 0);

      await tester.tap(find.text('Etkinlik Yönetimi'));
      await tester.pumpAndSettle();

      expect(editorCalls, 1);
      expect(returned, isTrue);
      expect(panelResult, isTrue);
      expect(find.byType(VenueManagementPanelScreen), findsNothing);
      expect(find.text('Yönetimi aç'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final visible in [false, true]) {
    testWidgets(
      'band management opens invitations regardless of both calendars: $visible',
      (tester) async {
        final bandCalendar = _Calendar(visible);
        final personal = _Calendar(!visible);
        final factory = _BandCalendars(bandCalendar);
        final invitations = _Invitations();
        serviceLocator
          ..registerSingleton<AuthSessionManager>(_Auth())
          ..registerSingleton<BandRepository>(_Bands())
          ..registerSingleton<BandCalendarRepositoryFactory>(factory)
          ..registerSingleton<MusicianCalendarRepository>(personal)
          ..registerSingleton<EventPerformerRequestRepository>(invitations);
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: BandManagementPanelScreen(profile: _band),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('musician-calendar-visibility-switch')),
          findsNothing,
        );
        expect(find.byTooltip('Etkinlik Ayarları'), findsNothing);
        expect(
          tester.getTopLeft(find.text('Etkinlik Yönetimi')).dy,
          greaterThan(
            tester.getTopLeft(find.text('Mekan Bağlantılarını Yönet')).dy,
          ),
        );
        expect(
          tester.getTopLeft(find.text('Etkinlik Yönetimi')).dy,
          lessThan(
            tester.getTopLeft(find.text('Etkileşim ve İstatistikler')).dy,
          ),
        );
        await tester.ensureVisible(find.text('Etkinlik Yönetimi'));
        await tester.tap(find.text('Etkinlik Yönetimi'));
        await tester.pumpAndSettle();
        expect(factory.acquiredId, isNull);
        expect(bandCalendar.reads, 0);
        expect(personal.reads, 0);
        expect(personal.updates, 0);
        expect(bandCalendar.updates, 0);
        expect(invitations.calls, 0);
        await tester.tap(find.byKey(const Key('event-management-invitations')));
        await tester.pumpAndSettle();
        expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
        expect(invitations.calls, 1);
        expect(invitations.targetType, EventPerformerTargetType.band);
        expect(invitations.targetId, _band.id);
        expect(find.text('Etkinlik Ekle'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('unchanged venue editor keeps its management panel open', (
    tester,
  ) async {
    var editorCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VenueManagementPanelScreen(
          ownerProfile: _venue,
          openWeeklyCalendar: (_) async {
            editorCalls++;
            return false;
          },
          openConnectedArtists: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Etkinlik Yönetimi'));
    await tester.pumpAndSettle();

    expect(editorCalls, 1);
    expect(find.byType(VenueManagementPanelScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Bands implements BandRepository {
  @override
  Future<Result<BandProfile>> getBandById(String id) async =>
      const Result.success(_band);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BandCalendars implements BandCalendarRepositoryFactory {
  _BandCalendars(this.repository);
  final MusicianCalendarRepository repository;
  String? acquiredId;
  @override
  MusicianCalendarRepository acquire(String bandId) {
    acquiredId = bandId;
    return repository;
  }

  @override
  Future<void> release(String bandId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthSessionManager {
  @override
  AuthSession get session => AuthSession.authenticated(
    token: 'test-token',
    userId: _musician.userId,
    username: _musician.username,
    accountStatus: 'ACTIVE',
    roles: ['ROLE_MUSICIAN'],
    permissions: [],
    expiresAt: DateTime(2100),
    isAdmin: false,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profile implements MusicianProfileRepository {
  @override
  Future<Result<MusicianProfile>> getMyProfile() async =>
      const Result.success(_musician);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Calendar implements MusicianCalendarRepository {
  _Calendar(this.visible);
  @override
  void invalidate() {}
  final bool visible;
  int reads = 0, updates = 0;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<Result<MusicianCalendarSettings>> getSettings() async {
    reads++;
    return Result.success(
      MusicianCalendarSettings(visible: visible, version: 0),
    );
  }

  @override
  Future<Result<MusicianCalendarSettings>> updateSettings({
    required bool visible,
    required int version,
  }) async {
    updates++;
    return Result.success(
      MusicianCalendarSettings(visible: visible, version: version + 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Invitations implements EventPerformerRequestRepository {
  @override
  Future<Result<void>> reconsider(
    String requestId, {
    required bool showOnProfile,
  }) => throw UnimplementedError(
    'Unexpected reconsideration in navigation test.',
  );

  int calls = 0;
  EventPerformerTargetType? targetType;
  String? targetId;
  @override
  Future<Result<EventPerformerRequestPage>> listMine({
    EventPerformerRequestStatus status = EventPerformerRequestStatus.pending,
    int page = 0,
    int size = 20,
    EventPerformerTargetType? targetType,
    String? targetId,
  }) async {
    calls++;
    this.targetType = targetType;
    this.targetId = targetId;
    return const Result.success(
      EventPerformerRequestPage(
        items: [],
        page: 0,
        size: 20,
        totalElements: 0,
        totalPages: 0,
        hasNext: false,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Promotions implements PromotionRepository {
  @override
  Future<Result<List<PromotionItem>>> getDisplayableByPlacement(
    String placement,
  ) async => const Result.success([]);
}

const _musician = MusicianProfile(
  id: 'musician-id',
  userId: 'musician-user-id',
  username: 'bugrasahin',
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
);

const _band = BandProfile(
  id: 'band-id',
  name: 'Şahbaz',
  description: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundCloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  members: [
    BandMemberSummary(
      userId: 'musician-user-id',
      profileId: 'musician-id',
      username: 'bugrasahin',
      profilePictureUrl: null,
      role: 'FOUNDER',
      status: 'ACTIVE',
    ),
  ],
);

const _venue = VenueOwnerProfile(
  venueProfileId: 'venue-profile-id',
  venueId: 'venue-id',
  ownerUserId: 'venue-owner-id',
  venueName: 'SoundConnect Ankara',
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
  status: 'APPROVED',
  activeMusicians: [],
  activeBands: [],
  weeklyEvents: [],
);
