import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/domain/marketplace_models.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/marketplace_access_gate.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/marketplace_photo.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/screens/marketplace_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/media_access.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/media_gallery_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';
import 'marketplace_test_support.dart';
import 'marketplace_photo_test_support.dart';

void main() {
  late MarketplaceTestSessions sessions;
  late MarketplaceFakeRepository repository;
  setUp(() async {
    await serviceLocator.reset();
    sessions = MarketplaceTestSessions(marketSession());
    repository = MarketplaceFakeRepository();
    serviceLocator.registerSingleton<AuthSessionManager>(
      sessions,
      dispose: (value) => value.dispose(),
    );
    serviceLocator.registerSingleton<ProfileMediaUploadRepository>(
      MarketplaceFakeUploads(),
    );
  });
  tearDown(() async {
    await serviceLocator.reset();
  });

  Future<void> home(
    WidgetTester tester, {
    _Observer? observer,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        navigatorObservers: [if (observer != null) observer],
        home: MarketplaceScreen(
          repository: repository,
          locationRepository: MarketplaceFakeLocations(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('listener cannot construct marketplace requests', (tester) async {
    sessions.replace(marketSession(roles: ['ROLE_LISTENER']));
    await home(tester);
    expect(repository.discoverCalls, 0);
    expect(
      find.text('Ekipman Pazarı bu oturumda kullanılamıyor.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'gate rejects same-frame stale actions and stays revoked through A-B-A',
    (tester) async {
      final first = sessions.session;
      var calls = 0;
      late VoidCallback captured;
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceAccessGate(
            builder: (context) {
              captured = () {
                if (marketplaceCanAct(context)) calls++;
              };
              return TextButton(onPressed: captured, child: const Text('Run'));
            },
          ),
        ),
      );
      sessions.replace(marketSession(userId: 'second'));
      captured();
      expect(calls, 0);
      sessions.replace(first);
      captured();
      expect(calls, 0);
      await tester.pump();
      expect(find.text('Run'), findsNothing);
    },
  );
  testWidgets(
    'old create callback cannot open an editor for another account before rebuild',
    (tester) async {
      final observer = _Observer();
      await home(tester, observer: observer);
      final callback = tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed!;
      sessions.replace(marketSession(userId: 'another-user'));
      callback();
      expect(observer.pushes, 1);
      expect(repository.creates, 0);
      await tester.pumpAndSettle();
      expect(
        find.text('Ekipman Pazarı bu oturumda kullanılamıyor.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'filter selections send NEW, district and exact minor-unit prices',
    (tester) async {
      await home(tester);
      await tester.tap(find.byTooltip('Filtreler ve sıralama'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tüm iller'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İstanbul'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tüm ilçeler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kadıköy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sıfır'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('En az ₺'), '1.250,50');
      await tester.enterText(_field('En çok ₺'), '2.000');
      await tester.ensureVisible(find.text('Sonuçları göster'));
      await tester.tap(find.text('Sonuçları göster'));
      await tester.pumpAndSettle();
      expect(repository.lastQuery!.condition, MarketplaceCondition.fresh);
      expect(repository.lastQuery!.districtId, marketDistrictId);
      expect(repository.lastQuery!.minPriceMinor, 125050);
      expect(repository.lastQuery!.maxPriceMinor, 200000);
      // Reopening and applying preserves the district selection.
      await tester.tap(find.byTooltip('Filtreler ve sıralama'));
      await tester.pumpAndSettle();
      expect(find.text('Kadıköy'), findsOneWidget);
      await tester.ensureVisible(find.text('Sonuçları göster'));
      await tester.tap(find.text('Sonuçları göster'));
      await tester.pumpAndSettle();
      expect(repository.lastQuery!.districtId, marketDistrictId);
    },
  );
  testWidgets(
    'home filters and nested pickers do not restore hidden search or price keyboards',
    (tester) async {
      await home(tester);
      final search = find.byType(TextField);
      await tester.enterText(search, 'Pedal');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final searchFocus = tester
          .widget<EditableText>(
            find.descendant(of: search, matching: find.byType(EditableText)),
          )
          .focusNode;
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Aramayı temizle'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(searchFocus.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byTooltip('Filtreler ve sıralama'));
      await tester.pumpAndSettle();

      for (final selection in {
        'Kategori': null,
        'İl': 'İstanbul',
        'İlçe': 'Kadıköy',
      }.entries) {
        final minimum = _field('En az ₺');
        await tester.ensureVisible(minimum);
        await tester.pumpAndSettle();
        await tester.enterText(minimum, '100');
        final priceFocus = tester
            .widget<EditableText>(
              find.descendant(of: minimum, matching: find.byType(EditableText)),
            )
            .focusNode;
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        expect(priceFocus.hasFocus, isTrue);
        final field = find
            .ancestor(
              of: find.text(selection.key),
              matching: find.byType(InkWell),
            )
            .first;
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.pumpAndSettle();
        if (selection.value == null) {
          await tester.tap(
            find.byKey(ValueKey('marketplace-category-$marketRootId')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(ValueKey('marketplace-category-$marketLeafId')),
          );
        } else {
          await tester.tap(find.text(selection.value!).last);
        }
        await tester.pumpAndSettle();
        expect(priceFocus.hasFocus, isFalse, reason: selection.key);
        expect(tester.testTextInput.isVisible, isFalse, reason: selection.key);
      }
      await tester.ensureVisible(find.text('Sonuçları göster'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sonuçları göster'));
      await tester.pumpAndSettle();
      expect(searchFocus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(repository.lastQuery!.search, isEmpty);
      expect(repository.lastQuery!.categoryId, marketLeafId);
      expect(repository.lastQuery!.cityId, marketCityId);
      expect(repository.lastQuery!.districtId, marketDistrictId);
      expect(repository.lastQuery!.minPriceMinor, 10000);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'home category sheets do not restore the hidden search keyboard when cancelled',
    (tester) async {
      await home(tester);
      for (final general in [true, false]) {
        final search = find.byType(TextField);
        await tester.enterText(search, 'Pedal');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        final focus = tester
            .widget<EditableText>(
              find.descendant(of: search, matching: find.byType(EditableText)),
            )
            .focusNode;
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        final entry = general
            ? find.byKey(const Key('marketplace-all-categories'))
            : find.text('Gitarlar');
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        await tester.tap(entry);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('marketplace-category-close')));
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(repository.lastQuery!.search, 'Pedal');
        expect(repository.lastQuery!.categoryId, isNull);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'returning from home destinations does not restore the hidden search keyboard',
    (tester) async {
      repository.current = marketListing();
      repository.listings = [repository.current];
      await home(tester);
      for (final destination in ['detail', 'editor', 'mine', 'saved']) {
        final search = find.byType(TextField);
        await tester.ensureVisible(search);
        await tester.pumpAndSettle();
        await tester.enterText(search, 'Pedal');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        final focus = tester
            .widget<EditableText>(
              find.descendant(of: search, matching: find.byType(EditableText)),
            )
            .focusNode;
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        final entry = switch (destination) {
          'detail' => find.text('Fender Player Stratocaster'),
          'editor' => find.byType(FloatingActionButton),
          'mine' => find.byTooltip('İlanlarım'),
          _ => find.byTooltip('Kaydettiklerim'),
        };
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        await tester.tap(entry);
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isFalse, reason: destination);
        expect(tester.testTextInput.isVisible, isFalse, reason: destination);
        expect(repository.lastQuery!.search, 'Pedal');
      }
      expect(repository.creates, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'category filter drills into a group and applies the selected product type',
    (tester) async {
      await home(tester);
      await tester.tap(find.byTooltip('Filtreler ve sıralama'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tüm kategoriler'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('marketplace-category-$marketLeafId')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(ValueKey('marketplace-category-$marketRootId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('marketplace-category-$marketLeafId')),
      );
      await tester.pumpAndSettle();
      expect(repository.lastQuery!.categoryId, isNull);
      await tester.ensureVisible(find.text('Sonuçları göster'));
      await tester.tap(find.text('Sonuçları göster'));
      await tester.pumpAndSettle();
      expect(repository.lastQuery!.categoryId, marketLeafId);
    },
  );
  testWidgets(
    'home category chip opens children and cancel leaves the query unchanged',
    (tester) async {
      await home(tester);
      final initialRequests = repository.discoverCalls;
      await tester.ensureVisible(find.text('Gitarlar'));
      await tester.tap(find.text('Gitarlar'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('marketplace-category-$marketLeafId')),
        findsOneWidget,
      );
      expect(repository.discoverCalls, initialRequests);
      await tester.tap(find.byKey(const Key('marketplace-category-close')));
      await tester.pumpAndSettle();
      expect(repository.lastQuery!.categoryId, isNull);
      expect(repository.discoverCalls, initialRequests);
      await tester.tap(find.text('Gitarlar'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('marketplace-category-branch-all')),
      );
      await tester.pumpAndSettle();
      expect(repository.lastQuery!.categoryId, marketRootId);
      expect(repository.discoverCalls, initialRequests + 1);
    },
  );
  testWidgets(
    'all categories button stays fixed while quick categories scroll on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repository = _ManyCategoriesRepository();
      await home(tester, textScaler: const TextScaler.linear(1.5));
      final all = find.byKey(const Key('marketplace-all-categories'));
      final quick = find.byKey(const Key('marketplace-quick-categories'));
      await tester.ensureVisible(all);
      await tester.pumpAndSettle();
      final initialRect = tester.getRect(all);
      final quickScrollable = find.descendant(
        of: quick,
        matching: find.byType(Scrollable),
      );
      final scroll = tester.state<ScrollableState>(quickScrollable);
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      await tester.drag(quick, const Offset(-450, 0));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(0));
      expect(tester.getRect(all), initialRect);
      expect(find.text('Kategoriler'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.text('Kategori seç'), findsOneWidget);
      expect(find.byKey(const Key('marketplace-category-all')), findsOneWidget);
      expect(
        find.byKey(ValueKey('marketplace-category-$marketLeafId')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'all categories opens at groups after a leaf selection and resets only category',
    (tester) async {
      await home(tester);
      await tester.enterText(find.byType(TextField), 'Fender');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filtreler ve sıralama'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tüm iller'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İstanbul'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tüm ilçeler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kadıköy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sıfır'));
      await tester.enterText(_field('En az ₺'), '1.250,50');
      await tester.enterText(_field('En çok ₺'), '2.000');
      final sort = find.text(MarketplaceSort.priceAscending.label);
      await tester.ensureVisible(sort);
      await tester.tap(sort);
      await tester.ensureVisible(find.text('Sonuçları göster'));
      await tester.tap(find.text('Sonuçları göster'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Gitarlar'));
      await tester.tap(find.text('Gitarlar'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('marketplace-category-$marketLeafId')),
      );
      await tester.pumpAndSettle();
      expect(repository.lastQuery!.categoryId, marketLeafId);
      expect(find.text('Gitarlar › Elektro Gitarlar'), findsOneWidget);
      final before = repository.lastQuery!.toJson();
      expect(
        before,
        const MarketplaceQuery(
          search: 'Fender',
          categoryId: marketLeafId,
          cityId: marketCityId,
          districtId: marketDistrictId,
          condition: MarketplaceCondition.fresh,
          minPriceMinor: 125050,
          maxPriceMinor: 200000,
          sort: MarketplaceSort.priceAscending,
        ).toJson(),
      );
      final requests = repository.discoverCalls;
      await tester.tap(find.byKey(const Key('marketplace-all-categories')));
      await tester.pumpAndSettle();
      final root = find.byKey(ValueKey('marketplace-category-$marketRootId'));
      expect(root, findsOneWidget);
      expect(tester.widget<ListTile>(root).selected, isTrue);
      expect(
        find.byKey(ValueKey('marketplace-category-$marketLeafId')),
        findsNothing,
      );
      expect(find.byKey(const Key('marketplace-category-back')), findsNothing);
      expect(repository.discoverCalls, requests);
      await tester.tap(find.byKey(const Key('marketplace-category-all')));
      await tester.pumpAndSettle();
      expect(repository.lastQuery!.categoryId, isNull);
      expect(repository.lastQuery!.toJson(), before..remove('categoryId'));
      expect(repository.discoverCalls, requests + 1);
      expect(find.text('Gitarlar › Elektro Gitarlar'), findsNothing);
    },
  );
  testWidgets(
    'editor uses one hierarchical picker and saves only the selected leaf',
    (tester) async {
      await home(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      final categoryField = find
          .ancestor(of: find.text('Kategori'), matching: find.byType(InkWell))
          .first;
      await tester.ensureVisible(categoryField);
      await tester.tap(categoryField);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('marketplace-category-all')), findsNothing);
      await tester.tap(
        find.byKey(ValueKey('marketplace-category-$marketRootId')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('marketplace-category-branch-all')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(ValueKey('marketplace-category-$marketLeafId')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Taslağı kaydet'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Taslağı kaydet'));
      await tester.pumpAndSettle();
      expect(repository.creates, 1);
      expect(repository.lastInput!.categoryId, marketLeafId);
    },
  );
  testWidgets(
    'draft save creates only on intent and permits incomplete publication fields',
    (tester) async {
      await home(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(repository.creates, 0);
      await tester.enterText(_field('İlan başlığı'), 'Pedal satılık');
      await tester.scrollUntilVisible(
        find.text('Taslağı kaydet'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Taslağı kaydet'));
      await tester.pumpAndSettle();
      expect(repository.creates, 1);
      expect(repository.updates, 1);
      expect(repository.lastInput!.title, 'Pedal satılık');
      expect(repository.lastInput!.condition, isNull);
      expect(repository.lastInput!.photoIds, isEmpty);
    },
  );
  testWidgets(
    'editor pickers and preview do not restore a hidden description keyboard',
    (tester) async {
      repository.current = marketListing(
        status: 'DRAFT',
        isOwner: true,
        photo: true,
      );
      final media = _Media();
      media.response.complete(
        const Result.failure(
          AppError(code: 'FIXTURE', message: 'Photo placeholder'),
        ),
      );
      serviceLocator.registerSingleton<MediaGalleryRepository>(media);
      await home(tester);
      await tester.tap(find.byTooltip('İlanlarım'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Fender Player Stratocaster'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fender Player Stratocaster'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Taslağı düzenle'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Taslağı düzenle'));
      await tester.pumpAndSettle();

      Future<FocusNode> focusThenHideKeyboard() async {
        final description = _field('Açıklama');
        await tester.ensureVisible(description);
        await tester.pumpAndSettle();
        await tester.tap(description);
        await tester.pumpAndSettle();
        final focus = tester
            .widget<EditableText>(
              find.descendant(
                of: description,
                matching: find.byType(EditableText),
              ),
            )
            .focusNode;
        expect(focus.hasFocus, isTrue);
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(focus.hasFocus, isTrue);
        return focus;
      }

      for (final selection in {
        'İl': 'İstanbul',
        'İlçe': 'Kadıköy',
        'Kategori': null,
      }.entries) {
        final focus = await focusThenHideKeyboard();
        final field = find
            .ancestor(
              of: find.text(selection.key),
              matching: find.byType(InkWell),
            )
            .first;
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(
          selection.value == null
              ? find.byKey(ValueKey('marketplace-category-$marketLeafId'))
              : find.text(selection.value!).last,
        );
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isFalse, reason: selection.key);
        expect(tester.testTextInput.isVisible, isFalse, reason: selection.key);
      }
      final focus = await focusThenHideKeyboard();
      await tester.tap(find.text('Önizle ve yayınla'));
      await tester.pumpAndSettle();
      expect(find.text('İlan önizlemesi'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(repository.updates, 0);
      expect(
        tester.widget<TextField>(_field('Açıklama')).controller!.text,
        repository.current.description,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'photo cover stays readable and order controls work at 320px with ${scale}x text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const secondAsset = '88888888-8888-4888-8888-888888888888';
        repository.current = MarketplaceListing.fromJson({
          ...marketListingJson(status: 'DRAFT', isOwner: true),
          'photos': [
            {'assetId': marketAssetId},
            {'assetId': secondAsset},
          ],
        });
        final media = _Media();
        media.response.complete(
          const Result.failure(
            AppError(code: 'FIXTURE', message: 'Photo placeholder'),
          ),
        );
        serviceLocator.registerSingleton<MediaGalleryRepository>(media);
        await home(tester, textScaler: TextScaler.linear(scale));
        await tester.tap(find.byTooltip('İlanlarım'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Fender Player Stratocaster'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fender Player Stratocaster'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Taslağı düzenle'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Taslağı düzenle'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Kapak'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final label = find.text('Kapak');
        expect(
          tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
          isFalse,
        );
        final labelRect = tester.getRect(label);
        final photoRect = tester.getRect(find.byType(MarketplacePhoto).first);
        expect(photoRect.contains(labelRect.topLeft), isTrue);
        expect(photoRect.contains(labelRect.bottomRight), isTrue);
        expect(
          labelRect.overlaps(
            tester.getRect(find.byTooltip('Fotoğrafı kaldır').first),
          ),
          isFalse,
        );
        for (final tooltip in ['Öne taşı', 'Arkaya taşı']) {
          final size = tester.getSize(find.byTooltip(tooltip).first);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        final next = find.byTooltip('Arkaya taşı').first;
        await tester.ensureVisible(next);
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MarketplacePhoto>(find.byType(MarketplacePhoto).first)
              .assetId,
          secondAsset,
        );
        final remove = find.byTooltip('Fotoğrafı kaldır').first;
        await tester.ensureVisible(remove);
        await tester.pumpAndSettle();
        await tester.tap(remove);
        await tester.pumpAndSettle();
        expect(find.byType(MarketplacePhoto), findsOneWidget);
        expect(find.text('Kapak'), findsOneWidget);
        await tester.tap(find.text('Taslağı kaydet'));
        await tester.pumpAndSettle();
        expect(repository.lastInput!.photoIds, [marketAssetId]);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('old contact callback cannot navigate after account switch', (
    tester,
  ) async {
    repository.current = marketListing();
    repository.listings = [repository.current];
    final observer = _Observer();
    await home(tester, observer: observer);
    await tester.ensureVisible(find.text('Fender Player Stratocaster'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fender Player Stratocaster'));
    await tester.pumpAndSettle();
    expect(find.text('İlan detayı'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Satıcıya yaz'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final button = tester.widget<GradientOutlineButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is GradientOutlineButton && widget.label == 'Satıcıya yaz',
      ),
    );
    final previous = observer.pushes;
    sessions.replace(marketSession(userId: 'another-user'));
    button.onPressed!();
    expect(observer.pushes, previous);
    await tester.pumpAndSettle();
  });
  testWidgets('private photo late response after logout never renders pixels', (
    tester,
  ) async {
    final media = _Media();
    final cache = MarketplacePhotoTestCache();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          height: 100,
          child: MarketplacePhoto(
            assetId: marketAssetId,
            repository: media,
            sessions: sessions,
            cache: cache,
          ),
        ),
      ),
    );
    sessions.replace(marketSession(roles: ['ROLE_LISTENER']));
    media.response.complete(
      Result.success(
        MediaAccess(
          assetId: marketAssetId,
          accessUrl: 'https://example.com/photo.jpg',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(cache.loads, isEmpty);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });
  testWidgets('private photo renders memory bytes and clears on background', (
    tester,
  ) async {
    final media = _Media();
    final cache = MarketplacePhotoTestCache();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          height: 100,
          child: MarketplacePhoto(
            assetId: marketAssetId,
            repository: media,
            sessions: sessions,
            cache: cache,
          ),
        ),
      ),
    );
    media.response.complete(
      Result.success(
        MediaAccess(
          assetId: marketAssetId,
          accessUrl: 'https://example.com/photo.jpg',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(provider.imageProvider, isA<MemoryImage>());
    expect(cache.loads, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.scheduleForcedFrame();
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    await tester.pumpWidget(const SizedBox());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

class _Observer extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

class _ManyCategoriesRepository extends MarketplaceFakeRepository {
  @override
  Future<Result<List<MarketplaceCategory>>> getCategories() async =>
      const Result.success([
        ...marketCategories,
        MarketplaceCategory(id: 'keys', code: 'keys', name: 'Klavye ve Piyano'),
        MarketplaceCategory(
          id: 'drums',
          code: 'drums',
          name: 'Davul ve Perküsyon',
        ),
        MarketplaceCategory(
          id: 'audio',
          code: 'audio',
          name: 'Ses Ekipmanları',
        ),
        MarketplaceCategory(id: 'stage', code: 'stage', name: 'Sahne ve Işık'),
      ]);
}

class _Media implements MediaGalleryRepository {
  final response = Completer<Result<MediaAccess>>();
  @override
  Future<Result<MediaAccess>> getAccess(String assetId) => response.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
