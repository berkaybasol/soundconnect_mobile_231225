import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/policy/stage_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/event/domain/entities/discovery_event_page.dart';
import 'package:soundconnect_23_12_25codx/modules/event/domain/entities/discovery_event.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/presentation/widgets/event_audience_controls.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/event/domain/event_discovery_search_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/event/presentation/screens/event_discovery_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/event/presentation/screens/guest_event_home_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/district.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/neighborhood.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_public_bottom_bar.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_route_args.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'support/event_audience_fakes.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    serviceLocator.registerSingleton<DmBadgeCubit>(_Badges());
  });
  tearDown(() async => serviceLocator.reset());

  if (Platform.environment['MEMBER_DISCOVERY_RENDER_DIR'] != null) {
    testWidgets('render authenticated discovery with real fonts and actual bar', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final fonts =
            '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
        final loader = FontLoader('Roboto');
        for (final file in [
          'roboto-regular.ttf',
          'roboto-medium.ttf',
          'roboto-bold.ttf',
          'roboto-black.ttf',
        ]) {
          loader.addFont(
            File('$fonts/$file').readAsBytes().then(ByteData.sublistView),
          );
        }
        await loader.load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      await _mount(
        tester,
        capture: capture,
        search: _Search(events: [_event()]),
      );
      await _chooseCity(tester);
      await tester.runAsync(() async {
        final context = tester.element(find.byType(Scaffold));
        for (final asset in [
          'assets/logo.png',
          'assets/ME!2-transparent.png',
          'assets/confined.png',
        ]) {
          await precacheImage(AssetImage(asset), context);
        }
      });
      await tester.pumpAndSettle();
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byTooltip('Masalar'), findsOneWidget);
      expect(find.text('Giriş Yap'), findsNothing);
      expect(find.text('Üye Ol'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final pixels =
            await (capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
        final output = Platform.environment['MEMBER_DISCOVERY_RENDER_DIR']!;
        await Directory(output).create(recursive: true);
        await File(
          '$output/member-discovery.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        pixels.dispose();
      });
    });
  }

  for (final role in ['ROLE_LISTENER', 'ROLE_MUSICIAN']) {
    testWidgets(
      '$role result opens real event detail with the same session and audience controls',
      (tester) async {
        final sessions = _Sessions(_session(role: role));
        final audience = AudienceTestRepository();
        serviceLocator
          ..registerSingleton<AuthSessionManager>(sessions)
          ..registerSingleton<EventAudienceRepository>(audience)
          ..registerSingleton<EngagementRepository>(_Comments())
          ..registerSingleton<VenueEventRepository>(_Details());
        await _mount(
          tester,
          sessions: sessions,
          search: _Search(events: [_event()]),
        );
        await _chooseCity(tester);
        final title = find.text('Canlı müzik akşamı');
        await tester.ensureVisible(title);
        await tester.pump();
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
        expect(find.byType(EventAudienceControls), findsOneWidget);
        expect(find.byKey(const Key('event-audience-going')), findsOneWidget);
        expect(
          find.byKey(const Key('event-audience-thinking')),
          findsOneWidget,
        );
        expect(audience.reads, ['user']);
        expect(audience.writes, isEmpty);
        expect(
          serviceLocator<AuthSessionManager>().session,
          same(sessions.session),
        );
        expect(find.text('Giriş Yap'), findsNothing);
        expect(find.text('Üye Ol'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final stage in StageMode.values) {
    testWidgets(
      'member $stage has one matching bottom bar, no guest footer, direct table navigation',
      (tester) async {
        TableGroupListArgs? opened;
        final sessions = _Sessions(
          _session(
            role: stage == StageMode.backstage
                ? 'ROLE_MUSICIAN'
                : 'ROLE_LISTENER',
          ),
        );
        await _mount(
          tester,
          sessions: sessions,
          stage: stage,
          onTable: (args) => opened = args,
        );
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(BottomNavigationBar), findsOneWidget);
        final bar = tester.widget<ProfilePublicBottomBar>(
          find.byType(ProfilePublicBottomBar),
        );
        expect(bar.stageMode, stage);
        expect(bar.currentIndex, stage == StageMode.mainstage ? 0 : 2);
        expect(find.text('Giriş Yap'), findsNothing);
        expect(find.text('Üye Ol'), findsNothing);
        final callback = tester
            .widget<GuestEventDiscoveryScreen>(
              find.byType(GuestEventDiscoveryScreen),
            )
            .onTableTap!;
        callback();
        callback();
        await tester.pumpAndSettle();
        expect(find.text('TABLE DESTINATION'), findsOneWidget);
        expect(opened?.bottomBarStageMode, stage);
        expect(
          find.text('Masaları görmek veya masa açmak için giriş yap.'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'listener cannot acquire backstage chrome through route arguments',
    (tester) async {
      await _mount(tester, stage: StageMode.backstage);
      final bar = tester.widget<ProfilePublicBottomBar>(
        find.byType(ProfilePublicBottomBar),
      );
      expect(bar.stageMode, StageMode.mainstage);
      expect(bar.currentIndex, 0);
    },
  );

  for (final role in ['ROLE_VENUE', 'ROLE_STUDIO']) {
    testWidgets(
      '$role table bubble promises browsing, not forbidden creation',
      (tester) async {
        TableGroupListArgs? opened;
        await _mount(
          tester,
          sessions: _Sessions(_session(role: role)),
          stage: StageMode.backstage,
          onTable: (args) => opened = args,
        );
        expect(find.text('Masaları görmek için\ndokunun'), findsOneWidget);
        expect(find.text('Masa açmak için\ndokunun'), findsNothing);
        await tester.tap(find.byIcon(Icons.groups_2_rounded));
        await tester.pumpAndSettle();
        expect(opened?.bottomBarStageMode, StageMode.backstage);
      },
    );
  }

  testWidgets(
    'member filters survive keyboard dismissal and returning from location picker',
    (tester) async {
      await _mount(tester);
      await tester.tap(find.text('Şehir seç'));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      expect(field, findsOneWidget);
      await tester.enterText(field, 'Ank');
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 310);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ankara'));
      tester.view.resetViewInsets();
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Ankara'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same public city/date search works and survives table round trip',
    (tester) async {
      final search = _Search();
      await _mount(tester, search: search);
      await _chooseCity(tester);
      expect(search.calls.single, (DateTime(2026, 9, 8), 'ankara', 0, 20));
      await tester.tap(find.byIcon(Icons.groups_2_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BACK TO DISCOVERY'));
      await tester.pumpAndSettle();
      expect(find.text('Ankara'), findsOneWidget);
      expect(search.calls.length, 1);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    },
  );

  testWidgets(
    'token refresh preserves public filters without re-fetching cities',
    (tester) async {
      final sessions = _Sessions(_session());
      final locations = _Locations();
      final search = _Search();
      await _mount(
        tester,
        sessions: sessions,
        locations: locations,
        search: search,
      );
      await _chooseCity(tester);
      sessions.change(_session(token: 'replacement'));
      await tester.pumpAndSettle();
      expect(find.text('Ankara'), findsOneWidget);
      expect(locations.cityCalls, 1);
      expect(search.calls.length, 1);
    },
  );

  testWidgets(
    'logout removes member actions and rejects captured table callback',
    (tester) async {
      final sessions = _Sessions(_session());
      var tableCalls = 0;
      await _mount(tester, sessions: sessions, onTable: (_) => tableCalls++);
      final callback = tester
          .widget<GuestEventDiscoveryScreen>(
            find.byType(GuestEventDiscoveryScreen),
          )
          .onTableTap!;
      sessions.change(const AuthSession.guest());
      callback();
      await tester.pumpAndSettle();
      expect(find.byType(GuestEventDiscoveryScreen), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byTooltip('Masalar'), findsNothing);
      expect(tableCalls, 0);
    },
  );

  testWidgets(
    'replacement account fences old callback even while public search remains',
    (tester) async {
      final sessions = _Sessions(_session());
      var tableCalls = 0;
      await _mount(tester, sessions: sessions, onTable: (_) => tableCalls++);
      final callback = tester
          .widget<GuestEventDiscoveryScreen>(
            find.byType(GuestEventDiscoveryScreen),
          )
          .onTableTap!;
      sessions.change(_session(userId: 'other'));
      callback();
      await tester.pumpAndSettle();
      expect(find.byType(GuestEventDiscoveryScreen), findsOneWidget);
      expect(tableCalls, 0);
    },
  );

  for (final state in ['guest', 'inactive', 'onboarding']) {
    testWidgets(
      '$state member entry never loads discovery or displays authenticated controls',
      (tester) async {
        final locations = _Locations();
        final session = switch (state) {
          'guest' => const AuthSession.guest(),
          'inactive' => _session(status: 'INACTIVE'),
          _ => _session(choice: true),
        };
        await _mount(
          tester,
          sessions: _Sessions(session),
          locations: locations,
        );
        expect(find.byType(GuestEventDiscoveryScreen), findsNothing);
        expect(locations.cityCalls, 0);
      },
    );
  }

  testWidgets(
    'member bubble remains draggable above the sole bottom bar at 320px/200%',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _mount(tester, scale: 2);
      for (final offset in [
        Offset.zero,
        const Offset(-1000, -1000),
        const Offset(1000, 1000),
      ]) {
        if (offset != Offset.zero) {
          await tester.drag(find.byIcon(Icons.groups_2_rounded), offset);
        }
        await tester.pumpAndSettle();
        final bubble = tester.getRect(find.byTooltip('Masalar'));
        final bar = tester.getRect(find.byType(BottomNavigationBar));
        expect(bubble.left, greaterThanOrEqualTo(0));
        expect(bubble.top, greaterThanOrEqualTo(0));
        expect(bubble.right, lessThanOrEqualTo(320));
        expect(bubble.bottom, lessThanOrEqualTo(bar.top));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'guest shared-screen defaults still show auth footer and login table gate',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: GuestEventDiscoveryScreen(
            locationRepository: _Locations(),
            searchRepository: _Search(),
            watchClock: false,
            now: () => DateTime.utc(2026, 9, 8, 9),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Giriş Yap'), findsOneWidget);
      expect(find.text('Üye Ol'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      await tester.tap(find.byIcon(Icons.groups_2_rounded));
      await tester.pumpAndSettle();
      expect(
        find.text('Masaları görmek veya masa açmak için giriş yap.'),
        findsOneWidget,
      );
    },
  );
}

Future<void> _chooseCity(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Şehir seç'));
  await tester.tap(find.text('Şehir seç'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ankara'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

Future<void> _mount(
  WidgetTester tester, {
  _Sessions? sessions,
  StageMode stage = StageMode.mainstage,
  _Locations? locations,
  _Search? search,
  double scale = 1,
  GlobalKey? capture,
  ValueChanged<TableGroupListArgs>? onTable,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: capture == null
          ? AppTheme.navy
          : AppTheme.navy.copyWith(
              textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
              primaryTextTheme: AppTheme.navy.primaryTextTheme.apply(
                fontFamily: 'Roboto',
              ),
            ),
      builder: (context, child) => RepaintBoundary(
        key: capture,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      routes: {
        AppRoutes.tableGroupList: (context) {
          onTable?.call(
            ModalRoute.of(context)!.settings.arguments! as TableGroupListArgs,
          );
          return Scaffold(
            body: Column(
              children: [
                const Text('TABLE DESTINATION'),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('BACK TO DISCOVERY'),
                ),
              ],
            ),
          );
        },
      },
      home: MemberEventDiscoveryScreen(
        args: EventDiscoveryArgs(bottomBarStageMode: stage),
        sessions: sessions ?? _Sessions(_session()),
        locationRepository: locations ?? _Locations(),
        searchRepository: search ?? _Search(),
        watchClock: false,
        now: () => DateTime.utc(2026, 9, 8, 9),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AuthSession _session({
  String userId = 'user',
  String token = 'token',
  String role = 'ROLE_LISTENER',
  String status = 'ACTIVE',
  bool choice = false,
}) => AuthSession.authenticated(
  token: token,
  userId: userId,
  username: 'listener',
  accountStatus: status,
  roles: [role],
  permissions: const [],
  expiresAt: DateTime.utc(2040),
  isAdmin: false,
  requiresListenerProfileChoice: choice,
);

class _Sessions extends Fake with ChangeNotifier implements AuthSessionManager {
  _Sessions(this._session);
  AuthSession _session;
  @override
  AuthSession get session => _session;
  void change(AuthSession value) {
    _session = value;
    notifyListeners();
  }
}

class _Locations implements LocationRepository {
  int cityCalls = 0;
  @override
  Future<Result<List<City>>> getCities() async {
    cityCalls++;
    return const Result.success([City(id: 'ankara', name: 'Ankara')]);
  }

  @override
  Future<Result<List<District>>> getDistricts(String cityId) async =>
      const Result.success([]);
  @override
  Future<Result<List<Neighborhood>>> getNeighborhoods(
    String districtId,
  ) async => const Result.success([]);
}

class _Search implements EventDiscoverySearchRepository {
  _Search({this.events = const []});
  final List<DiscoveryEvent> events;
  final calls = <(DateTime, String, int, int)>[];
  @override
  Future<Result<DiscoveryEventPage>> search({
    required DateTime date,
    required String cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async {
    calls.add((date, cityId, page, size));
    return Result.success(
      DiscoveryEventPage(
        content: events,
        number: 0,
        size: 20,
        totalElements: events.length,
        totalPages: events.isEmpty ? 0 : 1,
        last: true,
      ),
    );
  }
}

DiscoveryEvent _event() => DiscoveryEvent(
  id: audienceEventId,
  title: 'Canlı müzik akşamı',
  performerName: 'Sahbaz',
  musicianProfileId: null,
  performerType: 'MANUAL',
  performerImageUrl: null,
  bandMembers: const [],
  venueId: audienceVenueId,
  venueName: 'SoundConnect Ankara',
  venueImageUrl: null,
  venueCity: 'Ankara',
  venueDistrict: 'Çankaya',
  venueNeighborhood: 'Çayyolu',
  eventDate: DateTime(2026, 9, 8),
  startTime: const TimeOfDay(hour: 20, minute: 0),
  endTime: const TimeOfDay(hour: 22, minute: 0),
  posterImageUrl: null,
  description: 'Şehirde müzik dolu bir akşam.',
);

class _Details extends Fake implements VenueEventRepository {
  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) async =>
      Result.success(audienceState(eventId: eventId).event!);
}

class _Comments extends Fake implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));
}

class _Badges extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _Badges() : super(const DmBadgeState.initial());
  @override
  Future<void> ensureStarted() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
