part of 'guest_event_discovery_screen_test.dart';

void _registerGuestEventDiscoveryScreen1() {
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
}
