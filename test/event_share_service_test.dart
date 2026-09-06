import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_data.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_service.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('soundconnect_event_share_service_test');
  late Directory directory;
  late Uint8List png;
  late _RecordingScreenshot screenshot;
  late List<ShareParams> shares;
  late List<MethodCall> nativeCalls;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'soundconnect_event_share_test_',
    );
    png = await _png();
    screenshot = _RecordingScreenshot(png);
    shares = [];
    nativeCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call);
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  PlatformEventShareService service({
    EventShareMediaFileLoader? loader,
    EventShareImageResolver? resolver,
    Future<Directory> Function()? temporaryDirectory,
    TargetPlatform platform = TargetPlatform.windows,
    DateTime Function()? clock,
    String Function()? randomToken,
  }) => PlatformEventShareService(
    screenshotController: screenshot,
    channel: channel,
    mediaFileLoader:
        loader ?? (_, _) async => throw StateError('No network in tests'),
    imageResolver: resolver ?? (_, _) async => true,
    temporaryDirectory: temporaryDirectory ?? () async => directory,
    shareSender: (params) async {
      shares.add(params);
      return ShareResult.unavailable;
    },
    platform: platform,
    clock: clock,
    randomToken: randomToken,
  );

  testWidgets(
    'prepares the fixed 1080×1920 canvas after the brand asset resolves',
    (tester) async {
      final context = await _context(tester);
      final providers = <ImageProvider>[];
      final data = _data();
      final prepared = await tester.runAsync(
        () => service(
          resolver: (provider, _) async {
            providers.add(provider);
            return true;
          },
        ).prepare(context, data),
      );

      expect(screenshot.targetSize, const Size(360, 640));
      expect(screenshot.pixelRatio, 3);
      expect(screenshot.widget, isA<EventShareCard>());
      expect(
        providers.whereType<AssetImage>().map((provider) => provider.assetName),
        ['assets/logo.png'],
      );
      expect(prepared!.data, same(data));
      expect(prepared.bytes, png);
      expect(() => prepared.bytes[0] = 0, throwsUnsupportedError);
      expect(shares, isEmpty);
      expect(nativeCalls, isEmpty);
    },
  );

  testWidgets('failed brand decoding does not export an incomplete logo', (
    tester,
  ) async {
    final context = await _context(tester);
    await tester.runAsync(() async {
      await expectLater(
        service(resolver: (_, _) async => false).prepare(context, _data()),
        throwsStateError,
      );
    });
    expect(screenshot.widget, isNull);
  });

  testWidgets('remote URLs must be HTTP(S) without embedded credentials', (
    tester,
  ) async {
    final context = await _context(tester);
    var loadCalls = 0;
    await tester.runAsync(
      () =>
          service(
            loader: (_, _) async {
              loadCalls++;
              throw StateError('Unsafe URL reached loader');
            },
          ).prepare(
            context,
            _data(
              posterUrl: 'file:///private/event.png',
              avatarUrl: 'https://secret:password@example.com/avatar.png',
            ),
          ),
    );
    expect(loadCalls, 0);
    final card = screenshot.widget! as EventShareCard;
    expect(card.posterImage, isNull);
    expect(card.venueAvatar, isNull);
  });

  testWidgets('invalid and oversized remote media use local artwork', (
    tester,
  ) async {
    final context = await _context(tester);
    final invalid = File('${directory.path}/invalid.png')
      ..writeAsBytesSync([1, 2, 3]);
    final oversized = File('${directory.path}/large.png')
      ..writeAsBytesSync(Uint8List(2 * 1024 * 1024 + 1));
    await tester.runAsync(
      () =>
          service(
            loader: (_, profile) async =>
                profile == AppImageCacheProfile.original ? invalid : oversized,
          ).prepare(
            context,
            _data(
              posterUrl: 'https://example.com/broken.png',
              avatarUrl: 'https://example.com/large.png',
            ),
          ),
    );
    final card = screenshot.widget! as EventShareCard;
    expect(card.posterImage, isNull);
    expect(card.venueAvatar, isNull);
    expect(shares, isEmpty);
  });

  testWidgets('network failure of one image does not discard the other', (
    tester,
  ) async {
    final context = await _context(tester);
    final avatar = File('${directory.path}/avatar.png')..writeAsBytesSync(png);
    await tester.runAsync(
      () =>
          service(
            loader: (_, profile) async {
              if (profile == AppImageCacheProfile.original) {
                throw const SocketException('offline');
              }
              return avatar;
            },
          ).prepare(
            context,
            _data(
              posterUrl: 'https://example.com/poster.png',
              avatarUrl: 'https://example.com/avatar.png',
            ),
          ),
    );
    final card = screenshot.widget! as EventShareCard;
    expect(card.posterImage, isNull);
    expect(card.venueAvatar, isA<MemoryImage>());
  });

  testWidgets(
    'large decoded poster is downsampled without changing aspect ratio',
    (tester) async {
      final context = await _context(tester);
      await tester.runAsync(() async {
        final source = await File(
          '${directory.path}/poster.png',
        ).writeAsBytes(await _png(width: 2160, height: 1080));
        await service(
          loader: (_, _) async => source,
        ).prepare(context, _data(posterUrl: 'https://example.com/poster.png'));
        final provider =
            (screenshot.widget! as EventShareCard).posterImage! as MemoryImage;
        final codec = await ui.instantiateImageCodec(provider.bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 1080);
        expect(frame.image.height, 540);
        frame.image.dispose();
        codec.dispose();
      });
    },
  );

  testWidgets('capture output must be a PNG before preview can be used', (
    tester,
  ) async {
    final context = await _context(tester);
    screenshot = _RecordingScreenshot(Uint8List.fromList([1, 2, 3]));
    await tester.runAsync(() async {
      await expectLater(service().prepare(context, _data()), throwsStateError);
    });
  });

  testWidgets(
    'covered route during media preparation never captures a stale preview',
    (tester) async {
      final context = await _context(tester);
      final pendingFile = Completer<File>();
      late Future<void> rejected;
      await tester.runAsync(() async {
        final result = service(
          loader: (_, _) => pendingFile.future,
        ).prepare(context, _data(posterUrl: 'https://example.com/poster.png'));
        rejected = expectLater(result, throwsStateError);
      });
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Another page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      pendingFile.completeError(const SocketException('offline'));
      await tester.runAsync(() => rejected);
      expect(screenshot.widget, isNull);
    },
  );

  testWidgets(
    'system share receives the preview PNG with a real visible origin',
    (tester) async {
      final context = await _context(tester);
      final data = _data(eventId: '../../secret/unsafe');
      await tester.runAsync(
        () => service().share(
          context,
          PreparedEventShare(bytes: png, data: data),
          EventShareTarget.other,
        ),
      );
      expect(shares, hasLength(1));
      final params = shares.single;
      _expectStoreOnlyMessage(params.text, _neutralMessage, data);
      expect(params.subject, 'SoundConnect etkinliği');
      expect(params.files!.single.mimeType, 'image/png');
      final file = File(params.files!.single.path);
      expect(
        file.parent.path,
        '${directory.path}${Platform.pathSeparator}collab_share',
      );
      expect(
        file.uri.pathSegments.last,
        matches(RegExp(r'^event_\d+_[a-f0-9]{32}\.png$')),
      );
      expect(file.readAsBytesSync(), png);
      final box = context.findRenderObject()! as RenderBox;
      expect(
        params.sharePositionOrigin,
        box.localToGlobal(Offset.zero) & box.size,
      );
      expect(params.sharePositionOrigin!.width, greaterThan(1));
      expect(nativeCalls, isEmpty);
    },
  );

  for (final platform in TargetPlatform.values) {
    testWidgets(
      '${platform.name} system share uses only its store call to action',
      (tester) async {
        final context = await _context(tester);
        final data = _data();
        await tester.runAsync(
          () => service(platform: platform).share(
            context,
            PreparedEventShare(bytes: png, data: data),
            EventShareTarget.other,
          ),
        );
        final expected = switch (platform) {
          TargetPlatform.android => _googlePlayMessage,
          TargetPlatform.iOS => _appStoreMessage,
          _ => _neutralMessage,
        };
        expect(shares, hasLength(1));
        _expectStoreOnlyMessage(shares.single.text, expected, data);
        expect(shares.single.subject, 'SoundConnect etkinliği');
        expect(File(shares.single.files!.single.path).readAsBytesSync(), png);
        expect(nativeCalls, isEmpty);
      },
    );
  }

  testWidgets('iOS WhatsApp request uses App Store text in the system picker', (
    tester,
  ) async {
    final context = await _context(tester);
    final data = _data();
    await tester.runAsync(
      () => service(platform: TargetPlatform.iOS).share(
        context,
        PreparedEventShare(bytes: png, data: data),
        EventShareTarget.whatsapp,
      ),
    );
    expect(shares, hasLength(1));
    _expectStoreOnlyMessage(shares.single.text, _appStoreMessage, data);
    expect(shares.single.subject, 'SoundConnect etkinliği');
    expect(nativeCalls, isEmpty);
  });

  for (final target in [
    EventShareTarget.instagramStory,
    EventShareTarget.whatsapp,
  ]) {
    testWidgets('${target.name} uses existing Android image channel', (
      tester,
    ) async {
      final context = await _context(tester);
      await tester.runAsync(
        () => service(
          platform: TargetPlatform.android,
        ).share(context, PreparedEventShare(bytes: png, data: _data()), target),
      );
      expect(nativeCalls, hasLength(1));
      expect(nativeCalls.single.method, 'share');
      final arguments = nativeCalls.single.arguments as Map;
      expect(arguments['target'], target.name);
      expect(File(arguments['path'] as String).readAsBytesSync(), png);
      _expectStoreOnlyMessage(
        arguments['caption'] as String?,
        _googlePlayMessage,
        _data(),
      );
      expect(shares, isEmpty);
    });
  }

  for (final missingPlugin in [false, true]) {
    testWidgets(
      '${missingPlugin ? 'missing plugin' : 'app not installed'} falls back to image system picker',
      (tester) async {
        final context = await _context(tester);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async {
              if (missingPlugin) throw MissingPluginException();
              throw PlatformException(code: 'app_not_installed');
            });
        await tester.runAsync(
          () => service(platform: TargetPlatform.android).share(
            context,
            PreparedEventShare(bytes: png, data: _data()),
            EventShareTarget.whatsapp,
          ),
        );
        expect(shares, hasLength(1));
        expect(shares.single.files!.single.mimeType, 'image/png');
        _expectStoreOnlyMessage(
          shares.single.text,
          _googlePlayMessage,
          _data(),
        );
        expect(shares.single.subject, 'SoundConnect etkinliği');
      },
    );
  }

  testWidgets(
    'native failures are not silently reported as successful shares',
    (tester) async {
      final context = await _context(tester);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'share_failed'),
          );
      await tester.runAsync(() async {
        await expectLater(
          service(platform: TargetPlatform.android).share(
            context,
            PreparedEventShare(bytes: png, data: _data()),
            EventShareTarget.whatsapp,
          ),
          throwsA(isA<PlatformException>()),
        );
      });
      expect(shares, isEmpty);
    },
  );

  testWidgets('a covered route cannot open an external app', (tester) async {
    final context = await _context(tester);
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Another page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => service(platform: TargetPlatform.android).share(
        context,
        PreparedEventShare(bytes: png, data: _data()),
        EventShareTarget.whatsapp,
      ),
    );
    expect(nativeCalls, isEmpty);
    expect(shares, isEmpty);
    expect(Directory('${directory.path}/collab_share').existsSync(), isFalse);
  });

  testWidgets('unmount during file preparation cancels external sharing', (
    tester,
  ) async {
    final context = await _context(tester);
    final pendingDirectory = Completer<Directory>();
    late Future<void> result;
    await tester.runAsync(() async {
      result = service(temporaryDirectory: () => pendingDirectory.future).share(
        context,
        PreparedEventShare(bytes: png, data: _data()),
        EventShareTarget.other,
      );
    });
    await tester.pumpWidget(const SizedBox.shrink());
    pendingDirectory.complete(directory);
    await tester.runAsync(() => result);
    expect(nativeCalls, isEmpty);
    expect(shares, isEmpty);
  });

  testWidgets(
    'only expired generated event PNGs are cleaned; recent and collab files survive',
    (tester) async {
      final context = await _context(tester);
      final cache = Directory('${directory.path}/collab_share')..createSync();
      final now = DateTime(2026, 9, 6, 12);
      final expired = File('${cache.path}/event_1_${'a' * 32}.png')
        ..writeAsBytesSync(png);
      final recent = File('${cache.path}/event_2_${'b' * 32}.png')
        ..writeAsBytesSync(png);
      final collab = File('${cache.path}/collab_do_not_remove.png')
        ..writeAsBytesSync(png);
      final unrelated = File('${cache.path}/event_user_file.png')
        ..writeAsBytesSync(png);
      final nested = Directory('${cache.path}/nested')..createSync();
      final nestedFile = File('${nested.path}/event_3_${'c' * 32}.png')
        ..writeAsBytesSync(png);
      for (final file in [expired, collab, unrelated, nestedFile]) {
        file.setLastModifiedSync(now.subtract(const Duration(hours: 25)));
      }
      recent.setLastModifiedSync(now.subtract(const Duration(hours: 23)));
      await tester.runAsync(
        () => service(clock: () => now).share(
          context,
          PreparedEventShare(bytes: png, data: _data()),
          EventShareTarget.other,
        ),
      );
      expect(expired.existsSync(), isFalse);
      for (final file in [
        recent,
        collab,
        unrelated,
        nestedFile,
        File(shares.single.files!.single.path),
      ]) {
        expect(file.existsSync(), isTrue);
      }
    },
  );

  testWidgets(
    'invalid generated tokens cannot create paths or trigger sharing',
    (tester) async {
      final context = await _context(tester);
      await tester.runAsync(() async {
        await expectLater(
          service(randomToken: () => '../../outside').share(
            context,
            PreparedEventShare(bytes: png, data: _data()),
            EventShareTarget.other,
          ),
          throwsStateError,
        );
      });
      expect(shares, isEmpty);
    },
  );

  testWidgets('share cannot overwrite an existing generated filename', (
    tester,
  ) async {
    final context = await _context(tester);
    final sharer = service(
      clock: () => DateTime(2026, 9, 6),
      randomToken: () => 'd' * 32,
    );
    final prepared = PreparedEventShare(bytes: png, data: _data());
    await tester.runAsync(() async {
      await sharer.share(context, prepared, EventShareTarget.other);
      await expectLater(
        sharer.share(context, prepared, EventShareTarget.other),
        throwsA(isA<FileSystemException>()),
      );
    });
    expect(shares, hasLength(1));
    expect(File(shares.single.files!.single.path).readAsBytesSync(), png);
  });
}

EventShareData _data({
  String eventId = 'event-1',
  String? posterUrl,
  String? avatarUrl,
}) => EventShareData(
  eventId: eventId,
  title: 'M-T1 — Katıl, gösterme',
  description: 'Etkinlik hakkında kısa not',
  performerName: 'bugrasahin',
  performerLinked: false,
  venueName: 'soundconnectankara',
  location: 'Çankaya · Ankara',
  eventDate: DateTime(2026, 9, 6),
  startTime: '20:00',
  endTime: '22:00',
  posterUrl: posterUrl,
  venueAvatarUrl: avatarUrl,
  shareUrl: 'https://example.com/events/event-1',
);

const _googlePlayMessage =
    'Etkinlik detayları için:\n[Google Play URL’si buraya eklenecek]';
const _appStoreMessage =
    'Etkinlik detayları için:\n[App Store URL’si buraya eklenecek]';
const _neutralMessage =
    'Etkinlik detayları için:\n[Uygulama indirme URL’si buraya eklenecek]';

void _expectStoreOnlyMessage(
  String? message,
  String expected,
  EventShareData data,
) {
  expect(message, expected);
  for (final detail in [
    data.title,
    data.description,
    data.dateLabel,
    data.timeLabel,
    data.performerName,
    data.venueName,
    data.location,
    data.shareUrl!,
  ]) {
    expect(message, isNot(contains(detail)));
  }
}

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (value) {
              context = value;
              return const SizedBox(width: 200, height: 80);
            },
          ),
        ),
      ),
    ),
  );
  return context;
}

Future<Uint8List> _png({int width = 2, int height = 2}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const Color(0xFFEF7E88), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

class _RecordingScreenshot extends ScreenshotController {
  _RecordingScreenshot(this.result);
  final Uint8List result;
  Widget? widget;
  Size? targetSize;
  double? pixelRatio;

  @override
  Future<Uint8List> captureFromWidget(
    Widget widget, {
    Duration delay = const Duration(seconds: 1),
    double? pixelRatio,
    BuildContext? context,
    Size? targetSize,
  }) async {
    this.widget = widget;
    this.targetSize = targetSize;
    this.pixelRatio = pixelRatio;
    return result;
  }
}
