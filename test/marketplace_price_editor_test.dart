import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/screens/marketplace_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';

import 'marketplace_test_support.dart';

void main() {
  late MarketplaceFakeRepository repository;

  setUp(() async {
    await serviceLocator.reset();
    repository = MarketplaceFakeRepository();
    serviceLocator.registerSingleton<AuthSessionManager>(
      MarketplaceTestSessions(marketSession()),
      dispose: (value) => value.dispose(),
    );
    serviceLocator.registerSingleton<ProfileMediaUploadRepository>(
      MarketplaceFakeUploads(),
    );
  });

  tearDown(() async => serviceLocator.reset());

  Future<void> openEditor(WidgetTester tester, {bool existing = false}) async {
    if (existing) {
      repository.current = marketListing(status: 'DRAFT', isOwner: true);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceScreen(
          initialListingId: existing ? marketListingId : null,
          repository: repository,
          locationRepository: MarketplaceFakeLocations(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (existing) {
      await tester.scrollUntilVisible(
        find.text('Taslağı düzenle'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Taslağı düzenle'));
    } else {
      await tester.tap(find.byType(FloatingActionButton));
    }
    await tester.pumpAndSettle();
    await tester.ensureVisible(_priceField);
    await tester.pumpAndSettle();
  }

  Future<void> saveDraft(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Taslağı kaydet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taslağı kaydet'));
    await tester.pumpAndSettle();
    expect(repository.updates, 1);
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'new listing groups typed lira and saves the exact kuruş amount',
    (tester) async {
      await openEditor(tester);
      await tester.showKeyboard(_priceField);

      for (final digit in '12500'.split('')) {
        final text = _priceController(tester).text + digit;
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        );
        await tester.pump();
      }
      expect(_priceController(tester).text, '12.500');

      for (final character in ',50'.split('')) {
        final text = _priceController(tester).text + character;
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        );
        await tester.pump();
      }
      expect(_priceController(tester).text, '12.500,50');

      await saveDraft(tester);
      expect(repository.creates, 1);
      expect(repository.lastInput!.priceMinor, 1250050);
    },
  );

  testWidgets('existing listing shows grouped price and retains exact kuruş', (
    tester,
  ) async {
    await openEditor(tester, existing: true);

    expect(_priceController(tester).text, '28.500,50');
    await saveDraft(tester);

    expect(repository.creates, 0);
    expect(repository.lastInput!.priceMinor, 2850050);
  });
}

Finder get _priceField => find.byWidgetPredicate(
  (widget) =>
      widget is TextField && widget.decoration?.labelText == 'Fiyat (TL)',
);

TextEditingController _priceController(WidgetTester tester) =>
    tester.widget<TextField>(_priceField).controller!;
