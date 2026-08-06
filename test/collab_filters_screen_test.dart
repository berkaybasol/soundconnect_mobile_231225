import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_creation_mock_data.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_discovery_mock_data.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_mock_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_discovery_models.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_listing_draft.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_discovery_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_filters_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  Widget filtersApp() => MaterialApp(
    theme: AppTheme.navy,
    home: const CollabFiltersScreen(
      cadence: CollabCadence.extra,
      direction: null,
      initialFilter: CollabDiscoveryFilter(),
    ),
  );

  testWidgets('filter screen includes Studio and shows live result count', (
    tester,
  ) async {
    await tester.pumpWidget(filtersApp());
    await tester.pumpAndSettle();

    expect(find.text('Müzisyen, Grup, Mekan, Stüdyo'), findsOneWidget);
    expect(find.text('Sonuçları Göster (4)'), findsOneWidget);

    final profileKinds = find.byKey(
      const ValueKey<String>('collab-filter-profile-kinds'),
    );
    await tester.ensureVisible(profileKinds);
    await tester.tap(profileKinds);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tümünü temizle'));
    await tester.tap(find.text('Stüdyo'));
    await tester.tap(find.text('Seçimleri Uygula'));
    await tester.pumpAndSettle();

    expect(find.text('Sonuçları Göster (1)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Moda Kayıt Stüdyosu'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Moda Kayıt Stüdyosu'), findsOneWidget);
    expect(find.text('SoundConnect Kadıköy'), findsNothing);
  });

  testWidgets('fee filter finds only listings without a stated fee', (
    tester,
  ) async {
    await tester.pumpWidget(filtersApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Belirtilmemiş'));
    await tester.pumpAndSettle();

    expect(find.text('Sonuçları Göster (1)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('melisvocal'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('melisvocal'), findsOneWidget);
  });

  testWidgets('applied city filter returns to discovery and updates results', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: const CollabDiscoveryScreen(showBottomNavigation: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    final city = find.byKey(const ValueKey<String>('collab-filter-city'));
    await tester.ensureVisible(city);
    await tester.tap(city);
    await tester.pumpAndSettle();
    await tester.tap(find.text('İstanbul'));
    await tester.pumpAndSettle();
    final apply = find.text('Sonuçları Göster (3)');
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();

    expect(find.text('İstanbul'), findsOneWidget);
    expect(find.text('3 ilan'), findsOneWidget);
    expect(find.text('bugrasahin'), findsNothing);
  });

  testWidgets('back discards an un-applied filter change', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: const CollabDiscoveryScreen(showBottomNavigation: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    final city = find.byKey(const ValueKey<String>('collab-filter-city'));
    await tester.ensureVisible(city);
    await tester.tap(city);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ankara'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();

    expect(find.text('4 ilan'), findsOneWidget);
    expect(find.text('Şehir'), findsOneWidget);
  });

  testWidgets('regular filters hide and clear the one-off date range', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: CollabFiltersScreen(
          cadence: CollabCadence.regular,
          direction: null,
          initialFilter: CollabDiscoveryFilter(
            dateRange: CollabDateRange(
              start: DateTime(2026, 8, 1),
              end: DateTime(2026, 8, 31),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('collab-filter-date')),
      findsNothing,
    );
    expect(find.text('Sonuçları Göster (3)'), findsOneWidget);
  });

  testWidgets('filters include a listing published while discovery is open', (
    tester,
  ) async {
    final controller = CollabMockController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: CollabDiscoveryScreen(
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.publish(_listingDraft('Filtrede görünen yeni ilan'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Sonuçları Göster (5)'), findsOneWidget);
  });

  testWidgets('filter cards use the shared bookmark state', (tester) async {
    final controller = CollabMockController(
      savedListingIds: {'extra-venue-bass'},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: CollabFiltersScreen(
          cadence: CollabCadence.extra,
          direction: null,
          initialFilter: const CollabDiscoveryFilter(),
          sourceListings: collabDiscoveryMockListings,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final savedButton = find.byTooltip('Kaydedilenlerden çıkar');
    await tester.scrollUntilVisible(
      savedButton,
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(savedButton);
    await tester.pumpAndSettle();
    await tester.tap(savedButton);
    await tester.pump();

    expect(controller.isListingSaved('extra-venue-bass'), isFalse);
  });
}

CollabListingDraft _listingDraft(String title) {
  return CollabListingDraft(
    cadence: CollabCadence.extra,
    direction: CollabDirection.seeking,
    title: title,
    description:
        'Filtre ekranının oluşturulmuş ilanları da kapsadığını doğrulayan açıklama.',
    location: 'Kadıköy, İstanbul',
    city: 'İstanbul',
    role: 'Bas Gitar',
    genres: const {'Funk'},
    occurrenceDate: DateTime.now().add(const Duration(days: 4)),
    occurrenceTime: const CollabClockTime(hour: 20, minute: 30),
    feeMode: CollabFeeMode.paid,
    feeAmount: 1750,
    capacity: 1,
    publisher: collabPublisherMockProfiles.first,
  );
}
