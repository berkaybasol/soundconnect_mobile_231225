import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/domain/marketplace_models.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/marketplace_photo.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/screens/marketplace_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/media_access.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_upload_result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/media_gallery_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'marketplace_test_support.dart';

const _secondPhoto = '99999999-9999-4999-8999-999999999999';
const _timeout = AppError(
  code: 'network_timeout',
  message: 'Bağlantı kesildi. Tekrar dene.',
);
const _conflict = AppError(
  code: '9943',
  message: 'İlan değişti. Güncel kaydı açıp tekrar dene.',
);

void main() {
  late MarketplaceTestSessions sessions;
  late _Repository repository;
  late _Uploads uploads;
  setUp(() async {
    await serviceLocator.reset();
    sessions = MarketplaceTestSessions(marketSession());
    repository = _Repository();
    uploads = _Uploads(repository);
    serviceLocator.registerSingleton<AuthSessionManager>(
      sessions,
      dispose: (value) => value.dispose(),
    );
    serviceLocator.registerSingleton<ProfileMediaUploadRepository>(uploads);
    serviceLocator.registerSingleton<MediaGalleryRepository>(_Media());
  });
  tearDown(() async => serviceLocator.reset());

  Future<void> mount(WidgetTester tester, {bool detail = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceScreen(
          initialListingId: detail ? marketListingId : null,
          repository: repository,
          locationRepository: MarketplaceFakeLocations(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> edit(WidgetTester tester) async {
    await mount(tester);
    await _tapText(
      tester,
      repository.current.status == MarketplaceStatus.draft
          ? 'Taslağı düzenle'
          : 'İlanı düzenle',
    );
  }

  testWidgets(
    'draft retry keeps request identity and ignores a same-frame double save',
    (tester) async {
      final first = Completer<Result<MarketplaceListing>>();
      repository.createReply = (_) => repository.createIds.length == 1
          ? first.future
          : Future.value(Result.success(repository.current));
      await mount(tester, detail: false);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(_field('İlan başlığı'), 'Taslak metni korunur');
      final save = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Taslağı kaydet'))
          .onPressed!;
      save();
      save();
      await tester.pump();
      expect(repository.createIds, hasLength(1));
      first.complete(const Result.failure(_timeout));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_field('İlan başlığı')).controller!.text,
        'Taslak metni korunur',
      );
      await _tapText(tester, 'Taslağı kaydet');
      expect(repository.createIds, hasLength(2));
      expect(repository.createIds.toSet(), hasLength(1));
      expect(repository.writes, hasLength(1));
      expect(repository.writes.single.input.title, 'Taslak metni korunur');
    },
  );

  testWidgets('same-frame publish callbacks open only one preview', (
    tester,
  ) async {
    await edit(tester);
    final action = tester
        .widget<GradientOutlineButton>(
          find.byWidgetPredicate(
            (w) => w is GradientOutlineButton && w.label == 'Önizle ve yayınla',
          ),
        )
        .onPressed!;
    action();
    action();
    await tester.pumpAndSettle();
    expect(find.text('İlan önizlemesi', skipOffstage: false), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(repository.writes, isEmpty);
    expect(
      tester
          .widget<GradientOutlineButton>(
            find.byWidgetPredicate(
              (w) =>
                  w is GradientOutlineButton && w.label == 'Önizle ve yayınla',
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'returning from preview keeps unsaved fields and photos without publishing',
    (tester) async {
      await edit(tester);
      const title = 'Önizlemeden sonra düzenlenen gitar';
      const description = 'Kılıfı ve askısı dahildir. Elden teslim edilebilir.';
      await tester.enterText(_field('İlan başlığı'), title);
      await tester.enterText(_field('Açıklama'), description);
      await tester.enterText(_field('Fiyat (TL)'), '12500,75');
      await _tapText(tester, 'Önizle ve yayınla');
      expect(find.text('İlan önizlemesi'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == title),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('12.500,75') ?? false),
        ),
        findsOneWidget,
      );

      await _tapText(tester, 'Düzenlemeye dön');
      expect(find.text('İlan önizlemesi'), findsNothing);
      expect(find.text('İlanı düzenle'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('İlan başlığı')).controller!.text,
        title,
      );
      expect(
        tester.widget<TextField>(_field('Açıklama')).controller!.text,
        description,
      );
      expect(
        tester.widget<TextField>(_field('Fiyat (TL)')).controller!.text,
        '12.500,75',
      );
      expect(
        tester.widget<MarketplacePhoto>(find.byType(MarketplacePhoto)).assetId,
        marketAssetId,
      );
      expect(repository.createIds, isEmpty);
      expect(repository.writes, isEmpty);
      expect(repository.transitions, isEmpty);
      expect(uploads.attemptedDeletes, isEmpty);

      const revisedTitle = 'Önizleme sonrası güncel gitar başlığı';
      await tester.enterText(_field('İlan başlığı'), revisedTitle);
      await _tapText(tester, 'Önizle ve yayınla');
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == revisedTitle),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('12.500,75') ?? false),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Düzenlemeye dön'));
      await tester.pumpAndSettle();
      expect(find.text('İlanı düzenle'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('İlan başlığı')).controller!.text,
        revisedTitle,
      );
      expect(repository.writes, isEmpty);
      expect(repository.transitions, isEmpty);
    },
  );

  testWidgets('same-frame preview return callbacks leave the editor open', (
    tester,
  ) async {
    await edit(tester);
    await _tapText(tester, 'Önizle ve yayınla');
    final returnFromFooter = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Düzenlemeye dön'))
        .onPressed!;
    final returnFromHeader = tester
        .widget<IconButton>(
          find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == 'Düzenlemeye dön',
          ),
        )
        .onPressed!;
    returnFromFooter();
    returnFromHeader();
    await tester.pumpAndSettle();
    expect(find.text('İlan önizlemesi'), findsNothing);
    expect(find.text('İlanı düzenle'), findsOneWidget);
    expect(_field('İlan başlığı'), findsOneWidget);
    expect(repository.writes, isEmpty);
    expect(repository.transitions, isEmpty);
  });

  testWidgets(
    'long preview keeps return and publish reachable on a small enlarged display',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await edit(tester);
      await tester.scrollUntilVisible(
        _field('Açıklama'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        _field('Açıklama'),
        List.filled(200, 'Ekipman açıklaması. ').join().padRight(4000, '.'),
      );
      await _tapText(tester, 'Önizle ve yayınla');
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Düzenlemeye dön').hitTestable(), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Düzenlemeye dön').hitTestable(),
        findsOneWidget,
      );
      expect(
        find
            .byWidgetPredicate(
              (w) => w is GradientOutlineButton && w.label == 'İlanı yayınla',
            )
            .hitTestable(),
        findsOneWidget,
      );
      await _tapText(tester, 'Düzenlemeye dön');
      expect(find.text('İlanı düzenle'), findsOneWidget);
      expect(repository.writes, isEmpty);
      expect(repository.transitions, isEmpty);
    },
  );

  testWidgets(
    'double preview confirmation publishes once and preserves the detail route',
    (tester) async {
      await edit(tester);
      await _tapText(tester, 'Önizle ve yayınla');
      final confirm = tester
          .widget<GradientOutlineButton>(
            find.byWidgetPredicate(
              (w) => w is GradientOutlineButton && w.label == 'İlanı yayınla',
            ),
          )
          .onPressed!;
      confirm();
      confirm();
      await tester.pumpAndSettle();
      expect(repository.transitions, hasLength(1));
      expect(find.text('İlan detayı'), findsOneWidget);
      expect(find.text('İlanın yayınlandı.'), findsOneWidget);
    },
  );

  testWidgets(
    'conflict preserves unsaved fields and referenced photos until explicit reload',
    (tester) async {
      repository.current = _listing(photos: [marketAssetId, _secondPhoto]);
      repository.updateReply = (_, _) async => const Result.failure(_conflict);
      await edit(tester);
      await tester.enterText(_field('İlan başlığı'), 'Yerel düzenlemem');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Fotoğrafı kaldır').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fotoğrafı kaldır').first);
      await tester.pumpAndSettle();
      await _tapText(tester, 'Taslağı kaydet');
      expect(uploads.tracked, contains(marketAssetId));
      expect(uploads.attemptedDeletes, isEmpty);
      expect(repository.writes.single.version, 2);
      await _tapText(tester, 'Sunucudaki güncel kaydı yükle');
      await tester.tap(find.text('Vazgeç').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_field('İlan başlığı')).controller!.text,
        'Yerel düzenlemem',
      );
      expect(find.byType(MarketplacePhoto), findsOneWidget);
      await _tapText(tester, 'Sunucudaki güncel kaydı yükle');
      await tester.tap(find.text('Güncel kaydı yükle').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_field('İlan başlığı')).controller!.text,
        'Fender Player Stratocaster',
      );
      expect(find.byType(MarketplacePhoto), findsNWidgets(2));
      expect(uploads.attemptedDeletes, [marketAssetId]);
      expect(uploads.deleted, isEmpty);
    },
  );

  testWidgets(
    'lost update reply reloads committed data and cleans only detached photos',
    (tester) async {
      repository.current = _listing(photos: [marketAssetId, _secondPhoto]);
      repository.updateReply = (input, version) async {
        repository.current = _listing(
          title: input.title,
          photos: input.photoIds,
          version: version + 1,
        );
        return const Result.failure(_timeout);
      };
      await edit(tester);
      await tester.enterText(
        _field('İlan başlığı'),
        'Sunucuda kaydedilmiş metin',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Fotoğrafı kaldır').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fotoğrafı kaldır').first);
      await tester.pumpAndSettle();
      await _tapText(tester, 'Taslağı kaydet');
      expect(repository.current.version, 3);
      expect(uploads.deleted, isEmpty);
      repository.updateReply = (_, _) async => const Result.failure(_conflict);
      await _tapText(tester, 'Taslağı kaydet');
      expect(repository.writes.map((write) => write.version), [2, 2]);
      await _tapText(tester, 'Sunucudaki güncel kaydı yükle');
      await tester.tap(find.text('Güncel kaydı yükle').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_field('İlan başlığı')).controller!.text,
        'Sunucuda kaydedilmiş metin',
      );
      expect(uploads.deleted, [marketAssetId]);
      expect(uploads.deleted, isNot(contains(_secondPhoto)));
      repository.updateReply = null;
      await _tapText(tester, 'Taslağı kaydet');
      expect(repository.writes.last.version, 3);
    },
  );

  testWidgets(
    'new upload stays protected when its committed update reply is lost',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'pickMultiImage');
        return [File('assets/logo.png').absolute.path];
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      repository.updateReply = (input, version) async {
        repository.current = _listing(
          photos: input.photoIds,
          title: input.title,
          version: version + 1,
        );
        return const Result.failure(_timeout);
      };
      await edit(tester);
      final picker = tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Fotoğraf ekle'),
          )
          .onPressed!;
      await tester.runAsync(() => (picker as Future<void> Function())());
      await tester.pumpAndSettle();
      expect(uploads.uploaded, [_secondPhoto]);
      expect(uploads.tracked, contains(_secondPhoto));
      await _tapText(tester, 'Taslağı kaydet');
      expect(repository.current.photoIds, [marketAssetId, _secondPhoto]);
      await _tapText(tester, 'Sunucudaki güncel kaydı yükle');
      await tester.tap(find.text('Güncel kaydı yükle').last);
      await tester.pumpAndSettle();
      expect(uploads.attemptedDeletes, [_secondPhoto]);
      expect(uploads.deleted, isEmpty);
      expect(find.byType(MarketplacePhoto), findsNWidgets(2));
    },
  );

  testWidgets(
    'lost publish reply reloads published state without another publish',
    (tester) async {
      repository.transitionReply = (_, version) async {
        repository.current = _listing(
          status: 'PUBLISHED',
          version: version + 1,
        );
        return const Result.failure(_timeout);
      };
      await edit(tester);
      await _tapText(tester, 'Önizle ve yayınla');
      await _tapText(tester, 'İlanı yayınla');
      expect(repository.current.status, MarketplaceStatus.published);
      await _tapText(tester, 'Sunucudaki güncel kaydı yükle');
      await tester.tap(find.text('Güncel kaydı yükle').last);
      await tester.pumpAndSettle();
      expect(find.text('Önizle ve yayınla'), findsNothing);
      expect(find.text('Değişiklikleri kaydet'), findsOneWidget);
      expect(repository.transitions, hasLength(1));
      await _tapText(tester, 'Değişiklikleri kaydet');
      expect(repository.writes.last.version, 4);
    },
  );

  testWidgets(
    'cleanup queue failure blocks mutation without deleting persisted photos',
    (tester) async {
      repository.current = _listing(photos: [marketAssetId, _secondPhoto]);
      uploads.failTracking = true;
      await edit(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Fotoğrafı kaldır').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fotoğrafı kaldır').first);
      await tester.pumpAndSettle();
      await _tapText(tester, 'Taslağı kaydet');
      expect(repository.writes, isEmpty);
      expect(uploads.deleted, isEmpty);
      expect(find.text('Fotoğraf değişikliği hazırlanamadı.'), findsOneWidget);
    },
  );

  testWidgets(
    'publish failure retains saved draft and retries from its newer version',
    (tester) async {
      repository.transitionReply = (_, _) async =>
          const Result.failure(_timeout);
      await edit(tester);
      await _tapText(tester, 'Önizle ve yayınla');
      await _tapText(tester, 'İlanı yayınla');
      expect(repository.writes.single.version, 2);
      expect(repository.transitions.single.version, 3);
      expect(find.text('Bağlantı kesildi. Tekrar dene.'), findsOneWidget);
      repository.transitionReply = null;
      await _tapText(tester, 'Önizle ve yayınla');
      await _tapText(tester, 'İlanı yayınla');
      expect(repository.writes.last.version, 3);
      expect(repository.transitions.last.version, 4);
      expect(repository.current.status, MarketplaceStatus.published);
    },
  );

  testWidgets(
    'same-frame status callbacks open one confirmation and cancellation unlocks detail',
    (tester) async {
      repository.current = _listing(status: 'PUBLISHED');
      await mount(tester);
      await tester.scrollUntilVisible(
        find.text('Yayından kaldır'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      final action = tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Yayından kaldır'),
          )
          .onPressed!;
      action();
      action();
      await tester.pumpAndSettle();
      expect(
        find.text('İlan yayından kaldırılsın mı?', skipOffstage: false),
        findsOneWidget,
      );
      await tester.tap(find.text('Vazgeç').last);
      await tester.pumpAndSettle();
      expect(repository.transitions, isEmpty);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Yayından kaldır'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'double status confirmation changes state once without leaving detail',
    (tester) async {
      repository.current = _listing(status: 'PUBLISHED');
      await mount(tester);
      await _tapText(tester, 'Yayından kaldır');
      final confirm = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Onayla'))
          .onPressed!;
      confirm();
      confirm();
      await tester.pumpAndSettle();
      expect(repository.transitions, hasLength(1));
      expect(repository.current.status, MarketplaceStatus.withdrawn);
      expect(find.text('İlan detayı'), findsOneWidget);
    },
  );

  testWidgets(
    'late report success cannot pop detail while its sheet is dismissing',
    (tester) async {
      repository.current = _listing(owner: false, status: 'PUBLISHED');
      final response = Completer<Result<void>>();
      repository.reportReply = () => response.future;
      await mount(tester);
      await _tapText(tester, 'İlanı şikâyet et');
      final send = tester
          .widget<GradientOutlineButton>(
            find.byWidgetPredicate(
              (w) => w is GradientOutlineButton && w.label == 'Şikâyeti gönder',
            ),
          )
          .onPressed!;
      send();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 30));
      response.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(find.text('İlan detayı'), findsOneWidget);
      expect(find.text('Şikâyetin inceleme için alındı.'), findsNothing);
    },
  );

  testWidgets(
    'bookmark timeout keeps UI stable and retry repeats the same desired state',
    (tester) async {
      repository.current = _listing(owner: false, status: 'PUBLISHED');
      final first = Completer<Result<void>>();
      repository.saveReply = (_) => repository.saves.length == 1
          ? first.future
          : Future.value(const Result.success(null));
      await mount(tester);
      final action = tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'İlanı kaydet',
            ),
          )
          .onPressed!;
      action();
      action();
      await tester.pump();
      expect(repository.saves, [true]);
      first.complete(const Result.failure(_timeout));
      await tester.pumpAndSettle();
      expect(find.byTooltip('İlanı kaydet'), findsOneWidget);
      await tester.tap(find.byTooltip('İlanı kaydet'));
      await tester.pumpAndSettle();
      expect(repository.saves, [true, true]);
      expect(find.byTooltip('Kayıttan çıkar'), findsOneWidget);
      await tester.tap(find.byTooltip('Kayıttan çıkar'));
      await tester.pumpAndSettle();
      expect(repository.saves, [true, true, false]);
      expect(find.byTooltip('İlanı kaydet'), findsOneWidget);
    },
  );

  testWidgets('same-frame report opening is single-flight', (tester) async {
    repository.current = _listing(owner: false, status: 'PUBLISHED');
    await mount(tester);
    await tester.scrollUntilVisible(
      find.text('İlanı şikâyet et'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    final action = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'İlanı şikâyet et'))
        .onPressed!;
    action();
    action();
    await tester.pumpAndSettle();
    expect(
      find.text('İncelememizi istediğin konuyu seç.', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets(
    'report retry reuses identity only while its submitted payload is unchanged',
    (tester) async {
      repository.current = _listing(owner: false, status: 'PUBLISHED');
      repository.reportReply = () async => const Result.failure(_timeout);
      await mount(tester);
      await _tapText(tester, 'İlanı şikâyet et');
      await _tapText(tester, 'Şikâyeti gönder');
      await _tapText(tester, 'Şikâyeti gönder');
      expect(repository.reportAttempts, hasLength(2));
      expect(repository.reportAttempts[1].id, repository.reportAttempts[0].id);
      await tester.enterText(
        _field('Açıklama (isteğe bağlı)'),
        'Yeni ve farklı açıklama',
      );
      await _tapText(tester, 'Şikâyeti gönder');
      expect(
        repository.reportAttempts[2].id,
        isNot(repository.reportAttempts[1].id),
      );
      expect(
        repository.reportAttempts.last.description,
        'Yeni ve farklı açıklama',
      );
    },
  );

  testWidgets(
    'other report validates description and ignores double send while pending',
    (tester) async {
      repository.current = _listing(owner: false, status: 'PUBLISHED');
      final response = Completer<Result<void>>();
      repository.reportReply = () => response.future;
      await mount(tester);
      await _tapText(tester, 'İlanı şikâyet et');
      await _tapText(tester, 'Diğer');
      await tester.enterText(_field('Açıklama'), 'abcd');
      await _tapText(tester, 'Şikâyeti gönder');
      expect(repository.reportAttempts, isEmpty);
      await tester.enterText(_field('Açıklama'), 'Yeterli açıklama');
      final send = tester
          .widget<GradientOutlineButton>(
            find.byWidgetPredicate(
              (w) => w is GradientOutlineButton && w.label == 'Şikâyeti gönder',
            ),
          )
          .onPressed!;
      send();
      send();
      await tester.pump();
      expect(repository.reportAttempts, hasLength(1));
      response.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(find.text('Şikâyetin inceleme için alındı.'), findsOneWidget);
      expect(find.text('İncelememizi istediğin konuyu seç.'), findsNothing);
    },
  );
}

Finder _field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

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

MarketplaceListing _listing({
  String title = 'Fender Player Stratocaster',
  String status = 'DRAFT',
  int version = 2,
  bool owner = true,
  List<String> photos = const [marketAssetId],
}) => MarketplaceListing.fromJson(
  marketListingJson(status: status, isOwner: owner)..addAll({
    'title': title,
    'version': version,
    'photos': [
      for (final id in photos) {'assetId': id},
    ],
  }),
);

typedef _Write = ({MarketplaceListingInput input, int version});

class _Repository extends MarketplaceFakeRepository {
  _Repository() {
    current = _listing();
  }
  final createIds = <String>[];
  final writes = <_Write>[];
  final transitions = <({String action, int version})>[];
  final saves = <bool>[];
  final reportAttempts = <({String id, String reason, String description})>[];
  Future<Result<MarketplaceListing>> Function(String id)? createReply;
  Future<Result<MarketplaceListing>> Function(
    MarketplaceListingInput input,
    int version,
  )?
  updateReply;
  Future<Result<MarketplaceListing>> Function(String action, int version)?
  transitionReply;
  Future<Result<void>> Function(bool saved)? saveReply;
  Future<Result<void>> Function()? reportReply;
  @override
  Future<Result<MarketplaceListing>> createDraft(String clientRequestId) async {
    createIds.add(clientRequestId);
    return createReply == null
        ? Result.success(current)
        : createReply!(clientRequestId);
  }

  @override
  Future<Result<MarketplaceListing>> updateListing(
    String id,
    MarketplaceListingInput input, {
    required int expectedVersion,
  }) async {
    writes.add((input: input, version: expectedVersion));
    if (updateReply != null) return updateReply!(input, expectedVersion);
    current = _listing(
      title: input.title,
      photos: input.photoIds,
      version: expectedVersion + 1,
      status: current.status.apiValue,
    );
    return Result.success(current);
  }

  @override
  Future<Result<MarketplaceListing>> transition(
    String id,
    String action, {
    required int expectedVersion,
  }) async {
    transitions.add((action: action, version: expectedVersion));
    if (transitionReply != null) {
      return transitionReply!(action, expectedVersion);
    }
    current = _listing(
      title: current.title,
      photos: current.photoIds,
      version: expectedVersion + 1,
      status: action == 'publish'
          ? 'PUBLISHED'
          : action == 'sold'
          ? 'SOLD'
          : 'WITHDRAWN',
    );
    return Result.success(current);
  }

  @override
  Future<Result<void>> setSaved(String id, bool saved) async {
    saves.add(saved);
    return saveReply == null ? const Result.success(null) : saveReply!(saved);
  }

  @override
  Future<Result<void>> report(
    String id, {
    required String reason,
    required String description,
    required String clientRequestId,
  }) async {
    reportAttempts.add((
      id: clientRequestId,
      reason: reason,
      description: description,
    ));
    return reportReply == null ? const Result.success(null) : reportReply!();
  }
}

class _Uploads extends MarketplaceFakeUploads {
  _Uploads(this.repository);
  final _Repository repository;
  bool failTracking = false;
  final tracked = <String>{};
  final attemptedDeletes = <String>[];
  final deleted = <String>[];
  final uploaded = <String>[];
  @override
  Future<Result<ProfileUploadedMedia>> uploadAsset({
    required ProfileUploadSource source,
    required String ownerType,
    required String ownerId,
    required String mediaKind,
    required String mimeType,
    required String originalFileName,
    String visibility = 'PUBLIC',
    String contentAudience = 'MAINSTAGE',
    ProfileUploadAttachmentIntent attachmentIntent =
        const ProfileUploadAttachmentIntent.none(),
    ProfileUploadProgress? onProgress,
    ProfileUploadStageChanged? onStageChanged,
    ProfileUploadCancellation? cancellation,
  }) async {
    expect(ownerType, 'MARKETPLACE');
    expect(ownerId, marketListingId);
    expect(visibility, 'PRIVATE');
    expect(contentAudience, 'BACKSTAGE');
    expect(attachmentIntent.type, ProfileUploadAttachmentType.draft);
    uploaded.add(_secondPhoto);
    return const Result.success(
      ProfileUploadedMedia(
        uuid: _secondPhoto,
        sourceUrl: null,
        playbackUrl: null,
        contentAudience: 'BACKSTAGE',
      ),
    );
  }

  @override
  Future<Result<void>> persistDraftCleanupIntent({
    required String assetId,
    required String ownerType,
    required String ownerId,
  }) async {
    tracked.add(assetId);
    return failTracking
        ? const Result.failure(
            AppError(
              code: 'io',
              message: 'Fotoğraf değişikliği hazırlanamadı.',
            ),
          )
        : const Result.success(null);
  }

  @override
  Future<Result<void>> clearDraftCleanupIntents(
    Iterable<String> assetIds,
  ) async {
    tracked.removeAll(assetIds);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> deleteOwnedAsset({
    required String assetId,
    required String ownerType,
    required String ownerId,
  }) async {
    attemptedDeletes.add(assetId);
    if (repository.current.photoIds.contains(assetId)) {
      return const Result.failure(
        AppError(code: '1823', message: 'Referenced'),
      );
    }
    deleted.add(assetId);
    return const Result.success(null);
  }
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
