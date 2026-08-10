import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_creation_mock_data.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_mock_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_discovery_models.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_listing_draft.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_discovery_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/widgets/collab_discovery_widgets.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  Widget app([CollabMockController? controller]) => MaterialApp(
    theme: AppTheme.navy,
    home: CollabDiscoveryScreen(
      controller: controller ?? CollabMockController(),
      showBottomNavigation: false,
    ),
  );

  testWidgets('opens with regular listings selected', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('collab-brand-logo')),
      findsOneWidget,
    );
    expect(find.text('Collab'), findsNothing);
    expect(find.text('Ekibini ve fırsatını bul.'), findsNothing);
    expect(find.byIcon(Icons.tune_rounded), findsNothing);
    expect(
      tester
          .getCenter(
            find.byKey(const ValueKey<String>('collab-cadence-regular')),
          )
          .dx,
      lessThan(
        tester
            .getCenter(
              find.byKey(const ValueKey<String>('collab-cadence-extra')),
            )
            .dx,
      ),
    );
    expect(find.text('Düzenli fırsatlar'), findsOneWidget);
    expect(
      find.text('Düzenli sahne alabileceğimiz mekan arıyoruz'),
      findsOneWidget,
    );
    expect(find.text('Acoustic Route'), findsOneWidget);
    expect(find.text('Mekan arayan'), findsOneWidget);
    expect(find.text('Çarşamba gecesi bas gitarist arıyoruz'), findsNothing);
    expect(find.text('Mekandan'), findsNothing);
    expect(find.text('Stüdyodan'), findsNothing);
    expect(find.text('Arıyorum'), findsNothing);
    expect(find.text('Müsaitim'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(CollabListingCard),
        matching: find.text('Düzenli'),
      ),
      findsNothing,
    );
  });

  testWidgets('cadence and wanted filters only show matching listings', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('collab-cadence-regular')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Düzenli fırsatlar'), findsOneWidget);
    expect(find.text('Acoustic Route'), findsOneWidget);
    expect(find.text('Mekan arayan'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Mekan arayan')).dx,
      greaterThan(tester.getCenter(find.text('İstanbul Anadolu')).dx),
    );
    expect(find.text('Gruptan'), findsNothing);
    expect(find.text('Her Cuma'), findsNothing);
    expect(find.text('Akustik Grup'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(CollabListingCard),
        matching: find.text('Düzenli'),
      ),
      findsNothing,
    );
    expect(find.text('₺10.000'), findsNothing);
    expect(find.text('₺12.000'), findsOneWidget);
    expect(find.text('₺5.000'), findsNothing);
    expect(find.text('Çarşamba gecesi bas gitarist arıyoruz'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('collab-quick-wanted')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mekan arayan').last);
    await tester.pumpAndSettle();

    expect(find.text('Acoustic Route'), findsOneWidget);
    expect(find.text('Berlin Sahne'), findsNothing);
    expect(find.text('Northline Studio'), findsNothing);
  });

  testWidgets('musician board reveals specialty and publisher includes band', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('collab-quick-specialty')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey<String>('collab-quick-wanted')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Müzisyen arayan'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('collab-quick-specialty')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('collab-quick-publisher')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gruptan'), findsOneWidget);
  });

  testWidgets('search and bookmark are interactive', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Moda Kayıt');
    await tester.pumpAndSettle();

    expect(find.text('Moda Kayıt Stüdyosu'), findsOneWidget);
    expect(find.text('1 ilan'), findsOneWidget);

    await tester.tap(find.byTooltip('İlanı kaydet'));
    await tester.pump();

    expect(find.byTooltip('Kaydedilenlerden çıkar'), findsOneWidget);
  });

  testWidgets('keyword search includes genre and description', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'enerjisi yüksek');
    await tester.pumpAndSettle();
    expect(find.text('Çarşamba gecesi bas gitarist arıyoruz'), findsOneWidget);
    expect(find.text('1 ilan'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Soul');
    await tester.pumpAndSettle();
    expect(
      find.text('Yarınki kayıt için kadın vokalist arıyoruz'),
      findsOneWidget,
    );
    expect(
      find.text('Konser ve kayıt projelerinde yer almak istiyorum'),
      findsOneWidget,
    );
  });

  testWidgets('mounted discovery reacts when controller publishes a listing', (
    tester,
  ) async {
    final controller = CollabMockController();
    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();

    controller.publish(_listingDraft('Canlı akışta yeni Collab ilanı'));
    await tester.pump();

    expect(find.text('Canlı akışta yeni Collab ilanı'), findsOneWidget);
    expect(find.text('5 ilan'), findsOneWidget);
  });
}

CollabListingDraft _listingDraft(String title) {
  return CollabListingDraft(
    cadence: CollabCadence.extra,
    direction: CollabDirection.seeking,
    title: title,
    description:
        'Bu açıklama, oluşturulan ilanın test akışında görünmesi için yeterince uzundur.',
    location: 'Kadıköy, İstanbul',
    city: 'İstanbul',
    role: 'Bas Gitar',
    genres: const {'Funk'},
    occurrenceDate: DateTime.now().add(const Duration(days: 3)),
    occurrenceTime: const CollabClockTime(hour: 21, minute: 0),
    feeMode: CollabFeeMode.paid,
    feeAmount: 1500,
    publisher: collabPublisherMockProfiles.first,
  );
}
