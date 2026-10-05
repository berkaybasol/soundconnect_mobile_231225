part of 'guest_event_discovery_screen_test.dart';

void _registerGuestEventDiscoveryScreen2() {
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

  testWidgets(
    'discovery controls use the shared dark surface and input palette',
    (tester) async {
      await _mount(tester);
      await _city(tester, 'Ankara');
      await _toggleDetails(tester);
      for (final element
          in find
              .byWidgetPredicate(
                (widget) =>
                    widget.runtimeType.toString() == '_DiscoverySurface',
              )
              .evaluate()) {
        final surface = find.byWidget(element.widget);
        final container = tester.widget<Container>(
          find.descendant(of: surface, matching: find.byType(Container)).first,
        );
        expect(
          (container.decoration! as BoxDecoration).color,
          const [
                Key('discovery-filters-surface'),
                Key('discovery-suggestion-surface'),
              ].contains(element.widget.key)
              ? Color.lerp(
                  BackstagePalette.surface,
                  BackstagePalette.canvas,
                  .45,
                )
              : BackstagePalette.surface,
        );
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
          expect(material.color, BackstagePalette.input);
        }
      }
    },
  );

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
          'Roboto-Regular.ttf',
          'Roboto-Medium.ttf',
          'Roboto-Bold.ttf',
          'Roboto-Black.ttf',
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
