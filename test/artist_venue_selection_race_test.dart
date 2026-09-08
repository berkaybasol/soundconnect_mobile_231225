import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_search_result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_venue_models.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_venue_request_sheet.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_venue_support.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

const artist = ProfileSearchResult(
  type: ProfileSearchResultType.band,
  targetId: 'band',
  userId: null,
  title: 'Sahbaz',
  subtitle: null,
  imageUrl: null,
);

void main() {
  Future<void> openArtists(
    WidgetTester tester,
    Future<List<ProfileSearchResult>> Function(String) search, {
    ValueChanged<ConnectedArtistRequestPayload?>? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await showConnectedArtistRequestBottomSheet(
                  context: context,
                  acceptedIds: {},
                  pendingIds: {},
                  searchArtists: search,
                );
                onResult?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'editing query invalidates earlier results before debounce fires',
    (tester) async {
      final old = Completer<List<ProfileSearchResult>>();
      await openArtists(tester, (_) => old.future);
      await tester.enterText(find.byType(TextField), 'sah');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'x');
      old.complete([artist]);
      await tester.pump();
      expect(find.text('Sahbaz'), findsNothing);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('changing search clears a selection that is no longer visible', (
    tester,
  ) async {
    await openArtists(tester, (_) async => [artist]);
    await tester.enterText(find.byType(TextField), 'sah');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sahbaz'));
    await tester.enterText(find.byType(TextField), 'other');
    await tester.pump();
    final next = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Devam'),
    );
    expect(next.onPressed, isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('artist continue cannot stack two note dialogs', (tester) async {
    await openArtists(tester, (_) async => [artist]);
    await tester.enterText(find.byType(TextField), 'sah');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sahbaz'));
    await tester.pump();
    final next = tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Devam'))
        .onPressed!;
    next();
    next();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog, skipOffstage: false), findsOneWidget);
  });

  Future<void> openVenues(
    WidgetTester tester, {
    required Future<List<VenueLookupOption>> Function(String) districts,
    Future<List<VenueLookupOption>> Function(String)? neighborhoods,
    ValueChanged<VenueRequestPayload?>? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await showVenueRequestBottomSheet(
                  context: context,
                  allVenues: const [VenueOption(id: 'venue', name: 'Venue')],
                  cities: const [
                    VenueLookupOption(id: 'a', name: 'Ankara'),
                    VenueLookupOption(id: 'b', name: 'Bursa'),
                  ],
                  acceptedIds: {},
                  pendingIds: {},
                  fetchDistricts: districts,
                  fetchNeighborhoods: neighborhoods ?? (_) async => [],
                  isMounted: () => context.mounted,
                );
                onResult?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('late city districts cannot overwrite the newer city filter', (
    tester,
  ) async {
    final first = Completer<List<VenueLookupOption>>();
    await openVenues(
      tester,
      districts: (city) => city == 'a'
          ? first.future
          : Future.value([
              const VenueLookupOption(id: 'db', name: 'Bursa district'),
            ]),
    );
    await tester.tap(find.text('Filtrele'));
    await tester.pumpAndSettle();
    final city = tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>).at(0),
        )
        .onChanged!;
    city('a');
    city('b');
    await tester.pumpAndSettle();
    first.complete([
      const VenueLookupOption(id: 'da', name: 'Ankara district'),
    ]);
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>).at(1),
    );
    expect(dropdown.items!.map((item) => item.value), ['db']);
  });

  testWidgets('filter reset discards late lookups and clears loading', (
    tester,
  ) async {
    final pending = Completer<List<VenueLookupOption>>();
    await openVenues(tester, districts: (_) => pending.future);
    await tester.tap(find.text('Filtrele'));
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>).first,
        )
        .onChanged!('a');
    await tester.pump();
    await tester.tap(find.text('Filtreyi sıfırla'));
    await tester.pump();
    expect(find.text('İlçe yükleniyor...'), findsNothing);
    pending.complete([const VenueLookupOption(id: 'late', name: 'Late')]);
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>).at(1),
    );
    expect(dropdown.items, isEmpty);
  });

  testWidgets('venue continue cannot stack two note dialogs', (tester) async {
    await openVenues(tester, districts: (_) async => []);
    await tester.tap(find.text('Venue'));
    await tester.pump();
    final action = tester
        .widget<GradientOutlineButton>(find.byType(GradientOutlineButton))
        .onPressed!;
    action();
    action();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog, skipOffstage: false), findsOneWidget);
  });

  for (final bandSearch in [true, false]) {
    Future<void> openNote(WidgetTester tester, List<Object?> delivered) async {
      if (bandSearch) {
        await openArtists(
          tester,
          (_) async => [artist],
          onResult: delivered.add,
        );
        await tester.enterText(find.byType(TextField), 'sah');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sahbaz'));
      } else {
        await openVenues(
          tester,
          districts: (_) async => [],
          onResult: delivered.add,
        );
        await tester.tap(find.text('Venue'));
      }
      await tester.pump();
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
    }

    for (final sendFirst in [true, false]) {
      testWidgets(
        '${bandSearch ? 'artist' : 'venue'} note ${sendFirst ? 'send' : 'cancel'} callbacks deliver one decision and cannot pop the underlying route',
        (tester) async {
          final delivered = <Object?>[];
          await openNote(tester, delivered);
          await tester.enterText(find.byType(TextFormField), '  note  ');
          final send = tester
              .widget<GradientOutlineButton>(
                find.descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(GradientOutlineButton),
                ),
              )
              .onPressed!;
          final cancel = tester
              .widget<OutlinedButton>(
                find.descendant(
                  of: find.byType(Dialog),
                  matching: find.widgetWithText(OutlinedButton, 'Vazgeç'),
                ),
              )
              .onPressed!;
          final navigator = Navigator.of(tester.element(find.byType(Dialog)));
          final decide = sendFirst ? send : cancel;
          decide();
          decide();
          (sendFirst ? cancel : send)();
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
          if (sendFirst) {
            expect(delivered, hasLength(1));
            final payload = delivered.single;
            if (bandSearch) {
              expect(
                (payload as ConnectedArtistRequestPayload).targetId,
                'band',
              );
              expect(payload.message, 'note');
            } else {
              expect((payload as VenueRequestPayload).venueId, 'venue');
              expect(payload.message, 'note');
            }
            expect(find.text('Devam'), findsNothing);
          } else {
            expect(delivered, isEmpty);
            expect(find.text('Devam'), findsOneWidget);
          }
          unawaited(
            navigator.push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('New route')),
              ),
            ),
          );
          await tester.pumpAndSettle();
          send();
          cancel();
          await tester.pumpAndSettle();
          expect(find.text('New route'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '${bandSearch ? 'artist' : 'venue'} covered note callbacks cannot pop a newer route',
      (tester) async {
        final delivered = <Object?>[];
        await openNote(tester, delivered);
        final send = tester
            .widget<GradientOutlineButton>(
              find.descendant(
                of: find.byType(Dialog),
                matching: find.byType(GradientOutlineButton),
              ),
            )
            .onPressed!;
        final cancel = tester
            .widget<OutlinedButton>(
              find.descendant(
                of: find.byType(Dialog),
                matching: find.widgetWithText(OutlinedButton, 'Vazgeç'),
              ),
            )
            .onPressed!;
        final navigator = Navigator.of(tester.element(find.byType(Dialog)));
        unawaited(
          navigator.push<void>(
            MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('New route')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        send();
        cancel();
        await tester.pumpAndSettle();
        expect(find.text('New route'), findsOneWidget);
        expect(delivered, isEmpty);
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        send();
        await tester.pumpAndSettle();
        expect(delivered, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${bandSearch ? 'artist' : 'venue'} overlong note stays editable instead of failing after submission',
      (tester) async {
        if (bandSearch) {
          await openArtists(tester, (_) async => [artist]);
          await tester.enterText(find.byType(TextField), 'sah');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Sahbaz'));
        } else {
          await openVenues(tester, districts: (_) async => []);
          await tester.tap(find.text('Venue'));
        }
        await tester.pump();
        await tester.tap(find.text('Devam'));
        await tester.pumpAndSettle();
        final draft = List.filled(256, 'a').join();
        await tester.enterText(find.byType(TextFormField), draft);
        await tester.tap(find.text('Gönder'));
        await tester.pumpAndSettle();
        expect(
          find.text('Not en fazla 255 karakter olabilir.'),
          findsOneWidget,
        );
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text(draft), findsOneWidget);
        await tester.enterText(
          find.byType(TextFormField),
          List.filled(255, 'a').join(),
        );
        await tester.tap(find.text('Gönder'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(find.text('Devam'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('search failure is distinguishable from no matching artist', (
    tester,
  ) async {
    await openArtists(tester, (_) async => throw StateError('offline'));
    await tester.enterText(find.byType(TextField), 'sah');
    await tester.pumpAndSettle();
    expect(find.text('Sanatçı araması yapılamadı.'), findsOneWidget);
    expect(find.text('Sonuç bulunamadı.'), findsNothing);
  });

  testWidgets(
    'wrong artist type and missing profile identity cannot be selected',
    (tester) async {
      await openArtists(
        tester,
        (_) async => [
          artist,
          const ProfileSearchResult(
            type: ProfileSearchResultType.listener,
            targetId: 'listener',
            userId: null,
            title: 'Listener',
            subtitle: null,
            imageUrl: null,
          ),
          const ProfileSearchResult(
            type: ProfileSearchResultType.musician,
            targetId: '',
            userId: null,
            title: 'Missing identity',
            subtitle: null,
            imageUrl: null,
          ),
        ],
      );
      await tester.enterText(find.byType(TextField), 'sah');
      await tester.pumpAndSettle();
      expect(find.text('Sahbaz'), findsOneWidget);
      expect(find.text('Listener'), findsNothing);
      expect(find.text('Missing identity'), findsNothing);
    },
  );

  testWidgets(
    'new city invalidates in-flight neighborhoods of the old district',
    (tester) async {
      final old = Completer<List<VenueLookupOption>>();
      await openVenues(
        tester,
        districts: (city) async => [
          VenueLookupOption(id: '$city-d', name: '$city district'),
        ],
        neighborhoods: (_) => old.future,
      );
      await tester.tap(find.text('Filtrele'));
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>).first,
          )
          .onChanged!('a');
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>).at(1),
          )
          .onChanged!('a-d');
      await tester.pump();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>).first,
          )
          .onChanged!('b');
      await tester.pumpAndSettle();
      old.complete([
        const VenueLookupOption(id: 'a-n', name: 'Old neighborhood'),
      ]);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byType(DropdownButton<String>).at(2),
            )
            .items,
        isEmpty,
      );
      expect(find.text('Semt yukleniyor...'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed location lookup displays retry guidance', (tester) async {
    await openVenues(
      tester,
      districts: (_) async => throw StateError('offline'),
    );
    await tester.tap(find.text('Filtrele'));
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>).first,
        )
        .onChanged!('a');
    await tester.pumpAndSettle();
    expect(
      find.text('İlçeler getirilemedi. Şehri yeniden seçerek tekrar dene.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('venue hidden by a new search is no longer silently submitted', (
    tester,
  ) async {
    await openVenues(tester, districts: (_) async => []);
    await tester.tap(find.text('Venue'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'other');
    await tester.pump();
    expect(
      tester
          .widget<GradientOutlineButton>(find.byType(GradientOutlineButton))
          .onPressed,
      isNull,
    );
  });
}
