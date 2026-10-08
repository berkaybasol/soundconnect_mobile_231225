// Offline promotional recording of production widgets. All event data below
// is fictional and exists only in this test process. No backend is configured.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/event/domain/entities/discovery_event.dart';
import 'package:soundconnect_23_12_25codx/modules/event/domain/entities/discovery_event_page.dart';
import 'package:soundconnect_23_12_25codx/modules/event/domain/event_discovery_search_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/event/presentation/screens/event_discovery_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/district.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/neighborhood.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  testWidgets(
    'record Ankara listener discovery with actual scrolling widgets',
    (tester) async {
      final output = Platform.environment['PROMO_CAPTURE_DIR'];
      if (output == null) return;
      final root = Directory(output);
      final capture = GlobalKey();
      final sessions = _Sessions();
      final audience = _Audience();
      final search = _Search();
      await serviceLocator.reset();
      serviceLocator
        ..registerSingleton<AuthSessionManager>(sessions)
        ..registerSingleton<DmBadgeCubit>(_Badges())
        ..registerSingleton<EngagementRepository>(_Comments())
        ..registerSingleton<VenueEventRepository>(_Details())
        ..registerSingleton<EventAudienceRepository>(audience);
      tester.view.physicalSize = const Size(430, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(serviceLocator.reset);
      await tester.runAsync(() async {
        await root.create(recursive: true);
        final fonts =
            '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
        final loader = FontLoader('Roboto');
        for (final name in ['Regular', 'Medium', 'Bold', 'Black']) {
          loader.addFont(
            File(
              '$fonts/Roboto-$name.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          );
        }
        await loader.load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        await (FontLoader('Segoe UI Emoji')..addFont(
              File(
                'C:/Windows/Fonts/seguiemj.ttf',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      });
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.navy.copyWith(
            textTheme: AppTheme.navy.textTheme.apply(
              fontFamily: 'Roboto',
              fontFamilyFallback: const ['Segoe UI Emoji'],
            ),
            primaryTextTheme: AppTheme.navy.primaryTextTheme.apply(
              fontFamily: 'Roboto',
              fontFamilyFallback: const ['Segoe UI Emoji'],
            ),
          ),
          builder: (_, child) => RepaintBoundary(key: capture, child: child!),
          home: MemberEventDiscoveryScreen(
            sessions: sessions,
            locationRepository: _Locations(),
            searchRepository: search,
            watchClock: false,
            now: () => DateTime.utc(2026, 9, 23, 9),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(Scaffold));
        for (final asset in [
          'assets/Logoyanyana.png',
          'assets/logo.png',
          'assets/ME!2-transparent.png',
          'assets/confined.png',
        ]) {
          await precacheImage(AssetImage(asset), context);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      const fps = 24;
      var frame = 0;
      final stages = <Map<String, Object>>[];
      final log = StringBuffer();
      late StreamSubscription<String> errors;
      late Future<void> drain;
      final ffmpeg = await tester.runAsync(() async {
        final process = await Process.start(
          Platform.environment['PROMO_FFMPEG'] ?? 'ffmpeg',
          [
            '-hide_banner',
            '-loglevel',
            'error',
            '-y',
            '-f',
            'rawvideo',
            '-pixel_format',
            'rgba',
            '-video_size',
            '860x1720',
            '-framerate',
            '$fps',
            '-i',
            'pipe:0',
            '-an',
            '-c:v',
            'libx264',
            '-preset',
            'fast',
            '-crf',
            '16',
            '-pix_fmt',
            'yuv420p',
            '-movflags',
            '+faststart',
            '${root.path}/app-recording.mp4',
          ],
        );
        errors = process.stderr.transform(utf8.decoder).listen(log.write);
        drain = process.stdout.drain<void>();
        return process;
      });
      expect(ffmpeg, isNotNull);
      final encoder = ffmpeg!;
      addTearDown(() {
        encoder.kill();
      });
      Future<void> shot({String? name}) async {
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          encoder.stdin.add(bytes!.buffer.asUint8List());
          await encoder.stdin.flush();
          if (name != null || frame % 48 == 0) {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '${root.path}/${name ?? 'frame-${frame.toString().padLeft(4, '0')}'}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
          }
          image.dispose();
        });
        frame++;
      }

      Future<void> hold(double seconds) async {
        for (var i = 0; i < (seconds * fps).round(); i++) {
          await tester.pump(const Duration(microseconds: 41667));
          await shot();
        }
      }

      void mark(String name) {
        stages.add({'stage': name, 'frame': frame, 'seconds': frame / fps});
        debugPrint('PROMO_CAPTURE $name frame=$frame');
      }

      Future<void> tap(Finder finder, double seconds) async {
        expect(finder, findsOneWidget);
        await tester.tap(finder);
        await hold(seconds);
      }

      Future<void> swipe(double distance, double seconds) async {
        final start = distance > 0
            ? const Offset(185, 730)
            : const Offset(185, 240);
        final gesture = await tester.startGesture(start);
        final count = (seconds * fps).round();
        for (var i = 1; i <= count; i++) {
          final t = i / count;
          final eased = Curves.easeInOutSine.transform(t);
          await gesture.moveTo(start + Offset(0, -distance * eased));
          await tester.pump(const Duration(microseconds: 41667));
          await shot();
        }
        await gesture.up();
        await tester.pump();
      }

      mark('discovery-intro');
      await hold(.75);
      mark('city-picker');
      await tap(find.text('Şehir seç'), .8);
      await tap(find.text('Ankara'), 1.1);
      mark('district-filter');
      await tap(
        find.byKey(const ValueKey('discovery-location-details-toggle')),
        .4,
      );
      await tap(find.text('Tüm ilçeler'), .7);
      await tap(find.text('Çankaya'), .9);
      await tap(
        find.byKey(const ValueKey('discovery-location-details-toggle')),
        .45,
      );
      await shot(name: '01-ankara-filters');
      mark('events-scroll');
      await swipe(420, 2.25);
      await hold(.9);
      await swipe(400, 2.25);
      await hold(.9);
      await shot(name: '02-ankara-results');
      mark('event-open');
      // The second production event card is in view after the real gestures.
      final target = find.text('Tunalı Caz Akşamı');
      expect(target, findsOneWidget);
      final targetY = tester.getCenter(target).dy;
      if (targetY < 110 || targetY > 700) {
        final animation = Scrollable.ensureVisible(
          tester.element(target),
          alignment: .4,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOut,
        );
        await hold(.7);
        await animation;
      }
      await tap(target, 1.0);
      expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
      await hold(1.4);
      await shot(name: '03-event-detail');
      mark('detail-scroll');
      await swipe(300, 2.0);
      await hold(1.2);
      await shot(name: '04-event-actions');
      mark('going-action');
      final going = find.text('Gidiyorum');
      expect(going, findsOneWidget);
      await tap(going, 1.2);
      expect(audience.lastIntent, EventAudienceStatus.going);
      await hold(2.0);
      await shot(name: '05-going-selected');
      mark('end');
      final result = await tester.runAsync(() async {
        await encoder.stdin.close();
        final exitCode = await encoder.exitCode;
        await drain;
        await errors.cancel();
        await File('${root.path}/capture-manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'source':
                'Current production Flutter widgets rendered with local in-memory demonstration repositories. Actual pointer scrolling and route transitions captured frame by frame.',
            'backendUsed': false,
            'data':
                'All event and venue names are fictional demonstration data. Ankara, Çankaya, and neighborhood labels are location fixtures.',
            'fps': fps,
            'width': 860,
            'height': 1720,
            'frames': frame,
            'durationSeconds': frame / fps,
            'stages': stages,
            'searchCalls': search.calls,
            'lastAudienceIntent': audience.lastIntent.name,
            'ffmpegExit': exitCode,
            'ffmpegLog': log.toString(),
          }),
        );
        return exitCode;
      });
      expect(result, 0, reason: log.toString());
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

class _Sessions extends Fake with ChangeNotifier implements AuthSessionManager {
  @override
  AuthSession get session => _session;
  final _session = AuthSession.authenticated(
    token: 'local-demo-token',
    userId: 'local-demo-listener',
    username: 'dinleyici',
    accountStatus: 'ACTIVE',
    roles: const ['ROLE_LISTENER'],
    permissions: const [],
    expiresAt: DateTime.utc(2100),
    isAdmin: false,
  );
}

class _Locations implements LocationRepository {
  @override
  Future<Result<List<City>>> getCities() async => const Result.success([
    City(id: 'ankara', name: 'Ankara'),
    City(id: 'istanbul', name: 'İstanbul'),
    City(id: 'izmir', name: 'İzmir'),
  ]);
  @override
  Future<Result<List<District>>> getDistricts(String cityId) async =>
      const Result.success([
        District(id: 'cankaya', name: 'Çankaya', cityId: 'ankara'),
        District(id: 'yenimahalle', name: 'Yenimahalle', cityId: 'ankara'),
      ]);
  @override
  Future<Result<List<Neighborhood>>> getNeighborhoods(
    String districtId,
  ) async => const Result.success([
    Neighborhood(
      id: 'bahcelievler',
      name: 'Bahçelievler',
      districtId: 'cankaya',
    ),
    Neighborhood(id: 'kavaklidere', name: 'Kavaklıdere', districtId: 'cankaya'),
  ]);
}

final _events = <DiscoveryEvent>[
  _event(
    1,
    'Bahçeli Akustik Gecesi',
    'Deniz & Ece',
    'Sahne 7',
    'Bahçelievler',
    19,
    30,
    'İki gitar, iki ses. Ankara akşamına sıcak bir akustik mola.',
  ),
  _event(
    2,
    'Tunalı Caz Akşamı',
    'Mavi Nota Trio',
    'Nota Sahne',
    'Kavaklıdere',
    20,
    30,
    'Kontrbas, piyano ve davul. Caz standartlarıyla Tunalı’da müzik dolu bir akşam.',
  ),
  _event(
    3,
    'Ankara Rock Buluşması',
    'Kuzey Hattı',
    'Rota Live',
    'Kızılay',
    21,
    0,
    'Gitarlar yükseliyor. Sevdiğin rock parçaları aynı sahnede.',
  ),
  _event(
    4,
    'Soul & Funk Gecesi',
    'Gece Rengi',
    'Bakır Sahne',
    'Ayrancı',
    21,
    30,
    'Ritmi yakala; soul vokalleri ve bol baslı bir funk gecesi.',
  ),
  _event(
    5,
    'Alternatif Sesler',
    'Mor Ufuk',
    'Teras Nota',
    'Bahçelievler',
    22,
    0,
    'Ankara’dan yeni sesler ve özgün şarkılar.',
  ),
];
DiscoveryEvent _event(
  int n,
  String title,
  String performer,
  String venue,
  String neighborhood,
  int hour,
  int minute,
  String description,
) => DiscoveryEvent(
  id: 'c0890d3f-805d-4808-b123-abb9a9c7966$n',
  title: title,
  performerName: performer,
  musicianProfileId: null,
  performerType: 'MANUAL',
  performerImageUrl: null,
  bandMembers: const [],
  venueId: '58e05c32-bd79-4823-bbc0-58c53ea5aee$n',
  venueName: venue,
  venueImageUrl: null,
  venueCity: 'Ankara',
  venueDistrict: 'Çankaya',
  venueNeighborhood: neighborhood,
  eventDate: DateTime(2026, 9, 23),
  startTime: TimeOfDay(hour: hour, minute: minute),
  endTime: TimeOfDay(hour: hour + 2, minute: minute),
  posterImageUrl: null,
  description: description,
);

class _Search implements EventDiscoverySearchRepository {
  final calls = <Map<String, Object?>>[];
  @override
  Future<Result<DiscoveryEventPage>> search({
    required DateTime date,
    required String cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async {
    calls.add({
      'city': cityId,
      'district': districtId,
      'neighborhood': neighborhoodId,
      'date': date.toIso8601String(),
    });
    return Result.success(
      DiscoveryEventPage(
        content: _events,
        number: 0,
        size: 20,
        totalElements: _events.length,
        totalPages: 1,
        last: true,
      ),
    );
  }
}

VenueEventDetail _detail(String id) {
  final e = _events.firstWhere((e) => e.id == id);
  String clock(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  return VenueEventDetail(
    id: e.id,
    shareUrl: null,
    posterImage: null,
    performerName: e.performerName,
    musicianProfileId: null,
    title: e.title,
    description:
        '${e.description}\n\nMavi Nota Trio bu akşam tanıdık caz melodilerini kendi yorumuyla sahneye taşıyor. Piyanoda Ada, kontrbasta Can ve davulda Ege; sıcak, samimi bir buluşma için bir araya geliyor.\n\nİlk set 20.30’da başlıyor. Kısa bir aranın ardından ikinci sette ritim biraz daha yükseliyor. Arkadaşlarınla gel, günün temposunu kapıda bırak ve müziğe kulak ver.\n\nProgram ve mekân bilgilerini etkinlik sayfasından inceleyebilir, sorularını aşağıya bırakabilirsin.',
    eventDate: e.eventDate,
    startTime: clock(e.startTime!),
    endTime: clock(e.endTime!),
    venueId: e.venueId,
    venueName: e.venueName,
    venueCity: e.venueCity,
    venueDistrict: e.venueDistrict,
    venueNeighborhood: e.venueNeighborhood,
  );
}

class _Details extends Fake implements VenueEventRepository {
  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) async =>
      Result.success(_detail(eventId));
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

class _Audience extends Fake implements EventAudienceRepository {
  @override
  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  EventAudienceStatus lastIntent = EventAudienceStatus.none;
  EventAudienceState state(String eventId) => EventAudienceState(
    eventId: eventId,
    intent: lastIntent,
    publishedOnProfile: false,
    note: null,
    version: changes.value,
    updatedAt: null,
    eventAvailable: true,
    eventEnded: false,
    canSetIntent: true,
    canPublish: true,
    publicationVisible: false,
    event: _detail(eventId),
  );
  @override
  Future<Result<EventAudienceState>> getIntent({
    required String eventId,
    required String expectedSessionKey,
  }) async => Result.success(state(eventId));
  @override
  Future<Result<EventAudienceState>> setIntent({
    required String eventId,
    required EventAudienceStatus intent,
    required bool publishedOnProfile,
    required String? note,
    required int expectedVersion,
    required String expectedSessionKey,
  }) async {
    lastIntent = intent;
    changes.value++;
    return Result.success(state(eventId));
  }
}
