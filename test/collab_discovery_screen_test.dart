import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_creation_mock_data.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_mock_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_discovery_models.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_listing_draft.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_discovery_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  Widget app([CollabMockController? controller]) => MaterialApp(
    theme: AppTheme.navy,
    home: CollabDiscoveryScreen(
      controller: controller ?? CollabMockController(),
      showBottomNavigation: false,
    ),
  );

  testWidgets('opens with only extra listings and includes Studio', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Collab'), findsOneWidget);
    expect(find.text('Yakındaki ekstralar'), findsOneWidget);
    expect(find.text('Çarşamba gecesi bas gitarist arıyoruz'), findsOneWidget);
    expect(find.text('Moda Kayıt Stüdyosu'), findsOneWidget);
    expect(
      find.text('Düzenli sahne alabileceğimiz mekan arıyoruz'),
      findsNothing,
    );
  });

  testWidgets('cadence and direction filters only show matching listings', (
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
    expect(find.text('Çarşamba gecesi bas gitarist arıyoruz'), findsNothing);

    await tester.tap(find.text('Müsaitim'));
    await tester.pumpAndSettle();

    expect(find.text('Bu seçimlere uygun ilan bulunamadı.'), findsOneWidget);
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
      find.text('Konser ve kayıt projeleri için müsaitim'),
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
    capacity: 1,
    publisher: collabPublisherMockProfiles.first,
  );
}
