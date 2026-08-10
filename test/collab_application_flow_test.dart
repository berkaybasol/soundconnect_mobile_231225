import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_application_mock_data.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_discovery_mock_data.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_mock_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_application_compose_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_listing_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_profile_selection_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  Widget app(Widget home) => MaterialApp(theme: AppTheme.navy, home: home);

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      400,
      scrollable: find.byType(Scrollable).last,
    );
  }

  testWidgets('profile selection uses rating and completed work only', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        CollabProfileSelectionScreen(
          listing: collabDiscoveryMockListings.first,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil Seç'), findsOneWidget);
    expect(find.text('bugrasahin'), findsOneWidget);
    expect(find.text('Acoustic Route'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('32'), findsOneWidget);
    expect(find.textContaining('Collab Puanı'), findsNothing);
    expect(find.textContaining('Doğrulan'), findsNothing);
  });

  testWidgets('seeking listing completes profile and application flow', (
    tester,
  ) async {
    final controller = CollabMockController();
    await tester.pumpWidget(
      app(
        CollabListingDetailScreen(
          listing: collabDiscoveryMockListings.first,
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Başvuru Yap'));
    await tester.tap(find.text('Başvuru Yap'));
    await tester.pumpAndSettle();

    expect(find.byType(CollabProfileSelectionScreen), findsOneWidget);
    await tester.tap(find.text('Acoustic Route'));
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();

    expect(find.byType(CollabApplicationComposeScreen), findsOneWidget);
    expect(find.text('Acoustic Route'), findsOneWidget);
    expect(find.text('+90 555 123 45 67'), findsOneWidget);
    expect(find.text('₺1.500'), findsOneWidget);
    expect(find.textContaining('₺1.500 -'), findsNothing);

    await scrollTo(tester, find.text('Başvuruyu Gönder'));
    await tester.tap(find.text('Başvuruyu Gönder'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(CollabListingDetailScreen), findsOneWidget);
    await scrollTo(tester, find.text('Başvuru Gönderildi'));
    expect(find.text('Başvuru Gönderildi'), findsOneWidget);
    expect(find.text('Başvurun mock olarak gönderildi.'), findsOneWidget);
  });

  testWidgets('musician listing uses the standard application flow', (
    tester,
  ) async {
    final controller = CollabMockController();
    await tester.pumpWidget(
      app(
        CollabListingDetailScreen(
          listing: collabDiscoveryMockListings[2],
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Başvuru Yap'));
    await tester.tap(find.text('Başvuru Yap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();

    expect(find.byType(CollabApplicationComposeScreen), findsOneWidget);
    expect(find.text('Başvuru Yap'), findsOneWidget);
    await scrollTo(tester, find.text('Başvuruyu Gönder'));
    expect(find.text('Başvuruyu Gönder'), findsOneWidget);
    expect(find.text('Teklifi Gönder'), findsNothing);
  });

  testWidgets('application form validates phone and a non-empty message', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        CollabApplicationComposeScreen(
          listing: collabDiscoveryMockListings.first,
          initialProfile: collabApplicantMockProfiles.first,
          initialPhoneNumber: '',
          initialMessage: '',
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Başvuruyu Gönder'));
    await tester.tap(find.text('Başvuruyu Gönder'));
    await tester.pump();

    expect(find.text('Geçerli bir telefon numarası gir.'), findsOneWidget);
    expect(find.text('Mesaj alanı boş bırakılamaz.'), findsOneWidget);
  });

  testWidgets('application phone rejects alphabetic characters', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        CollabApplicationComposeScreen(
          listing: collabDiscoveryMockListings.first,
          initialProfile: collabApplicantMockProfiles.first,
          initialPhoneNumber: 'abc5551234567xyz',
          initialMessage:
              'İlanınızla ilgileniyorum ve detayları konuşabiliriz.',
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Başvuruyu Gönder'));
    await tester.tap(find.text('Başvuruyu Gönder'));
    await tester.pump();

    expect(find.text('Geçerli bir telefon numarası gir.'), findsOneWidget);
  });

  testWidgets('profile and application screens fit a phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      app(
        CollabProfileSelectionScreen(
          listing: collabDiscoveryMockListings.first,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('application-viewport-app'),
        theme: AppTheme.navy,
        home: CollabApplicationComposeScreen(
          listing: collabDiscoveryMockListings.first,
          initialProfile: collabApplicantMockProfiles.first,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(Scrollable).last,
      const Offset(0, -900),
      1000,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
