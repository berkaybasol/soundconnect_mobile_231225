import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/marketplace_photo.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/media_access.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/media_gallery_repository.dart';
import 'package:soundconnect_23_12_25codx/shared/images/private_media_image_cache.dart';

import 'marketplace_photo_test_support.dart';
import 'marketplace_test_support.dart';

const _otherAsset = '99999999-9999-4999-8999-999999999999';

void main() {
  late MarketplaceTestSessions sessions;
  late MarketplacePhotoTestCache cache;
  late _Media media;

  setUp(() {
    sessions = MarketplaceTestSessions(marketSession());
    cache = MarketplacePhotoTestCache();
    media = _Media();
  });
  tearDown(() => sessions.dispose());

  Future<void> mount(
    WidgetTester tester, {
    String assetId = marketAssetId,
    bool original = false,
    bool moderator = false,
    BoxFit fit = BoxFit.cover,
    PrivateMediaImageCache? imageCache,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 80,
            child: MarketplacePhoto(
              assetId: assetId,
              sessions: sessions,
              repository: media,
              cache: imageCache ?? cache,
              preferOriginal: original,
              moderatorMode: moderator,
              fit: fit,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final sample in [
    (
      name: 'compact chooses protected thumbnail',
      original: false,
      thumbnail: true,
      variant: 'thumbnail',
    ),
    (
      name: 'detail explicitly chooses original',
      original: true,
      thumbnail: true,
      variant: 'original',
    ),
    (
      name: 'legacy asset falls back to original',
      original: false,
      thumbnail: false,
      variant: 'original',
    ),
  ]) {
    testWidgets(sample.name, (tester) async {
      media.reply = (id, _) async =>
          Result.success(_access(id, thumbnail: sample.thumbnail));
      await mount(tester, original: sample.original);
      expect(cache.loads.single.variant, sample.variant);
      expect(
        cache.loads.single.authorizedUrl,
        'https://storage.example.com/$marketAssetId/${sample.variant}.jpg?signature=fresh',
      );
      expect(cache.loads.single.accessScope, 'marketplace');
      final provider =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect(provider.imageProvider, isA<MemoryImage>());
      expect(provider.width, lessThanOrEqualTo(1600));
      expect(provider.height, lessThanOrEqualTo(1600));
      expect(provider.policy, ResizeImagePolicy.fit);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final dimensions in [const Size(600, 960), const Size(960, 600)]) {
    testWidgets(
      'cover keeps crop detail for ${dimensions.width}x${dimensions.height}',
      (tester) async {
        final bytes = await tester.runAsync(() => _solidPng(dimensions));
        cache.onLoad = (_) async => bytes!;
        media.reply = (id, _) async =>
            Result.success(_access(id, thumbnail: true));
        await mount(tester);
        final provider = tester.widget<Image>(find.byType(Image)).image;
        final decoded = await tester.runAsync(() => _decodedSize(provider));
        // Both source dimensions survive, so cover never upscales an axis that
        // the decoder first discarded to fit the card's different aspect ratio.
        expect(decoded, dimensions);
        expect(cache.loads.single.variant, 'thumbnail');
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('very tall legacy cover decode stays below both hard limits', (
    tester,
  ) async {
    final bytes = await tester.runAsync(() => _solidPng(const Size(240, 2400)));
    cache.onLoad = (_) async => bytes!;
    await mount(tester);
    final provider = tester.widget<Image>(find.byType(Image)).image;
    final decoded = await tester.runAsync(() => _decodedSize(provider));
    expect(decoded, const Size(160, 1600));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('contain detail still decodes only the visible pixel budget', (
    tester,
  ) async {
    final bytes = await tester.runAsync(() => _solidPng(const Size(600, 960)));
    cache.onLoad = (_) async => bytes!;
    await mount(tester, original: true, fit: BoxFit.contain);
    final provider =
        tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    final decoded = await tester.runAsync(() => _decodedSize(provider));
    final ratio = tester.view.devicePixelRatio;
    expect(decoded!.width, lessThanOrEqualTo(100 * ratio));
    expect(decoded.height, lessThanOrEqualTo(80 * ratio));
    expect(decoded.width / decoded.height, closeTo(600 / 960, 0.01));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each remount authorizes but encoded bytes download only once', (
    tester,
  ) async {
    var downloads = 0;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          downloads++;
          handler.resolve(
            Response<ResponseBody>(
              requestOptions: options,
              statusCode: 200,
              data: ResponseBody.fromBytes(
                marketplacePhotoPng,
                200,
                headers: {
                  Headers.contentTypeHeader: ['image/png'],
                },
              ),
              headers: Headers.fromMap({
                Headers.contentTypeHeader: ['image/png'],
              }),
            ),
          );
        },
      ),
    );
    final realCache = PrivateMediaImageCache(sessions: sessions, dio: dio);
    addTearDown(() {
      realCache.dispose();
      dio.close(force: true);
    });
    await mount(tester, imageCache: realCache);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, imageCache: realCache);
    expect(find.byType(Image), findsOneWidget);
    expect(media.requests, [marketAssetId, marketAssetId]);
    expect(downloads, 1);
    await tester.pumpWidget(const SizedBox());
    realCache.dispose();
  });

  testWidgets('cached bytes never bypass a denied fresh access grant', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    media.reply = (_, _) async => const Result.success(null);
    await mount(tester);
    expect(media.requests, hasLength(2));
    expect(cache.loads, hasLength(1));
    expect(cache.evictions, ['$marketAssetId:marketplace']);
    expect(find.byType(Image), findsNothing);
    expect(find.byTooltip('Fotoğrafı yeniden yükle'), findsOneWidget);
  });

  testWidgets('late old asset grant cannot replace the new asset', (
    tester,
  ) async {
    final first = Completer<Result<MediaAccess>>();
    media.reply = (id, _) => id == marketAssetId
        ? first.future
        : Future.value(Result.success(_access(id)));
    await mount(tester);
    await mount(tester, assetId: _otherAsset);
    first.complete(Result.success(_access(marketAssetId)));
    await tester.pump();
    expect(cache.loads.map((load) => load.assetId), [_otherAsset]);
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late old asset download cannot replace current pixels', (
    tester,
  ) async {
    final first = Completer<Uint8List>();
    cache.onLoad = (load) => load.assetId == marketAssetId
        ? first.future
        : Future.value(marketplacePhotoPng);
    await mount(tester);
    await mount(tester, assetId: _otherAsset);
    final current = tester.widget<Image>(find.byType(Image)).image;
    first.complete(Uint8List.fromList([0, 1, 2]));
    await tester.pump();
    expect(tester.widget<Image>(find.byType(Image)).image, current);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'background clears pixels and ignores late bytes before fresh resume access',
    (tester) async {
      final first = Completer<Uint8List>();
      cache.onLoad = (_) => cache.loads.length == 1
          ? first.future
          : Future.value(marketplacePhotoPng);
      await mount(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      first.complete(marketplacePhotoPng);
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(media.requests, hasLength(2));
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('account A to B to A cannot resurrect the old photo view', (
    tester,
  ) async {
    final pending = Completer<Uint8List>();
    cache.onLoad = (_) => pending.future;
    final entry = sessions.session;
    await mount(tester);
    sessions.replace(marketSession(userId: 'another-account'));
    sessions.replace(entry);
    pending.complete(marketplacePhotoPng);
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(media.requests, hasLength(1));
  });

  testWidgets('expiry removes pixels and requires a fresh grant', (
    tester,
  ) async {
    final renewal = Completer<Result<MediaAccess>>();
    media.reply = (id, count) => count == 1
        ? Future.value(
            Result.success(_access(id, lifetime: const Duration(seconds: 1))),
          )
        : renewal.future;
    await mount(tester);
    expect(find.byType(Image), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(Image), findsNothing);
    expect(media.requests, hasLength(2));
    renewal.complete(const Result.success(null));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'disposed view evicts its decoded image without discarding encoded bytes',
    (tester) async {
      await mount(tester);
      final provider = tester.widget<Image>(find.byType(Image)).image;
      final key = await provider.obtainKey(ImageConfiguration.empty);
      await tester.runAsync(() async {
        final ready = Completer<void>();
        final stream = provider.resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener((_, _) {
          if (!ready.isCompleted) ready.complete();
        });
        stream.addListener(listener);
        await ready.future;
        stream.removeListener(listener);
      });
      await tester.pump();
      expect(PaintingBinding.instance.imageCache.containsKey(key), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(PaintingBinding.instance.imageCache.containsKey(key), isFalse);
      expect(cache.evictions, isEmpty);
    },
  );

  testWidgets('session expiry closes pixels before a longer photo grant ends', (
    tester,
  ) async {
    final sessionExpiry = DateTime.now().add(const Duration(seconds: 1));
    sessions.replace(
      AuthSession.authenticated(
        token: 'short-session',
        userId: marketSellerId,
        username: 'musician',
        accountStatus: 'ACTIVE',
        roles: ['ROLE_MUSICIAN'],
        permissions: [],
        expiresAt: sessionExpiry,
        isAdmin: false,
      ),
    );
    await mount(tester);
    expect(find.byType(Image), findsOneWidget);
    expect(cache.loads.single.expiresAt, sessionExpiry);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(media.requests, hasLength(1));
  });

  testWidgets('moderator image uses its separate authorization scope', (
    tester,
  ) async {
    sessions.replace(
      AuthSession.authenticated(
        token: 'moderator-token',
        userId: 'moderator',
        username: 'moderator',
        accountStatus: 'ACTIVE',
        roles: ['ROLE_ADMIN'],
        permissions: ['MANAGE_MARKETPLACE_REPORTS'],
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        isAdmin: true,
      ),
    );
    await mount(tester, moderator: true);
    expect(cache.loads.single.accessScope, 'marketplace-moderator');
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await mount(tester);
    expect(media.requests, hasLength(1));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  testWidgets('listener is rejected before authorization or byte lookup', (
    tester,
  ) async {
    sessions.replace(marketSession(roles: ['ROLE_LISTENER']));
    await mount(tester, moderator: true);
    expect(media.requests, isEmpty);
    expect(cache.loads, isEmpty);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  testWidgets('late bytes after dispose produce no image or exception', (
    tester,
  ) async {
    final pending = Completer<Uint8List>();
    cache.onLoad = (_) => pending.future;
    await mount(tester);
    await tester.pumpWidget(const SizedBox());
    pending.complete(marketplacePhotoPng);
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<Uint8List> _solidPng(Size size) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<Size> _decodedSize(ImageProvider<Object> provider) async {
  final result = Completer<Size>();
  final stream = provider.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener(
    (info, _) {
      if (!result.isCompleted) {
        result.complete(
          Size(info.image.width.toDouble(), info.image.height.toDouble()),
        );
      }
      info.dispose();
    },
    onError: (Object error, StackTrace? stack) {
      if (!result.isCompleted) result.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  try {
    return await result.future;
  } finally {
    stream.removeListener(listener);
  }
}

MediaAccess _access(
  String id, {
  bool thumbnail = false,
  Duration lifetime = const Duration(minutes: 5),
}) {
  final expiry = DateTime.now().toUtc().add(lifetime);
  return MediaAccess(
    assetId: id,
    accessUrl: 'https://storage.example.com/$id/original.jpg?signature=fresh',
    expiresAt: expiry,
    thumbnailAccessUrl: thumbnail
        ? 'https://storage.example.com/$id/thumbnail.jpg?signature=fresh'
        : null,
    thumbnailExpiresAt: thumbnail ? expiry : null,
  );
}

class _Media implements MediaGalleryRepository {
  final requests = <String>[];
  Future<Result<MediaAccess>> Function(String id, int count) reply =
      (id, _) async => Result.success(_access(id));
  @override
  Future<Result<MediaAccess>> getAccess(String assetId) {
    requests.add(assetId);
    return reply(assetId, requests.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
