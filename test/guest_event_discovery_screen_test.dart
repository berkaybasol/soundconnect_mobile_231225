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
import 'package:soundconnect_23_12_25codx/shared/theme/app_colors.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/brand_gradient_icon.dart';

part 'guest_event_discovery_analytics_cases.dart';

const _failure = AppError(code: 'offline', message: 'Bağlantı kurulamadı.');
final _initialNow = DateTime.utc(2026, 9, 7, 12);
const _betaNotice =
    'Beta sürecinde olduğumuz için etkinlikler ağırlıklı olarak Ankara’da. Diğer şehirler için çalışmaya devam ediyoruz. 🌱';
const _suggestionNotice =
    'SoundConnect’te bulamadığın bir mekanı önererek mekanla iletişime geçmemize yardımcı olabilirsin.';

void main() {
  _discoveryAnalyticsTests();
  testWidgets('starts today without searching and requires a city', (
    tester,
  ) async {
    final search = _Search();
    await _mount(tester, search: search);
    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Yarın (8 Eyl)'), findsOneWidget);
    expect(find.text('Canlı müzik nerede?'), findsOneWidget);
    expect(find.text('Şehrindeki sahneleri keşfet.'), findsOneWidget);
    expect(
      find.text('Şehrindeki sahneleri ve müzisyenleri keşfet.'),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/Logoyanyana.png',
      ),
      findsOneWidget,
    );
    expect(find.byType(BrandGradientIcon), findsWidgets);
    expect(find.text('Şehrini seçerek başla.'), findsNothing);
    final logo = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/Logoyanyana.png',
    );
    expect(tester.getSize(logo).width, 204);
    expect(tester.getSize(logo).height, 42);
    final heading = find.text('Canlı müzik nerede?');
    expect(tester.getTopLeft(heading).dy - tester.getBottomLeft(logo).dy, 10);
    // The bundled asset's transparent left margin scales with its width.
    expect(
      tester.getTopLeft(logo).dx + 204 * 10 / 190,
      closeTo(tester.getTopLeft(heading).dx, .01),
    );
    expect(find.text('Tüm ilçeler'), findsNothing);
    expect(find.text('Tüm mahalleler'), findsNothing);
    expect(_detailsToggle, findsNothing);
    expect(find.text('Konumu daralt'), findsNothing);
    expect(find.text('Daha az seçenek'), findsNothing);
    expect(find.text('0 etkinlik'), findsNothing);
    expect(find.text('Etkinlikleri göster'), findsNothing);
    expect(search.calls, isEmpty);
    final today = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == 'Bugün',
    );
    expect(tester.widget<Semantics>(today).properties.selected, isTrue);
    expect(tester.widget<Semantics>(today).properties.onTap, isNotNull);
  });

  testWidgets(
    'tomorrow includes its date and automatically repeats a prior search',
    (tester) async {
      final search = _Search();
      await _mount(tester, search: search);
      await _city(tester, 'Ankara');
      expect(search.calls.single.date, DateTime(2026, 9, 7));
      expect(search.calls.single.city, 'ankara');
      expect(search.calls.single.district, isNull);
      await _tap(tester, 'Yarın (8 Eyl)');
      expect(search.calls.last.date, DateTime(2026, 9, 8));
      expect(search.calls.length, 2);
      await _tap(tester, 'Yarın (8 Eyl)');
      expect(search.calls.length, 2);
    },
  );

  testWidgets(
    'date sheet offers only the five remaining days and updates selected label',
    (tester) async {
      await _mount(tester);
      await _tap(tester, 'Tarih seç');
      expect(find.text('Hangi gün?'), findsOneWidget);
      for (final label in [
        '9 Eylül · Çarşamba',
        '10 Eylül · Perşembe',
        '11 Eylül · Cuma',
        '12 Eylül · Cumartesi',
        '13 Eylül · Pazar',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(find.text('14 Eylül · Pazartesi'), findsNothing);
      await _tap(tester, '13 Eylül · Pazar');
      expect(find.text('13 Eyl'), findsOneWidget);
      expect(find.text('Tarih seç'), findsNothing);
    },
  );

  testWidgets(
    'refinements are optional and dependent selections reset on city change',
    (tester) async {
      final search = _Search();
      await _mount(tester, search: search);
      await _city(tester, 'Ankara');
      await _location(tester, 'Tüm ilçeler', 'Çankaya');
      await _location(tester, 'Tüm mahalleler', 'Çayyolu');
      expect(search.calls.last.district, 'cankaya');
      expect(search.calls.last.neighborhood, 'cayyolu');
      await _location(tester, 'Ankara', 'İstanbul', settle: false);
      expect(find.text('Çankaya'), findsNothing);
      expect(find.text('Çayyolu'), findsNothing);
      expect(find.text('Tüm ilçeler'), findsNothing);
      expect(find.text('Tüm mahalleler'), findsNothing);
      expect(find.text('İlçe veya mahalle seç'), findsOneWidget);
      expect(search.calls.last.city, 'istanbul');
      expect(search.calls.last.district, isNull);
      expect(search.calls.last.neighborhood, isNull);
    },
  );

  testWidgets(
    'all districts clears neighborhood and location search folds Turkish letters',
    (tester) async {
      final search = _Search();
      await _mount(tester, search: search);
      await _city(tester, 'Ankara');
      await _tap(tester, 'Tüm ilçeler');
      await tester.enterText(find.byType(TextField), 'cankaya');
      await tester.pump();
      expect(find.text('Çankaya'), findsOneWidget);
      await _tap(tester, 'Çankaya');
      await _location(tester, 'Tüm mahalleler', 'Çayyolu');
      await _location(tester, 'Çankaya', 'Tümü');
      expect(find.text('Çayyolu'), findsNothing);
      expect(search.calls.last.district, isNull);
      expect(search.calls.last.neighborhood, isNull);
    },
  );

  testWidgets(
    'result heading follows district neighborhood and reset selections',
    (tester) async {
      await _mount(tester);
      await _city(tester, 'Ankara');
      expect(find.text('7 Eylül · Ankara'), findsOneWidget);
      await _location(tester, 'Tüm ilçeler', 'Çankaya');
      expect(find.text('7 Eylül · Ankara · Çankaya'), findsOneWidget);
      await _location(tester, 'Tüm mahalleler', 'Çayyolu');
      expect(find.text('7 Eylül · Ankara · Çankaya · Çayyolu'), findsOneWidget);
      await _location(tester, 'Çayyolu', 'Tümü');
      expect(find.text('7 Eylül · Ankara · Çankaya'), findsOneWidget);
      expect(find.text('7 Eylül · Ankara · Çankaya · Çayyolu'), findsNothing);
      await _location(tester, 'Tüm mahalleler', 'Çayyolu');
      await _location(tester, 'Çankaya', 'Tümü');
      expect(find.text('7 Eylül · Ankara'), findsOneWidget);
      expect(find.textContaining('7 Eylül · Ankara ·'), findsNothing);
      await _location(tester, 'Ankara', 'İstanbul');
      expect(find.text('7 Eylül · İstanbul'), findsOneWidget);
      expect(find.textContaining('7 Eylül · Ankara'), findsNothing);
    },
  );

  testWidgets(
    'long trimmed location context and title fit at 320px and 200 percent text',
    (tester) async {
      const city = '  Uzun Şehir Adı Büyükşehir Merkezi  ';
      const district = '  Uzun İlçe Adı Kültür ve Sanat Merkezi  ';
      const neighborhood = '  Cumhuriyet Mahallesi Geniş Yerleşim Alanı  ';
      const title =
          'Uzun Etkinlik Başlığı Şehirde Canlı Müzikle Dolu Bir Akşam';
      const performer = 'Dolu Kadehi Ters Tut ve Çok Uzun Sanatçı Adı';
      final locations = _Locations();
      locations.cityReply = () async =>
          const Result.success([City(id: 'city', name: city)]);
      locations.districtReply = (_) async => const Result.success([
        District(id: 'district', name: district, cityId: 'city'),
      ]);
      locations.neighborhoodReply = (_) async => const Result.success([
        Neighborhood(
          id: 'neighborhood',
          name: neighborhood,
          districtId: 'district',
        ),
      ]);
      await _mount(
        tester,
        locations: locations,
        search: _Search()
          ..reply = (_) async => _page([title], performer: performer),
        size: const Size(320, 720),
        textScale: 2,
      );
      Future<void> chooseVisibleLongOption(String field, String value) async {
        await _tap(tester, field, preferField: true);
        final option = find.text(value);
        await _reveal(tester, option);
        // With 200% Ahem text a list item's paragraph can be taller than its
        // viewport. Tap the genuinely visible portion instead of its center.
        final visible = tester
            .getRect(option)
            .intersect(tester.getRect(find.byType(Scrollable).last))
            .intersect(const Rect.fromLTWH(0, 0, 320, 720));
        expect(visible.width, greaterThan(0));
        expect(visible.height, greaterThan(0));
        await tester.tapAt(visible.center);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
      }

      await chooseVisibleLongOption('Şehir seç', city);
      await chooseVisibleLongOption('Tüm ilçeler', district);
      await chooseVisibleLongOption('Tüm mahalleler', neighborhood);
      final heading = find.text(
        '7 Eylül · ${city.trim()} · ${district.trim()} · ${neighborhood.trim()}',
      );
      await _reveal(tester, heading);
      expect(heading, findsOneWidget);
      final headingRect = tester.getRect(heading);
      expect(headingRect.left, greaterThanOrEqualTo(0));
      expect(headingRect.right, lessThanOrEqualTo(320));
      await _reveal(tester, find.text(title));
      expect(
        find.byKey(const ValueKey('discovery-event-open-$title')),
        findsOneWidget,
      );
      final performerText = find.text(performer);
      final performerIcon = find.byWidgetPredicate(
        (widget) =>
            widget is BrandGradientIcon &&
            widget.icon == Icons.music_note_rounded,
      );
      expect(performerIcon, findsOneWidget);
      expect(tester.widget<Text>(performerText).maxLines, 2);
      expect(
        tester.widget<Text>(performerText).overflow,
        TextOverflow.ellipsis,
      );
      expect(
        tester.getTopLeft(performerText).dx -
            tester.getBottomRight(performerIcon).dx,
        closeTo(7, .01),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'title-side cue and whole card keep the same event detail destination',
    (tester) async {
      for (final tapCue in [true, false]) {
        const title = 'Bir Akşam Konseri';
        final navigation = _RecordedNavigation();
        await _mount(
          tester,
          search: _Search()..reply = (_) async => _page([title]),
          navigation: navigation,
        );
        await _city(tester, 'Ankara');
        final cue = find.byKey(const ValueKey('discovery-event-open-$title'));
        await _reveal(tester, cue);
        expect(tester.getSize(cue), const Size(36, 36));
        final tile = find.ancestor(
          of: cue,
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_DiscoveryEventTile',
          ),
        );
        final titleRect = tester.getRect(find.text(title));
        final performerRect = tester.getRect(
          find.descendant(of: tile, matching: find.text('Sahbaz')),
        );
        final performerIcon = find.descendant(
          of: tile,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is BrandGradientIcon &&
                widget.icon == Icons.music_note_rounded,
          ),
        );
        expect(performerIcon, findsOneWidget);
        final icon = tester.widget<BrandGradientIcon>(performerIcon);
        expect(icon.size, 17);
        expect(icon.semanticLabel, 'Sanatçı veya grup');
        final iconRect = tester.getRect(performerIcon);
        expect(performerRect.left - iconRect.right, closeTo(7, .01));
        expect(iconRect.center.dy, closeTo(performerRect.center.dy, .01));
        expect(iconRect.top, greaterThan(titleRect.bottom));
        final venueRect = tester.getRect(
          find.descendant(of: tile, matching: find.text('soundconnectankara')),
        );
        final cueRect = tester.getRect(cue);
        expect(cueRect.left, greaterThanOrEqualTo(titleRect.right));
        expect(cueRect.center.dy, greaterThanOrEqualTo(titleRect.top));
        expect(cueRect.center.dy, lessThanOrEqualTo(performerRect.bottom));
        expect(cueRect.bottom, lessThan(venueRect.top));
        expect(
          find.descendant(
            of: tile,
            matching: find.byIcon(Icons.arrow_forward_rounded),
          ),
          findsNothing,
        );
        final chevron = find.descendant(
          of: cue,
          matching: find.byIcon(Icons.chevron_right_rounded),
        );
        expect(chevron, findsOneWidget);
        expect(tester.widget<Icon>(chevron).size, 22);
        expect(
          find.descendant(of: tile, matching: find.byType(InkWell)),
          findsOneWidget,
        );

        // Capture and inspect the route without mounting the detail screen's
        // repositories. This verifies navigation with no backend calls.
        await tester.tap(tapCue ? cue : find.text(title));
        final route = navigation.pushed.last as MaterialPageRoute<dynamic>;
        final destination = route.builder(
          tester.element(find.byType(GuestEventDiscoveryScreen)),
        );
        expect(destination, isA<WeeklyEventDetailScreen>());
        final event = (destination as WeeklyEventDetailScreen).event;
        expect(event.id, title);
        expect(event.title, title);
        expect(event.venueId, 'venue');
        expect(event.bandProfileId, 'band');
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'late response from the previous date cannot overwrite new results',
    (tester) async {
      final old = Completer<Result<DiscoveryEventPage>>();
      final search = _Search()
        ..reply = (call) =>
            call.date.day == 7 ? old.future : Future.value(_page(['Yeni gün']));
      await _mount(tester, search: search);
      await _city(tester, 'Ankara', settle: false);
      expect(search.calls.length, 1);
      await _tap(tester, 'Yarın (8 Eyl)');
      old.complete(_page(['Eski gün']));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Yeni gün'));
      expect(find.text('Yeni gün'), findsOneWidget);
      expect(find.text('Eski gün'), findsNothing);
    },
  );

  testWidgets('changing city invalidates an in-flight search', (tester) async {
    final late = Completer<Result<DiscoveryEventPage>>();
    final search = _Search()
      ..reply = (call) => call.city == 'ankara'
          ? late.future
          : Future.value(_page(['Yeni şehir']));
    await _mount(tester, search: search);
    await _city(tester, 'Ankara', settle: false);
    await _location(tester, 'Ankara', 'İstanbul', settle: false);
    late.complete(_page(['Eski sonuç']));
    await tester.pumpAndSettle();
    expect(
      find.text('Hazırsın. Seçtiğin günün etkinliklerini keşfet.'),
      findsNothing,
    );
    expect(find.text('İstanbul'), findsOneWidget);
    expect(find.text('Eski sonuç'), findsNothing);
    expect(find.text('Tüm ilçeler'), findsNothing);
    expect(find.text('Tüm mahalleler'), findsNothing);
    expect(_detailsToggle, findsOneWidget);
    expect(search.calls.length, 2);
    expect(search.calls.last.city, 'istanbul');
  });

  testWidgets(
    'stale district and neighborhood replies cannot populate another city',
    (tester) async {
      final oldDistricts = Completer<Result<List<District>>>();
      final locations = _Locations()
        ..districtReply = (city) => city == 'ankara'
            ? oldDistricts.future
            : Future.value(
                const Result.success([
                  District(id: 'kadikoy', name: 'Kadıköy', cityId: 'istanbul'),
                ]),
              );
      await _mount(tester, locations: locations);
      await _city(tester, 'Ankara', settle: false);
      await _location(tester, 'Ankara', 'İstanbul', settle: false);
      oldDistricts.complete(
        const Result.success([
          District(id: 'old', name: 'Eski ilçe', cityId: 'ankara'),
        ]),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Tüm ilçeler');
      expect(find.text('Kadıköy'), findsOneWidget);
      expect(find.text('Eski ilçe'), findsNothing);
    },
  );

  testWidgets('late neighborhoods from a previous district are ignored', (
    tester,
  ) async {
    final oldNeighborhoods = Completer<Result<List<Neighborhood>>>();
    final locations = _Locations()
      ..neighborhoodReply = (district) => district == 'cankaya'
          ? oldNeighborhoods.future
          : Future.value(
              const Result.success([
                Neighborhood(
                  id: 'eryaman',
                  name: 'Eryaman',
                  districtId: 'etim',
                ),
              ]),
            );
    await _mount(tester, locations: locations);
    await _city(tester, 'Ankara');
    await _location(tester, 'Tüm ilçeler', 'Çankaya', settle: false);
    await _location(tester, 'Çankaya', 'Etimesgut', settle: false);
    oldNeighborhoods.complete(
      const Result.success([
        Neighborhood(id: 'old', name: 'Eski mahalle', districtId: 'cankaya'),
      ]),
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'Tüm mahalleler');
    expect(find.text('Eryaman'), findsOneWidget);
    expect(find.text('Eski mahalle'), findsNothing);
  });

  testWidgets(
    'optional fields stay disabled until their parent and loading dependency are ready',
    (tester) async {
      final districts = Completer<Result<List<District>>>();
      final neighborhoods = Completer<Result<List<Neighborhood>>>();
      final locations = _Locations();
      locations.districtReply = (_) => districts.future;
      locations.neighborhoodReply = (_) => neighborhoods.future;
      await _mount(tester, locations: locations);
      await _city(tester, 'Ankara', settle: false);
      await _toggleDetails(tester, settle: false);
      _expectFieldEnabled(tester, 'Tüm ilçeler', false);
      _expectFieldEnabled(tester, 'Tüm mahalleler', false);
      await _tap(tester, 'Tüm ilçeler', settle: false);
      expect(find.text('İlçe seç'), findsNothing);
      districts.complete(
        const Result.success([
          District(id: 'cankaya', name: 'Çankaya', cityId: 'ankara'),
        ]),
      );
      await tester.pumpAndSettle();
      _expectFieldEnabled(tester, 'Tüm ilçeler', true);
      _expectFieldEnabled(tester, 'Tüm mahalleler', false);
      await _location(tester, 'Tüm ilçeler', 'Çankaya', settle: false);
      _expectFieldEnabled(tester, 'Tüm mahalleler', false);
      await _tap(tester, 'Tüm mahalleler', settle: false);
      expect(find.text('Mahalle seç'), findsNothing);
      neighborhoods.complete(
        const Result.success([
          Neighborhood(id: 'cayyolu', name: 'Çayyolu', districtId: 'cankaya'),
        ]),
      );
      await tester.pumpAndSettle();
      _expectFieldEnabled(tester, 'Tüm mahalleler', true);
    },
  );

  testWidgets(
    'location disclosure preserves selected filters and visible summary when collapsed',
    (tester) async {
      final search = _Search();
      await _mount(tester, search: search);
      await _city(tester, 'Ankara');
      expect(find.text('İlçe veya mahalle seç'), findsOneWidget);
      expect(find.text('Tüm ilçeler'), findsNothing);
      await _location(tester, 'Tüm ilçeler', 'Çankaya');
      await _location(tester, 'Tüm mahalleler', 'Çayyolu');
      expect(find.text('Çankaya · Çayyolu'), findsOneWidget);
      await _toggleDetails(tester);
      expect(find.text('Çankaya'), findsNothing);
      expect(find.text('Çayyolu'), findsNothing);
      expect(find.text('Çankaya · Çayyolu'), findsOneWidget);
      expect(search.calls.last.district, 'cankaya');
      expect(search.calls.last.neighborhood, 'cayyolu');
      await _toggleDetails(tester);
      expect(find.text('Çankaya'), findsOneWidget);
      expect(find.text('Çayyolu'), findsOneWidget);
      await _location(tester, 'Ankara', 'İstanbul');
      expect(find.text('Çankaya · Çayyolu'), findsNothing);
      expect(find.text('Tüm ilçeler'), findsNothing);
      expect(find.text('İlçe veya mahalle seç'), findsOneWidget);
      expect(_detailsToggle, findsOneWidget);
      expect(find.text('Seçimleri temizle'), findsNothing);
    },
  );

  testWidgets(
    'page failure preserves first page and retries the same page without duplicates',
    (tester) async {
      var attempts = 0;
      final search = _Search()
        ..reply = (call) async {
          if (call.page == 0) {
            return _page(['İlk etkinlik'], last: false, total: 2);
          }
          attempts++;
          return attempts == 1
              ? const Result.failure(_failure)
              : _page(['İlk etkinlik', 'İkinci etkinlik'], number: 1, total: 2);
        };
      await _mount(tester, search: search);
      await _city(tester, 'Ankara');
      await _tap(tester, 'Daha fazla etkinlik');
      expect(find.text('Diğer etkinlikler yüklenemedi.'), findsOneWidget);
      expect(find.text('İlk etkinlik'), findsOneWidget);
      await _tap(tester, 'Tekrar dene');
      await _reveal(tester, find.text('İkinci etkinlik'));
      expect(find.text('İkinci etkinlik'), findsOneWidget);
      expect(search.calls.map((call) => call.page), [0, 1, 1]);
      expect(find.text('Daha fazla etkinlik'), findsNothing);
      final titles = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data);
      expect(
        titles.where((title) => title == 'İlk etkinlik').length,
        lessThanOrEqualTo(1),
      );
    },
  );

  testWidgets(
    'initial search errors are not displayed as zero results and can retry',
    (tester) async {
      var attempts = 0;
      final search = _Search()
        ..reply = (_) async =>
            ++attempts == 1 ? const Result.failure(_failure) : _page([]);
      await _mount(tester, search: search);
      await _city(tester, 'Ankara');
      expect(find.text('Bağlantı kurulamadı.'), findsOneWidget);
      expect(find.text('0 etkinlik'), findsNothing);
      expect(find.text('Bu gün için etkinlik bulunamadı.'), findsNothing);
      await _tap(tester, 'Tekrar dene');
      expect(find.text('Bu gün için etkinlik bulunamadı.'), findsOneWidget);
      expect(find.text('0 etkinlik'), findsOneWidget);
    },
  );

  testWidgets('city loading error offers a real retry', (tester) async {
    var attempts = 0;
    final locations = _Locations()
      ..cityReply = () async => ++attempts == 1
          ? const Result.failure(_failure)
          : const Result.success([City(id: 'ankara', name: 'Ankara')]);
    await _mount(tester, locations: locations);
    expect(
      find.text('Şehirler yüklenemedi. Tekrar deneyebilirsin.'),
      findsOneWidget,
    );
    await _tap(tester, 'Tekrar dene');
    await _city(tester, 'Ankara');
    expect(attempts, 2);
  });

  testWidgets(
    'resume at Istanbul midnight moves an expired day to today and repeats search',
    (tester) async {
      var now = DateTime.utc(2026, 9, 7, 20, 59);
      final search = _Search();
      await _mount(tester, search: search, now: () => now);
      await _city(tester, 'Ankara');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime.utc(2026, 9, 7, 21, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(search.calls.last.date, DateTime(2026, 9, 8));
      expect(find.text('Yarın (9 Eyl)'), findsOneWidget);
    },
  );

  testWidgets(
    'resume retains a future selected day if still inside the allowed window',
    (tester) async {
      var now = _initialNow;
      final search = _Search();
      await _mount(tester, search: search, now: () => now);
      await _city(tester, 'Ankara');
      await _tap(tester, 'Tarih seç');
      await _tap(tester, '11 Eylül · Cuma');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime.utc(2026, 9, 8, 12);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(search.calls.last.date, DateTime(2026, 9, 11));
      expect(find.text('11 Eyl'), findsOneWidget);
    },
  );

  testWidgets('disposed screen safely ignores outstanding repositories', (
    tester,
  ) async {
    final pending = Completer<Result<List<City>>>();
    await _mount(
      tester,
      locations: _Locations()..cityReply = () => pending.future,
      settle: false,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(
      const Result.success([City(id: 'ankara', name: 'Ankara')]),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('date changes do not issue requests before selecting a city', (
    tester,
  ) async {
    final search = _Search();
    await _mount(tester, search: search);
    await _tap(tester, 'Yarın (8 Eyl)');
    await _tap(tester, 'Tarih seç');
    await _tap(tester, '11 Eylül · Cuma');
    expect(search.calls, isEmpty);
    expect(find.text('Etkinlikleri göster'), findsNothing);
    await _city(tester, 'Ankara');
    expect(search.calls.single.date, DateTime(2026, 9, 11));
    expect(search.calls.single.page, 0);
  });

  testWidgets('first city selection searches only after the 300ms debounce', (
    tester,
  ) async {
    final search = _Search();
    await _mount(tester, search: search);
    await _tap(tester, 'Şehir seç');
    await tester.tap(find.text('Ankara'));
    await tester.pump();
    expect(search.calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 299));
    expect(search.calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(search.calls.single.city, 'ankara');
    expect(search.calls.single.date, DateTime(2026, 9, 7));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'rapid date choices coalesce and clear the previous result immediately',
    (tester) async {
      final search = _Search()..reply = (_) async => _page(['Önceki konser']);
      await _mount(tester, search: search);
      await _city(tester, 'Ankara');
      expect(search.calls.length, 1);
      await _reveal(tester, find.text('Yarın (8 Eyl)'));
      await tester.tap(find.text('Yarın (8 Eyl)'));
      await tester.pump();
      expect(find.text('Önceki konser'), findsNothing);
      expect(find.text('0 etkinlik'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Bugün'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Yarın (8 Eyl)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 299));
      expect(search.calls.length, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(search.calls.length, 2);
      expect(search.calls.last.date, DateTime(2026, 9, 8));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'location controls remain usable during a pending search and newer filters win',
    (tester) async {
      final old = Completer<Result<DiscoveryEventPage>>();
      final search = _Search()
        ..reply = (call) => call.district == null
            ? old.future
            : Future.value(_page(['İlçe konseri']));
      await _mount(tester, search: search);
      await _city(tester, 'Ankara', settle: false);
      _expectFieldEnabled(tester, 'Ankara', true);
      await _toggleDetails(tester, settle: false);
      _expectFieldEnabled(tester, 'Tüm ilçeler', true);
      await _location(tester, 'Tüm ilçeler', 'Çankaya', settle: false);
      expect(search.calls.last.district, 'cankaya');
      old.complete(_page(['Gecikmiş şehir sonucu']));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('İlçe konseri'));
      expect(find.text('İlçe konseri'), findsOneWidget);
      expect(find.text('Gecikmiş şehir sonucu'), findsNothing);
    },
  );

  testWidgets(
    'reselecting the same city district or neighborhood does not search again',
    (tester) async {
      final search = _Search();
      await _mount(tester, search: search);
      Future<void> reselect(String label) async {
        await _tap(tester, label, preferField: true);
        final sheet = find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString() == '_DiscoveryLocationSheet',
        );
        await tester.tap(
          find.descendant(of: sheet, matching: find.text(label)),
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
      }

      await _city(tester, 'Ankara');
      expect(search.calls.length, 1);
      await reselect('Ankara');
      expect(search.calls.length, 1);
      await _location(tester, 'Tüm ilçeler', 'Çankaya');
      expect(search.calls.length, 2);
      await reselect('Çankaya');
      expect(search.calls.length, 2);
      await _location(tester, 'Tüm mahalleler', 'Çayyolu');
      expect(search.calls.length, 3);
      await reselect('Çayyolu');
      await _toggleDetails(tester);
      await _toggleDetails(tester);
      expect(search.calls.length, 3);
      expect(search.calls.last.neighborhood, 'cayyolu');
    },
  );

  testWidgets(
    'ten thousand results stay page bounded and repeated load-more taps cannot duplicate requests',
    (tester) async {
      final next = Completer<Result<DiscoveryEventPage>>();
      final search = _Search()
        ..reply = (call) => call.page == 0
            ? Future.value(
                _page(
                  List.generate(20, (index) => 'Konser $index'),
                  total: 10000,
                  last: false,
                ),
              )
            : next.future;
      await _mount(tester, search: search);
      await _city(tester, 'Ankara');
      expect(search.calls.length, 1);
      expect(search.calls.single.size, 20);
      expect(search.calls.single.page, 0);
      await _tap(tester, 'Daha fazla etkinlik', settle: false);
      await _tap(tester, 'Daha fazla etkinlik', settle: false);
      expect(search.calls.map((call) => call.page), [0, 1]);
      expect(search.calls.every((call) => call.size == 20), isTrue);
      next.complete(_page(['Ek konser'], number: 1, total: 10000, last: false));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Ek konser'));
      expect(find.text('Ek konser'), findsOneWidget);
      expect(search.calls.length, 2);
    },
  );

  testWidgets('disposing during debounce cancels the scheduled search', (
    tester,
  ) async {
    final search = _Search();
    await _mount(tester, search: search);
    await _tap(tester, 'Şehir seç');
    await tester.tap(find.text('Ankara'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(search.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disposing during an automatic request ignores its eventual response',
    (tester) async {
      final pending = Completer<Result<DiscoveryEventPage>>();
      final search = _Search()..reply = (_) => pending.future;
      await _mount(tester, search: search);
      await _city(tester, 'Ankara', settle: false);
      expect(search.calls.length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(_page(['Silinmiş ekran']));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'date sheet updates while open when resumed after Istanbul midnight',
    (tester) async {
      var now = DateTime.utc(2026, 9, 7, 20, 59);
      await _mount(tester, now: () => now);
      await _tap(tester, 'Tarih seç');
      expect(find.text('9 Eylül · Çarşamba'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime.utc(2026, 9, 7, 21, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('9 Eylül · Çarşamba'), findsNothing);
      expect(find.text('14 Eylül · Pazartesi'), findsOneWidget);
      await _tap(tester, '14 Eylül · Pazartesi');
      expect(find.text('14 Eyl'), findsOneWidget);
    },
  );

  testWidgets('stale load-more response cannot append to a new date', (
    tester,
  ) async {
    final late = Completer<Result<DiscoveryEventPage>>();
    final search = _Search()
      ..reply = (call) async {
        if (call.date.day == 8) return _page(['Yeni tarih']);
        if (call.page == 0) return _page(['İlk gün'], total: 2, last: false);
        return late.future;
      };
    await _mount(tester, search: search);
    await _city(tester, 'Ankara');
    await _tap(tester, 'Daha fazla etkinlik', settle: false);
    await tester.drag(
      find.byKey(const PageStorageKey('guest-discovery-scroll')),
      const Offset(0, 1000),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _tap(tester, 'Yarın (8 Eyl)');
    late.complete(_page(['Geç kalan sonuç'], number: 1));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Yeni tarih'));
    expect(find.text('Yeni tarih'), findsOneWidget);
    expect(find.text('Geç kalan sonuç'), findsNothing);
    expect(search.calls.map((call) => call.page), [0, 1, 0]);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('320px layout and date sheet fit at text scale $scale', (
      tester,
    ) async {
      await _mount(tester, size: const Size(320, 720), textScale: scale);
      expect(tester.takeException(), isNull);
      await _tap(tester, 'Tarih seç');
      await _tap(tester, '13 Eylül · Pazar');
      await _city(tester, 'Ankara');
      await _location(tester, 'Tüm ilçeler', 'Çankaya');
      await _location(tester, 'Tüm mahalleler', 'Çayyolu');
    });
  }

  testWidgets(
    'table action is gated for guests and login navigation remains available',
    (tester) async {
      await _mount(tester);
      await tester.tap(find.byIcon(Icons.groups_2_rounded));
      await tester.pumpAndSettle();
      expect(
        find.text('Masaları görmek veya masa açmak için giriş yap.'),
        findsOneWidget,
      );
      await _tap(tester, 'Giriş yap');
      expect(find.text('LOGIN DESTINATION'), findsOneWidget);
    },
  );

  for (final size in [const Size(390, 844), const Size(320, 500)]) {
    testWidgets(
      'draggable table action stays within viewport and above footer at $size',
      (tester) async {
        await _mount(tester, size: size, textScale: size.height == 500 ? 2 : 1);
        final fab = find.byTooltip('Masalar');
        final footer = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_DiscoveryAuthFooter',
        );
        void expectSafeBounds() {
          final rect = tester.getRect(fab);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.bottom, lessThanOrEqualTo(tester.getTopLeft(footer).dy));
          expect(tester.takeException(), isNull);
        }

        expectSafeBounds();
        for (final delta in [
          const Offset(-1000, -1000),
          const Offset(1000, 1000),
          const Offset(-1000, 1000),
        ]) {
          final before = tester.getRect(fab);
          await tester.drag(find.byIcon(Icons.groups_2_rounded), delta);
          await tester.pumpAndSettle();
          expectSafeBounds();
          expect(tester.getRect(fab), isNot(before));
        }
        expect(
          find.text('Masaları görmek veya masa açmak için giriş yap.'),
          findsNothing,
        );
      },
    );
  }

  testWidgets(
    'registration footer offers options then email registration without requiring search',
    (tester) async {
      await _mount(tester);
      await _tap(tester, 'Üye Ol');
      expect(
        find.byKey(const Key('registration-options-sheet')),
        findsOneWidget,
      );
      expect(find.text('Google ile devam et'), findsOneWidget);
      expect(find.text('Yakında'), findsOneWidget);
      expect(find.text('REGISTER DESTINATION'), findsNothing);
      await tester.tap(find.byKey(const Key('registration-email-continue')));
      await tester.pumpAndSettle();
      expect(find.text('REGISTER DESTINATION'), findsOneWidget);
    },
  );

  testWidgets('no reset action is shown for date, city, or loaded results', (
    tester,
  ) async {
    final search = _Search()..reply = (_) async => _page(['Akşam konseri']);
    await _mount(tester, search: search);
    expect(find.text('Seçimleri temizle'), findsNothing);
    await _tap(tester, 'Yarın (8 Eyl)');
    expect(find.text('Seçimleri temizle'), findsNothing);
    await _city(tester, 'Ankara');
    expect(find.text('Seçimleri temizle'), findsNothing);
    expect(
      find.text('Hazırsın. Seçtiğin günün etkinliklerini keşfet.'),
      findsNothing,
    );
    await _reveal(tester, find.text('Akşam konseri'));
    expect(find.text('Akşam konseri'), findsOneWidget);
    expect(find.text('Seçimleri temizle'), findsNothing);
  });

  testWidgets(
    'auth actions retain matching branded geometry without search icons',
    (tester) async {
      await _mount(tester);
      await _city(tester, 'Ankara');
      Finder action(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString() == '_DiscoveryPrimaryButton',
        ),
      );
      BoxDecoration decoration(Finder button) =>
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: button,
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      final suggestion = action('Mekan öner');
      expect(find.text('Etkinlikleri göster'), findsNothing);
      final login = action('Giriş Yap');
      final register = action('Üye Ol');
      for (final button in [suggestion, login, register]) {
        expect(button, findsOneWidget);
        expect(decoration(button).borderRadius, BorderRadius.circular(15));
        // The shared minimum is identical. Long labels may wrap under the
        // intentionally wide Ahem test font without clipping their content.
        expect(
          find.descendant(
            of: button,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is ConstrainedBox &&
                  widget.constraints.minHeight == 52,
            ),
          ),
          findsOneWidget,
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(52));
      }
      expect(tester.getSize(login).height, tester.getSize(register).height);
      expect(decoration(login).gradient, isNull);
      expect(decoration(register).gradient, isNotNull);
      expect(
        find.descendant(of: login, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(
        find.descendant(of: register, matching: find.byType(Icon)),
        findsNothing,
      );
    },
  );

  testWidgets('login footer opens login without requiring a search', (
    tester,
  ) async {
    await _mount(tester);
    await _tap(tester, 'Giriş Yap');
    expect(find.text('LOGIN DESTINATION'), findsOneWidget);
  });

  testWidgets('discovery controls use the studio surface and input palette', (
    tester,
  ) async {
    await _mount(tester);
    await _city(tester, 'Ankara');
    await _toggleDetails(tester);
    for (final element
        in find
            .byWidgetPredicate(
              (widget) => widget.runtimeType.toString() == '_DiscoverySurface',
            )
            .evaluate()) {
      final surface = find.byWidget(element.widget);
      final container = tester.widget<Container>(
        find.descendant(of: surface, matching: find.byType(Container)).first,
      );
      expect((container.decoration! as BoxDecoration).color, AppColors.navBlue);
    }
    for (final type in [
      '_DiscoveryChoice',
      '_DiscoveryField',
      '_DiscoveryPrimaryButton',
    ]) {
      final controls = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == type,
      );
      expect(controls, findsWidgets);
      for (final element in controls.evaluate()) {
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byWidget(element.widget),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.color, AppColors.inputFill);
      }
    }
  });

  testWidgets(
    'beta invitation is present before choosing a city and remains in Ankara',
    (tester) async {
      await _mount(tester);
      expect(find.text(_betaNotice), findsOneWidget);
      expect(find.text(_suggestionNotice), findsOneWidget);
      expect(find.text('Mekan öner'), findsOneWidget);
      expect(find.text('Şehrini seçerek başla.'), findsNothing);
      await _city(tester, 'Ankara');
      expect(find.text(_betaNotice), findsOneWidget);
      expect(find.text(_suggestionNotice), findsOneWidget);
      expect(find.text('Mekan öner'), findsOneWidget);
      expect(
        find.text('Hazırsın. Seçtiğin günün etkinliklerini keşfet.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'beta invitation does not depend on city name formatting or identifier',
    (tester) async {
      final locations = _Locations()
        ..cityReply = () async => const Result.success([
          City(id: 'different-identifier', name: ' aNkArA '),
        ]);
      await _mount(tester, locations: locations);
      await _city(tester, ' aNkArA ');
      expect(find.text(_betaNotice), findsOneWidget);
      expect(find.text('Mekan öner'), findsOneWidget);
    },
  );

  testWidgets(
    'other cities show exact beta and venue suggestion copy before and after searching',
    (tester) async {
      await _mount(tester);
      await _city(tester, 'İstanbul');
      expect(find.text(_betaNotice), findsOneWidget);
      expect(find.text(_suggestionNotice), findsOneWidget);
      expect(find.text('Mekan öner'), findsOneWidget);
      expect(
        find.text('Hazırsın. Seçtiğin günün etkinliklerini keşfet.'),
        findsNothing,
      );
      expect(find.text(_betaNotice), findsOneWidget);
      await _location(tester, 'İstanbul', 'Ankara');
      expect(find.text(_betaNotice), findsOneWidget);
      expect(find.text('Mekan öner'), findsOneWidget);
    },
  );

  testWidgets(
    'beta notice remains usable before and after city selection at 320px and 200 percent text',
    (tester) async {
      await _mount(tester, size: const Size(320, 720), textScale: 2);
      await _reveal(tester, find.text(_betaNotice));
      await _reveal(tester, find.text(_suggestionNotice));
      await _reveal(tester, find.text('Mekan öner'));
      expect(tester.takeException(), isNull);
      await _city(tester, 'İstanbul');
      await _reveal(tester, find.text(_betaNotice));
      await _reveal(tester, find.text(_suggestionNotice));
      await _reveal(tester, find.text('Mekan öner'));
      expect(find.text(_betaNotice), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'venue suggestion opens without choosing a city and cancel preserves the selected day',
    (tester) async {
      final search = _Search();
      final suggestions = _Suggestions();
      await _mount(tester, search: search, suggestions: suggestions);
      await _tap(tester, 'Yarın (8 Eyl)');
      await _tap(tester, 'Mekan öner');
      expect(find.byKey(const ValueKey('proposal-venue-name')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('proposal-city')),
          matching: find.text('İl seç'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('proposal-district')),
          matching: find.text('İlçe seç'),
        ),
        findsOneWidget,
      );
      expect(find.text('LOGIN DESTINATION'), findsNothing);
      expect(find.textContaining('Instagram'), findsNothing);
      await _tap(tester, 'Vazgeç');
      expect(find.byKey(const ValueKey('proposal-venue-name')), findsNothing);
      expect(_detailsToggle, findsNothing);
      expect(find.text(_betaNotice), findsOneWidget);
      expect(search.calls, isEmpty);
      expect(suggestions.submissions, 0);
      await _city(tester, 'Ankara');
      expect(search.calls.single.city, 'ankara');
      expect(search.calls.single.date, DateTime(2026, 9, 8));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'venue suggestion opens a prefilled guest form and cancel preserves discovery filters',
    (tester) async {
      final search = _Search();
      final suggestions = _Suggestions();
      await _mount(tester, search: search, suggestions: suggestions);
      await _city(tester, 'İstanbul');
      await _location(tester, 'Tüm ilçeler', 'Kadıköy');
      await _tap(tester, 'Yarın (8 Eyl)');
      await _tap(tester, 'Mekan öner');
      expect(find.byKey(const ValueKey('proposal-venue-name')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('proposal-city')),
          matching: find.text('İstanbul'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('proposal-district')),
          matching: find.text('Kadıköy'),
        ),
        findsOneWidget,
      );
      expect(find.text('LOGIN DESTINATION'), findsNothing);
      expect(find.textContaining('Instagram'), findsNothing);
      expect(suggestions.submissions, 0);
      await _tap(tester, 'Vazgeç');
      expect(find.byKey(const ValueKey('proposal-venue-name')), findsNothing);
      expect(search.calls.last.date, DateTime(2026, 9, 8));
      expect(search.calls.last.city, 'istanbul');
      expect(search.calls.last.district, 'kadikoy');
      expect(suggestions.submissions, 0);
    },
  );

  testWidgets(
    'guest submission uses injected repository and returns to unchanged discovery with success notice',
    (tester) async {
      final search = _Search();
      final suggestions = _Suggestions();
      await _mount(tester, search: search, suggestions: suggestions);
      await _city(tester, 'İstanbul');
      await _location(tester, 'Tüm ilçeler', 'Kadıköy');
      await _tap(tester, 'Yarın (8 Eyl)');
      await _tap(tester, 'Mekan öner');
      await tester.enterText(
        find.byKey(const ValueKey('proposal-venue-name')),
        'Test sahnesi',
      );
      await _tap(tester, 'Evet');
      await _tap(tester, 'Öneriyi gönder');
      expect(suggestions.submissions, 1);
      expect(find.byKey(const ValueKey('proposal-venue-name')), findsNothing);
      expect(find.text('Önerin bize ulaştı. Teşekkür ederiz!'), findsOneWidget);
      expect(find.text('LOGIN DESTINATION'), findsNothing);
      expect(search.calls.last.date, DateTime(2026, 9, 8));
      expect(search.calls.last.city, 'istanbul');
      expect(search.calls.last.district, 'kadikoy');
    },
  );

  if (Platform.environment['GUEST_DISCOVERY_RENDER_DIR']
      case final String directory) {
    testWidgets('render readable initial, date sheet, and result previews', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final materialFonts =
            '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
        final font = FontLoader('Roboto');
        for (final name in [
          'roboto-regular.ttf',
          'roboto-medium.ttf',
          'roboto-bold.ttf',
          'roboto-black.ttf',
        ]) {
          font.addFont(
            File(
              '$materialFonts/$name',
            ).readAsBytes().then(ByteData.sublistView),
          );
        }
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        if (Platform.isWindows) {
          final emojiFile = File(
            '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/seguiemj.ttf',
          );
          if (await emojiFile.exists()) {
            final emoji = FontLoader('GuestPreviewEmoji')
              ..addFont(emojiFile.readAsBytes().then(ByteData.sublistView));
            await emoji.load();
          }
        }
      });
      final key = GlobalKey();
      final search = _Search()
        ..reply = (_) async => _page(['Şehirde Bir Akşam'], total: 1);
      await _mount(
        tester,
        search: search,
        size: const Size(390, 844),
        capture: key,
      );
      await _capture(tester, key, directory, '01-initial.png');
      await _tap(tester, 'Mekan öner');
      await _capture(tester, key, directory, '08-no-city-suggestion-form.png');
      await _tap(tester, 'Vazgeç');
      await _tap(tester, 'Tarih seç');
      await _capture(tester, key, directory, '02-date-sheet.png');
      await _tap(tester, '11 Eylül · Cuma');
      await _city(tester, 'Ankara');
      await _capture(tester, key, directory, '05-city-selected.png');
      await _toggleDetails(tester);
      await _capture(tester, key, directory, '04-filters-open.png');
      await _toggleDetails(tester);
      await _reveal(tester, find.text('Şehirde Bir Akşam'));
      await _capture(tester, key, directory, '03-results.png');
      await _location(tester, 'Tüm ilçeler', 'Çankaya');
      await _location(tester, 'Tüm mahalleler', 'Çayyolu');
      await _reveal(tester, find.text('11 Eylül · Ankara · Çankaya · Çayyolu'));
      await _capture(tester, key, directory, '09-full-location-context.png');
      await _location(tester, 'Ankara', 'İstanbul');
      await _reveal(tester, find.text('Mekan öner'));
      await _capture(tester, key, directory, '06-other-city-notice.png');
      await _tap(tester, 'Mekan öner');
      await _capture(tester, key, directory, '07-suggestion-form.png');
    });
  }
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
