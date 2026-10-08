import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/screens/marketplace_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/media_access.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/media_gallery_repository.dart';
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
    serviceLocator.registerSingleton<MediaGalleryRepository>(_Media());
  });

  tearDown(() async => serviceLocator.reset());

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceScreen(
          initialListingId: marketListingId,
          repository: repository,
          locationRepository: MarketplaceFakeLocations(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester) async {
    repository.current = marketListing(
      status: 'DRAFT',
      isOwner: true,
      photo: true,
    );
    await mount(tester);
    await _tapText(tester, 'Taslağı düzenle');
  }

  Future<void> openReport(WidgetTester tester) async {
    repository.current = marketListing(isOwner: false);
    await mount(tester);
    await _tapText(tester, 'İlanı şikâyet et');
  }

  void expectNoWrites() {
    expect(repository.creates, 0);
    expect(repository.updates, 0);
    expect(repository.reports, 0);
  }

  testWidgets(
    'publication counts emoji as code points for both minimum lengths',
    (tester) async {
      await openEditor(tester);
      await _enterText(tester, 'İlan başlığı', _repeat('🎸', 3));
      await _enterText(tester, 'Açıklama', _repeat('🎸', 5));

      await _tapText(tester, 'Önizle ve yayınla');
      expect(find.text('İlan önizlemesi'), findsNothing);
      expect(find.text('En az 5 karakterlik bir başlık yaz.'), findsOneWidget);
      expect(
        find.text('En az 10 karakterlik bir açıklama yaz.'),
        findsOneWidget,
      );
      expectNoWrites();

      await _enterText(tester, 'İlan başlığı', _repeat('🎸', 5));
      await _enterText(tester, 'Açıklama', _repeat('🎸', 9));
      await _tapText(tester, 'Önizle ve yayınla');
      expect(find.text('İlan önizlemesi'), findsNothing);
      expect(find.text('En az 5 karakterlik bir başlık yaz.'), findsNothing);
      expect(
        find.text('En az 10 karakterlik bir açıklama yaz.'),
        findsOneWidget,
      );
      expectNoWrites();

      await _enterText(tester, 'Açıklama', _repeat('🎸', 10));
      await _tapText(tester, 'Önizle ve yayınla');
      expect(find.text('İlan önizlemesi'), findsOneWidget);
      expectNoWrites();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'draft rejects combining sequences above every server text limit',
    (tester) async {
      await openEditor(tester);
      // Each accented letter is one grapheme but two database characters.
      // Flutter's built-in maxLength alone therefore accepts these inputs.
      const limits = {
        'İlan başlığı': 120,
        'Açıklama': 4000,
        'Marka': 80,
        'Model': 100,
      };
      for (final entry in limits.entries) {
        final controller = tester
            .widget<TextField>(_field(entry.key))
            .controller!;
        final original = controller.text;
        final overflowing = _repeat('a\u0301', entry.value ~/ 2 + 1);
        await _enterText(tester, entry.key, overflowing);
        expect(controller.text, overflowing);

        await _tapText(tester, 'Taslağı kaydet');
        expectNoWrites();
        expect(find.text('İlanı düzenle'), findsOneWidget);
        expect(
          find.text('En fazla ${entry.value} karakter yaz.'),
          findsOneWidget,
        );
        await _enterText(tester, entry.key, original);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('publication also rejects a combining-sequence title overflow', (
    tester,
  ) async {
    await openEditor(tester);
    await _enterText(tester, 'İlan başlığı', _repeat('a\u0301', 61));

    await _tapText(tester, 'Önizle ve yayınla');

    expect(find.text('İlan önizlemesi'), findsNothing);
    expect(find.text('En fazla 120 karakter yaz.'), findsOneWidget);
    expectNoWrites();
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft preserves emoji text at the exact maximum lengths', (
    tester,
  ) async {
    await openEditor(tester);
    final title = _repeat('🎸', 120);
    final brand = _repeat('🎸', 80);
    final model = _repeat('🎸', 100);
    await _enterText(tester, 'İlan başlığı', title);
    await _enterText(tester, 'Marka', brand);
    await _enterText(tester, 'Model', model);

    await _tapText(tester, 'Taslağı kaydet');

    expect(repository.creates, 0);
    expect(repository.updates, 1);
    expect(repository.lastInput!.title, title);
    expect(repository.lastInput!.brand, brand);
    expect(repository.lastInput!.model, model);
    expect(tester.takeException(), isNull);
  });

  testWidgets('other report rejects three emoji and accepts five', (
    tester,
  ) async {
    await openReport(tester);
    await _tapText(tester, 'Diğer');
    await _enterText(tester, 'Açıklama', _repeat('🎸', 3));

    await _tapText(tester, 'Şikâyeti gönder');
    expect(repository.reports, 0);
    expect(find.text('Şikâyet nedenini kısaca açıkla.'), findsOneWidget);

    await _enterText(tester, 'Açıklama', _repeat('🎸', 5));
    await _tapText(tester, 'Şikâyeti gönder');
    expect(repository.reports, 1);
    expect(find.text('Şikâyetin inceleme için alındı.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional report description enforces the code-point maximum', (
    tester,
  ) async {
    await openReport(tester);
    await _enterText(
      tester,
      'Açıklama (isteğe bağlı)',
      _repeat('a\u0301', 501),
    );

    await _tapText(tester, 'Şikâyeti gönder');
    expect(repository.reports, 0);
    expect(find.text('İncelememizi istediğin konuyu seç.'), findsOneWidget);
    expect(find.text('En fazla 1000 karakter yaz.'), findsOneWidget);

    await _enterText(tester, 'Açıklama (isteğe bağlı)', _repeat('🎸', 1000));
    await _tapText(tester, 'Şikâyeti gönder');
    expect(repository.reports, 1);
    expect(find.text('Şikâyetin inceleme için alındı.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

String _repeat(String text, int count) => List.filled(count, text).join();

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _enterText(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(_field(label));
  await tester.pumpAndSettle();
  await tester.enterText(_field(label), value);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      400,
      scrollable: find.byType(Scrollable).first,
    );
  }
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

class _Media implements MediaGalleryRepository {
  @override
  Future<Result<MediaAccess>> getAccess(String assetId) async =>
      const Result.failure(
        AppError(code: 'fixture', message: 'Photo placeholder'),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
