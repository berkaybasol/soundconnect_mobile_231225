import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_tracker.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/presentation/widgets/analytics_exposure.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event/domain/entities/discovery_event.dart';
import 'package:soundconnect_23_12_25codx/modules/event/domain/entities/discovery_event_page.dart';
import 'package:soundconnect_23_12_25codx/modules/event/domain/event_discovery_search_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/event/domain/venue_suggestion_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/event/presentation/screens/guest_event_home_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/district.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/neighborhood.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/backstage_palette.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/brand_gradient_icon.dart';

part 'guest_event_discovery_analytics_cases.dart';

part 'guest_event_discovery_screen_test_register_guest_event_discovery_screen1.dart';
part 'guest_event_discovery_screen_test_register_guest_event_discovery_screen2.dart';

const _failure = AppError(code: 'offline', message: 'Bağlantı kurulamadı.');

final _initialNow = DateTime.utc(2026, 9, 7, 12);

const _betaNotice =
    'Beta sürecinde olduğumuz için etkinlikler ağırlıklı olarak Ankara’da. Diğer şehirler için çalışmaya devam ediyoruz. 🌱';

const _suggestionNotice =
    'SoundConnect’te bulamadığın bir mekanı önererek mekanla iletişime geçmemize yardımcı olabilirsin.';

void main() {
  _registerGuestEventDiscoveryScreen1();
  _registerGuestEventDiscoveryScreen2();
}

Future<void> _mount(
  WidgetTester tester, {
  _Locations? locations,
  _Search? search,
  _Suggestions? suggestions,
  DateTime Function()? now,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
  GlobalKey? capture,
  NavigatorObserver? navigation,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorObservers: [
          analyticsRouteObserver,
          if (navigation != null) navigation,
        ],
        theme: capture == null
            ? AppTheme.navy
            : AppTheme.navy.copyWith(
                textTheme: AppTheme.navy.textTheme.apply(
                  fontFamily: 'Roboto',
                  fontFamilyFallback: const ['GuestPreviewEmoji'],
                ),
                primaryTextTheme: AppTheme.navy.primaryTextTheme.apply(
                  fontFamily: 'Roboto',
                  fontFamilyFallback: const ['GuestPreviewEmoji'],
                ),
              ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routes: {
          AppRoutes.login: (_) =>
              const Scaffold(body: Text('LOGIN DESTINATION')),
          AppRoutes.register: (_) =>
              const Scaffold(body: Text('REGISTER DESTINATION')),
        },
        home: GuestEventDiscoveryScreen(
          locationRepository: locations ?? _Locations(),
          searchRepository: search ?? _Search(),
          suggestionRepository: suggestions ?? _Suggestions(),
          now: now ?? () => _initialNow,
          watchClock: false,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump();
}

void _expectFieldEnabled(WidgetTester tester, String label, bool enabled) {
  final field = find
      .ancestor(of: find.text(label), matching: find.byType(InkWell))
      .first;
  expect(
    tester.widget<InkWell>(field).onTap != null,
    enabled,
    reason: '$label enabled',
  );
}

Future<void> _tap(
  WidgetTester tester,
  String text, {
  bool settle = true,
  bool preferField = false,
}) async {
  if ((text == 'Tüm ilçeler' || text == 'Tüm mahalleler') &&
      find.text(text).evaluate().isEmpty &&
      _detailsToggle.evaluate().isNotEmpty) {
    await _toggleDetails(tester, settle: settle);
  }
  final finder = preferField
      ? find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_DiscoveryField',
          ),
          matching: find.text(text),
        )
      : find.text(text);
  await _reveal(tester, finder);
  await tester.tap(finder.first);
  await tester.pump();
  if (settle) {
    // Normal interactions wait for the trailing search debounce. Tests that
    // exercise its exact boundary use direct taps and short explicit pumps.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pump();
}

Finder get _detailsToggle =>
    find.byKey(const ValueKey('discovery-location-details-toggle'));

Future<void> _toggleDetails(WidgetTester tester, {bool settle = true}) async {
  await _reveal(tester, _detailsToggle);
  await tester.tap(_detailsToggle);
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _city(WidgetTester tester, String value, {bool settle = true}) =>
    _location(tester, 'Şehir seç', value, settle: settle);

Future<void> _location(
  WidgetTester tester,
  String field,
  String value, {
  bool settle = true,
}) async {
  await _tap(tester, field, settle: settle, preferField: true);
  await _tap(tester, value, settle: settle);
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String directory,
  String name,
) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final context = tester.element(find.byType(GuestEventDiscoveryScreen));
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(image.image, context);
    }
  });
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final frame = await boundary.toImage(pixelRatio: 1);
    final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name').writeAsBytes(bytes!.buffer.asUint8List());
    frame.dispose();
  });
}

class _RecordedNavigation extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

class _Locations implements LocationRepository {
  Future<Result<List<City>>> Function()? cityReply;
  Future<Result<List<District>>> Function(String)? districtReply;
  Future<Result<List<Neighborhood>>> Function(String)? neighborhoodReply;

  @override
  Future<Result<List<City>>> getCities() async =>
      cityReply?.call() ??
      const Result.success([
        City(id: 'ankara', name: 'Ankara'),
        City(id: 'istanbul', name: 'İstanbul'),
      ]);
  @override
  Future<Result<List<District>>> getDistricts(String cityId) async =>
      districtReply?.call(cityId) ??
      Result.success(
        cityId == 'ankara'
            ? const [
                District(id: 'cankaya', name: 'Çankaya', cityId: 'ankara'),
                District(id: 'etim', name: 'Etimesgut', cityId: 'ankara'),
              ]
            : const [
                District(id: 'kadikoy', name: 'Kadıköy', cityId: 'istanbul'),
              ],
      );
  @override
  Future<Result<List<Neighborhood>>> getNeighborhoods(
    String districtId,
  ) async =>
      neighborhoodReply?.call(districtId) ??
      const Result.success([
        Neighborhood(id: 'cayyolu', name: 'Çayyolu', districtId: 'cankaya'),
      ]);
}

class _SearchCall {
  const _SearchCall(
    this.date,
    this.city,
    this.district,
    this.neighborhood,
    this.page,
    this.size,
  );
  final DateTime date;
  final String city;
  final String? district;
  final String? neighborhood;
  final int page;
  final int size;
}

class _Search implements EventDiscoverySearchRepository {
  final calls = <_SearchCall>[];
  Future<Result<DiscoveryEventPage>> Function(_SearchCall)? reply;
  @override
  Future<Result<DiscoveryEventPage>> search({
    required DateTime date,
    required String cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async {
    final call = _SearchCall(
      date,
      cityId,
      districtId,
      neighborhoodId,
      page,
      size,
    );
    calls.add(call);
    return reply?.call(call) ?? _page([]);
  }
}

class _Suggestions implements VenueSuggestionRepository {
  int submissions = 0;

  @override
  Future<Result<void>> submit({
    required String requestId,
    required String venueName,
    required String cityId,
    required String districtId,
    required VenueSuggestionLiveMusic liveMusic,
  }) async {
    submissions++;
    return const Result.success(null);
  }
}

Result<DiscoveryEventPage> _page(
  List<String> titles, {
  int number = 0,
  int? total,
  bool last = true,
  String performer = 'Sahbaz',
}) => Result.success(
  DiscoveryEventPage(
    content: titles
        .map(
          (title) => DiscoveryEvent(
            id: title,
            title: title,
            performerName: performer,
            musicianProfileId: null,
            bandId: 'band',
            performerType: 'BAND',
            performerImageUrl: null,
            bandMembers: const [],
            venueId: 'venue',
            venueName: 'soundconnectankara',
            venueImageUrl: null,
            venueCity: 'Ankara',
            venueDistrict: 'Çankaya',
            venueNeighborhood: 'Çayyolu',
            eventDate: DateTime(2026, 9, 11),
            startTime: const TimeOfDay(hour: 20, minute: 0),
            endTime: const TimeOfDay(hour: 22, minute: 0),
            posterImageUrl: null,
            description: '',
          ),
        )
        .toList(),
    number: number,
    size: 20,
    totalElements: total ?? titles.length,
    totalPages: last ? number + 1 : number + 2,
    last: last,
  ),
);
