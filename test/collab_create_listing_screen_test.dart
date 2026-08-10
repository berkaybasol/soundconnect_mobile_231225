import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_mock_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_listing_draft.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_create_listing_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  Widget app(Widget home) => MaterialApp(theme: AppTheme.navy, home: home);

  Future<void> goToInformation(WidgetTester tester) async {
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    expect(find.text('İlan Bilgileri'), findsWidgets);
  }

  Future<void> goToPreview(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('collab-create-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Önizleme'), findsWidgets);
  }

  testWidgets('creation starts with only the approved listing types', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        CollabCreateListingScreen(
          controller: CollabMockController(),
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('İlan Türü'), findsWidgets);
    expect(find.text('Ekstra'), findsOneWidget);
    expect(find.text('Düzenli'), findsOneWidget);
    expect(find.text('İlan Amacı'), findsNothing);
    expect(find.text('Birini veya Bir Yeri Bul'), findsNothing);
    expect(find.text('İş veya Proje Bul'), findsNothing);
    expect(find.text('Param Güvende'), findsOneWidget);
    expect(find.text('Yakında'), findsOneWidget);
    expect(find.textContaining('₺49'), findsNothing);
  });

  testWidgets('regular venue listing keeps an optional fee', (tester) async {
    await tester.pumpWidget(
      app(
        CollabCreateListingScreen(
          controller: CollabMockController(),
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Düzenli'));
    await goToInformation(tester);

    expect(find.text('Sahne Tarihi'), findsNothing);
    expect(find.text('Saat'), findsNothing);
    expect(find.text('Kontenjan'), findsNothing);
    expect(find.text('Ücret'), findsWidgets);
    expect(find.text('Tarz'), findsOneWidget);
    expect(find.text('Performans Süresi'), findsNothing);
    expect(find.text('Ekipman'), findsNothing);
    expect(find.text('Prova'), findsNothing);
    expect(find.text('Ulaşım'), findsNothing);
  });

  testWidgets('extra includes stage date and time without capacity', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        CollabCreateListingScreen(
          controller: CollabMockController(),
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await goToInformation(tester);

    expect(find.text('Sahne Tarihi'), findsOneWidget);
    expect(find.text('Saat'), findsOneWidget);
    expect(find.text('Kontenjan'), findsNothing);
    expect(find.text('Ücret'), findsWidgets);
  });

  testWidgets('studio publisher reaches preview with a single fee', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        CollabCreateListingScreen(
          controller: CollabMockController(),
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await goToInformation(tester);

    await tester.scrollUntilVisible(
      find.text('SoundConnect Kadıköy'),
      650,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('SoundConnect Kadıköy'));
    await tester.pumpAndSettle();
    expect(find.text('Northline Studio'), findsOneWidget);
    expect(find.text('Acoustic Route'), findsOneWidget);
    await tester.tap(find.text('Northline Studio'));
    await tester.pumpAndSettle();

    await goToPreview(tester);
    expect(find.text('Northline Studio'), findsWidgets);
    expect(find.text('Stüdyo'), findsWidgets);
    expect(find.text('₺1.500'), findsOneWidget);
    expect(find.textContaining('₺1.500 -'), findsNothing);
    expect(find.textContaining('/ saat'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Öne Çıkar'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Yakında'), findsOneWidget);
    expect(find.textContaining('₺49'), findsNothing);
  });

  testWidgets('publish adds the listing to feed and owned listings', (
    tester,
  ) async {
    final controller = CollabMockController();
    await tester.pumpWidget(app(_CreateListingHost(controller: controller)));
    await tester.tap(find.text('Oluşturmayı Aç'));
    await tester.pumpAndSettle();
    await goToInformation(tester);
    await goToPreview(tester);

    await tester.scrollUntilVisible(
      find.text('Yayınla'),
      600,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Yayınla'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(controller.createdListings, hasLength(1));
    expect(controller.ownedListings, hasLength(5));
    expect(find.text('published'), findsOneWidget);
  });

  testWidgets('saved draft restores fields and replaces itself on resave', (
    tester,
  ) async {
    final controller = CollabMockController();
    await tester.pumpWidget(
      app(
        _CreateListingHost(
          key: const ValueKey('new-draft-host'),
          controller: controller,
        ),
      ),
    );
    await tester.tap(find.text('Oluşturmayı Aç'));
    await tester.pumpAndSettle();
    await goToInformation(tester);

    const savedTitle = 'Esnek kayıt işleri için gitaristim';
    const savedDescription =
        'Stüdyo ve kayıt projelerinde elektro gitarist olarak yer alabilirim.';
    await tester.enterText(
      find.byKey(const ValueKey('collab-create-title')),
      savedTitle,
    );
    await tester.enterText(
      find.byKey(const ValueKey('collab-create-description')),
      savedDescription,
    );
    await tester.enterText(
      find.byKey(const ValueKey('collab-create-fee')),
      '2750',
    );
    await goToPreview(tester);
    await tester.scrollUntilVisible(
      find.text('Taslak Kaydet'),
      600,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Taslak Kaydet'));
    await tester.pumpAndSettle();

    expect(controller.drafts, hasLength(1));
    final savedDraft = controller.drafts.single;
    expect(savedDraft.title, savedTitle);
    expect(savedDraft.description, savedDescription);
    expect(savedDraft.feeAmount, 2750);

    await tester.pumpWidget(
      app(
        _CreateListingHost(
          key: const ValueKey('resumed-draft-host'),
          controller: controller,
          initialDraft: savedDraft,
        ),
      ),
    );
    await tester.tap(find.text('Oluşturmayı Aç'));
    await tester.pumpAndSettle();
    await goToInformation(tester);

    final titleField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('collab-create-title')),
    );
    final descriptionField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('collab-create-description')),
    );
    final feeField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('collab-create-fee')),
    );
    expect(titleField.controller?.text, savedTitle);
    expect(descriptionField.controller?.text, savedDescription);
    expect(feeField.controller?.text, '2750');

    const replacementTitle = 'Güncellenmiş gitarist ilanı';
    await tester.enterText(
      find.byKey(const ValueKey('collab-create-title')),
      replacementTitle,
    );
    await goToPreview(tester);
    await tester.scrollUntilVisible(
      find.text('Taslak Kaydet'),
      600,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Taslak Kaydet'));
    await tester.pumpAndSettle();

    expect(controller.drafts, hasLength(1));
    expect(controller.drafts.single.title, replacementTitle);
  });

  testWidgets('preview hides bookmark interaction', (tester) async {
    final controller = CollabMockController();
    await tester.pumpWidget(
      app(
        CollabCreateListingScreen(
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await goToInformation(tester);
    await goToPreview(tester);

    expect(find.byTooltip('İlanı kaydet'), findsNothing);
    expect(
      find.widgetWithIcon(IconButton, Icons.bookmark_border_rounded),
      findsNothing,
    );
  });

  testWidgets('all three creation steps fit a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = CollabMockController();

    await tester.pumpWidget(
      app(
        CollabCreateListingScreen(
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await goToInformation(tester);
    expect(tester.takeException(), isNull);
    await goToPreview(tester);
    expect(tester.takeException(), isNull);
  });
}

class _CreateListingHost extends StatefulWidget {
  const _CreateListingHost({
    required this.controller,
    this.initialDraft,
    super.key,
  });

  final CollabMockController controller;
  final CollabListingDraft? initialDraft;

  @override
  State<_CreateListingHost> createState() => _CreateListingHostState();
}

class _CreateListingHostState extends State<_CreateListingHost> {
  CollabCreateListingResult? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: result == null
            ? ElevatedButton(
                onPressed: () async {
                  final next = await Navigator.of(context)
                      .push<CollabCreateListingResult>(
                        MaterialPageRoute(
                          builder: (_) => CollabCreateListingScreen(
                            controller: widget.controller,
                            initialDraft: widget.initialDraft,
                            showBottomNavigation: false,
                          ),
                        ),
                      );
                  if (mounted) setState(() => result = next);
                },
                child: const Text('Oluşturmayı Aç'),
              )
            : Text(result!.name),
      ),
    );
  }
}
