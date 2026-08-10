import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_discovery_mock_data.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_management_mock_data.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_mock_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_discovery_models.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_discovery_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_listing_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  Widget detailApp(int listingIndex) => MaterialApp(
    theme: AppTheme.navy,
    home: CollabListingDetailScreen(
      listing: collabDiscoveryMockListings[listingIndex],
      controller: CollabMockController(),
      showBottomNavigation: false,
    ),
  );

  Widget detailAppForListing(CollabDiscoveryListing listing) => MaterialApp(
    theme: AppTheme.navy,
    home: CollabListingDetailScreen(
      listing: listing,
      controller: CollabMockController(),
      showBottomNavigation: false,
    ),
  );

  testWidgets('seeking detail keeps only the approved job information', (
    tester,
  ) async {
    await tester.pumpWidget(detailApp(0));
    await tester.pumpAndSettle();

    expect(find.text('Çarşamba gecesi bas gitarist arıyoruz'), findsOneWidget);
    expect(find.text('Bas Gitar'), findsWidgets);
    expect(find.text('Ücret'), findsOneWidget);
    expect(find.text('₺1.500'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Başvuru Yap'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Başvuru Yap'), findsOneWidget);
    expect(find.text('İş Teklifi Gönder'), findsNothing);
    expect(find.text('Funk, Rock, Alternatif'), findsOneWidget);
    expect(find.text('4.8 / 5'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);

    expect(find.text('Performans Süresi'), findsNothing);
    expect(find.text('Ekipman'), findsNothing);
    expect(find.text('Prova'), findsNothing);
    expect(find.text('Ulaşım'), findsNothing);
    expect(find.textContaining('Collab Puanı'), findsNothing);
  });

  testWidgets('musician listing uses the standard application action', (
    tester,
  ) async {
    await tester.pumpWidget(detailApp(2));
    await tester.pumpAndSettle();

    expect(find.text('Stüdyo arayan'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Başvuru Yap'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Başvuru Yap'), findsOneWidget);
    expect(find.text('İş Teklifi Gönder'), findsNothing);
  });

  testWidgets('regular detail omits fee information', (tester) async {
    await tester.pumpWidget(detailApp(4));
    await tester.pumpAndSettle();

    expect(find.text('₺10.000'), findsNothing);
    expect(find.text('Ücret'), findsNothing);
    expect(find.text('Her Cuma'), findsNothing);
  });

  testWidgets('regular venue detail shows fee when it was provided', (
    tester,
  ) async {
    await tester.pumpWidget(detailApp(5));
    await tester.pumpAndSettle();

    expect(find.text('Ücret'), findsOneWidget);
    expect(find.text('₺12.000'), findsOneWidget);
    expect(find.text('Her Cuma'), findsNothing);
  });

  testWidgets('regular venue detail states when fee was not provided', (
    tester,
  ) async {
    final listing = collabDiscoveryMockListings[5].copyWith(
      clearFeeAmount: true,
    );
    await tester.pumpWidget(detailAppForListing(listing));
    await tester.pumpAndSettle();

    expect(find.text('Ücret'), findsOneWidget);
    expect(find.text('Ücret belirtilmemiş'), findsOneWidget);
  });

  testWidgets('bookmark state stays synchronized with discovery', (
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

    await tester.tap(find.text('Çarşamba gecesi bas gitarist arıyoruz'));
    await tester.pumpAndSettle();
    expect(find.byType(CollabListingDetailScreen), findsOneWidget);

    await tester.tap(find.byTooltip('İlanı kaydet'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byTooltip('Kaydedilenlerden çıkar'), findsOneWidget);
  });

  testWidgets('listing owner sees edit instead of an application action', (
    tester,
  ) async {
    final controller = CollabMockController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: CollabListingDetailScreen(
          listing: collabOwnedMockListings.first.listing,
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('İlanı Düzenle'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('İlanı Düzenle'), findsOneWidget);
    expect(find.text('Başvuru Yap'), findsNothing);
    expect(find.text('İş Teklifi Gönder'), findsNothing);
  });
}
