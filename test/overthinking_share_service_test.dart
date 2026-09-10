import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_data.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_service.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('soundconnect_overthinking_share_service_test');
  late Directory directory;
  late Uint8List png;
  late _Screenshot screenshot;
  late List<ShareParams> shares;
  late List<MethodCall> nativeCalls;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('overthinking_export_');
    png = await _png();
    screenshot = _Screenshot(png);
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

  PlatformOverthinkingShareService service({
    OverthinkingShareMediaFileLoader? loader,
    OverthinkingShareImageResolver? resolver,
    Future<Directory> Function()? temporaryDirectory,
    TargetPlatform platform = TargetPlatform.windows,
    DateTime Function()? clock,
    String Function()? randomToken,
  }) => PlatformOverthinkingShareService(
    screenshotController: screenshot,
    channel: channel,
    mediaFileLoader:
        loader ?? (_, _) async => throw const SocketException('offline'),
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
    'preparation exports a 1080×1920 immutable preview, never shares',
    (tester) async {
      final context = await _context(tester);
      final resolved = <ImageProvider>[];
      final data = _data();
      final prepared = await tester.runAsync(
        () => service(
          resolver: (provider, _) async {
            resolved.add(provider);
            return true;
          },
        ).prepare(context, data),
      );
      expect(screenshot.widget, isA<OverthinkingShareCard>());
      expect(screenshot.targetSize, const Size(360, 640));
      expect(screenshot.pixelRatio, 3);
      expect(resolved.whereType<AssetImage>().map((p) => p.assetName), [
        'assets/Logoyanyana.png',
        'assets/logo.png',
      ]);
      expect(prepared!.data, same(data));
      final original = Uint8List.fromList(png);
      png[0] = 0;
      expect(prepared.bytes, original);
      expect(() => prepared.bytes[0] = 0, throwsUnsupportedError);
      expect(shares, isEmpty);
      expect(nativeCalls, isEmpty);
    },
  );

  testWidgets('a private identity grant never fetches or captures its avatar', (
    tester,
  ) async {
    final context = await _context(tester);
    final requested = <String>[];
    await tester.runAsync(
      () =>
          service(
            loader: (url, _) async {
              requested.add(url);
              throw const SocketException('offline');
            },
          ).prepare(
            context,
            _data(
              anonymous: true,
              avatar: 'https://example.test/private-author.png',
              album: 'https://i.scdn.co/image/album',
            ),
          ),
    );
    expect(requested, ['https://i.scdn.co/image/album']);
    final card = screenshot.widget! as OverthinkingShareCard;
    expect(card.data.authorLabel, 'Anonim yazar');
    expect(card.data.authorAvatarUrl, isNull);
    expect(card.authorAvatar, isNull);
  });

  testWidgets('missing music does not fetch a stale album cover', (
    tester,
  ) async {
    final context = await _context(tester);
    var loads = 0;
    await tester.runAsync(
      () =>
          service(
            loader: (_, _) async {
              loads++;
              throw StateError('Unexpected stale image');
            },
          ).prepare(
            context,
            _data(music: false, album: 'https://example.test/stale-album.png'),
          ),
    );
    expect(loads, 0);
    expect((screenshot.widget! as OverthinkingShareCard).albumImage, isNull);
  });

  testWidgets('invalid URLs never reach the media loader', (tester) async {
    final context = await _context(tester);
    var loads = 0;
    await tester.runAsync(
      () =>
          service(
            loader: (_, _) async {
              loads++;
              throw StateError('Unsafe media URL');
            },
          ).prepare(
            context,
            _data(
              avatar: 'https://password:secret@example.test/avatar.png',
              album: 'file:///private/album.png',
            ),
          ),
    );
    expect(loads, 0);
  });

  testWidgets('broken album media preserves a successfully decoded avatar', (
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
              avatar: 'https://example.test/avatar.png',
              album: 'https://i.scdn.co/image/album',
            ),
          ),
    );
    final card = screenshot.widget! as OverthinkingShareCard;
    expect(card.albumImage, isNull);
    expect(card.authorAvatar, isA<MemoryImage>());
  });

  testWidgets('oversized avatar and invalid album safely use local artwork', (
    tester,
  ) async {
    final context = await _context(tester);
    final album = File('${directory.path}/album.png')..writeAsBytesSync([1, 2]);
    final avatar = File('${directory.path}/avatar.png')
      ..writeAsBytesSync(Uint8List(2 * 1024 * 1024 + 1));
    await tester.runAsync(
      () =>
          service(
            loader: (_, profile) async =>
                profile == AppImageCacheProfile.original ? album : avatar,
          ).prepare(
            context,
            _data(
              avatar: 'https://example.test/avatar.png',
              album: 'https://i.scdn.co/image/album',
            ),
          ),
    );
    final card = screenshot.widget! as OverthinkingShareCard;
    expect(card.albumImage, isNull);
    expect(card.authorAvatar, isNull);
  });

  testWidgets('album artwork is downsampled to a bounded square', (
    tester,
  ) async {
    final context = await _context(tester);
    await tester.runAsync(() async {
      final source = await File(
        '${directory.path}/album.png',
      ).writeAsBytes(await _png(width: 2160, height: 2160));
      await service(
        loader: (_, _) async => source,
      ).prepare(context, _data(album: 'https://i.scdn.co/image/album'));
      final image =
          (screenshot.widget! as OverthinkingShareCard).albumImage!
              as MemoryImage;
      final codec = await ui.instantiateImageCodec(image.bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1080);
      expect(frame.image.height, 1080);
      frame.image.dispose();
      codec.dispose();
    });
  });

  testWidgets('failed required logo resolution refuses an incomplete export', (
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

  for (final invalid in [Uint8List(7), Uint8List(20 * 1024 * 1024 + 1)]) {
    testWidgets('invalid PNG length ${invalid.length} cannot be exported', (
      tester,
    ) async {
      final context = await _context(tester);
      screenshot = _Screenshot(invalid);
      await tester.runAsync(() async {
        await expectLater(
          service().prepare(context, _data()),
          throwsStateError,
        );
        await expectLater(
          service().share(
            context,
            PreparedOverthinkingShare(bytes: invalid, data: _data()),
            EventShareTarget.other,
          ),
          throwsStateError,
        );
      });
      expect(shares, isEmpty);
    });
  }

  testWidgets(
    'covering the route during loading cannot capture stale content',
    (tester) async {
      final context = await _context(tester);
      final pending = Completer<File>();
      late Future<void> rejected;
      await tester.runAsync(() async {
        rejected = expectLater(
          service(
            loader: (_, _) => pending.future,
          ).prepare(context, _data(album: 'https://i.scdn.co/image/album')),
          throwsStateError,
        );
      });
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Another page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      pending.completeError(const SocketException('offline'));
      await tester.runAsync(() => rejected);
      expect(screenshot.widget, isNull);
    },
  );

  testWidgets(
    'system share uses the exact image, scoped path and neutral caption',
    (tester) async {
      final context = await _context(tester);
      await tester.runAsync(
        () => service().share(
          context,
          PreparedOverthinkingShare(
            bytes: png,
            data: _data(id: '../../private'),
          ),
          EventShareTarget.other,
        ),
      );
      final params = shares.single;
      final file = File(params.files!.single.path);
      expect(file.readAsBytesSync(), png);
      expect(
        file.parent.path,
        endsWith('collab_share${Platform.pathSeparator}overthinking_shares'),
      );
      expect(
        file.uri.pathSegments.last,
        matches(RegExp(r'^overthinking_\d+_[a-f0-9]{32}\.png$')),
      );
      expect(params.files!.single.mimeType, 'image/png');
      expect(
        params.text,
        'SoundConnect’i indirmek için:\n[Google Play URL’si buraya eklenecek]',
      );
      expect(params.subject, 'SoundConnect Overthinking');
      expect(params.sharePositionOrigin!.width, greaterThan(1));
      expect(nativeCalls, isEmpty);
    },
  );

  for (final target in [
    EventShareTarget.instagramStory,
    EventShareTarget.whatsapp,
  ]) {
    testWidgets('${target.name} uses the existing Android image transport', (
      tester,
    ) async {
      final context = await _context(tester);
      await tester.runAsync(
        () => service(platform: TargetPlatform.android).share(
          context,
          PreparedOverthinkingShare(bytes: png, data: _data()),
          target,
        ),
      );
      expect(nativeCalls.single.method, 'share');
      final args = nativeCalls.single.arguments as Map;
      expect(args['target'], target.name);
      expect(
        args['caption'],
        'SoundConnect’i indirmek için:\n[Google Play URL’si buraya eklenecek]',
      );
      expect(File(args['path'] as String).readAsBytesSync(), png);
      expect(shares, isEmpty);
    });
  }

  for (final missingPlugin in [false, true]) {
    testWidgets(
      '${missingPlugin ? 'missing plugin' : 'missing app'} opens system picker',
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
            PreparedOverthinkingShare(bytes: png, data: _data()),
            EventShareTarget.whatsapp,
          ),
        );
        expect(File(shares.single.files!.single.path).readAsBytesSync(), png);
        expect(
          shares.single.text,
          'SoundConnect’i indirmek için:\n[Google Play URL’si buraya eklenecek]',
        );
      },
    );
  }

  testWidgets('unexpected native errors are surfaced instead of fake success', (
    tester,
  ) async {
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
          PreparedOverthinkingShare(bytes: png, data: _data()),
          EventShareTarget.whatsapp,
        ),
        throwsA(isA<PlatformException>()),
      );
    });
    expect(shares, isEmpty);
  });

  testWidgets('stale callers cannot create files or launch an app', (
    tester,
  ) async {
    final context = await _context(tester);
    await tester.runAsync(
      () => service().share(
        context,
        PreparedOverthinkingShare(bytes: png, data: _data()),
        EventShareTarget.other,
        isValid: () => false,
      ),
    );
    expect(directory.listSync(), isEmpty);
    expect(shares, isEmpty);
    expect(nativeCalls, isEmpty);
  });

  testWidgets('session invalidation during native lookup suppresses fallback', (
    tester,
  ) async {
    final context = await _context(tester);
    var valid = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          valid = false;
          throw PlatformException(code: 'app_not_installed');
        });
    await tester.runAsync(
      () => service(platform: TargetPlatform.android).share(
        context,
        PreparedOverthinkingShare(bytes: png, data: _data()),
        EventShareTarget.whatsapp,
        isValid: () => valid,
      ),
    );
    expect(shares, isEmpty);
  });

  testWidgets('unmount during file preparation cannot launch sharing', (
    tester,
  ) async {
    final context = await _context(tester);
    final pending = Completer<Directory>();
    late Future<void> result;
    await tester.runAsync(() async {
      result = service(temporaryDirectory: () => pending.future).share(
        context,
        PreparedOverthinkingShare(bytes: png, data: _data()),
        EventShareTarget.other,
      );
    });
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(directory);
    await tester.runAsync(() => result);
    expect(shares, isEmpty);
    expect(nativeCalls, isEmpty);
  });

  testWidgets(
    'cleanup owns only expired Overthinking files in its own folder',
    (tester) async {
      final context = await _context(tester);
      final root = Directory('${directory.path}/collab_share')..createSync();
      final cache = Directory('${root.path}/overthinking_shares')..createSync();
      final now = DateTime(2026, 9, 10, 18);
      File makeFile(String path, int hours) => File(path)
        ..writeAsBytesSync(png)
        ..setLastModifiedSync(now.subtract(Duration(hours: hours)));
      final expired = makeFile(
        '${cache.path}/overthinking_1_${'a' * 32}.png',
        25,
      );
      final survivors = [
        makeFile('${cache.path}/overthinking_2_${'b' * 32}.png', 23),
        makeFile('${cache.path}/overthinking_user_file.png', 25),
        makeFile('${cache.path}/event_3_${'c' * 32}.png', 25),
        makeFile('${root.path}/event_4_${'d' * 32}.png', 25),
        makeFile('${root.path}/overthinking_5_${'e' * 32}.png', 25),
      ];
      await tester.runAsync(
        () => service(clock: () => now).share(
          context,
          PreparedOverthinkingShare(bytes: png, data: _data()),
          EventShareTarget.other,
        ),
      );
      expect(expired.existsSync(), isFalse);
      for (final file in survivors) {
        expect(file.existsSync(), isTrue, reason: file.path);
      }
      expect(File(shares.single.files!.single.path).existsSync(), isTrue);
    },
  );

  testWidgets('a file cannot masquerade as the owned share directory', (
    tester,
  ) async {
    final context = await _context(tester);
    final root = Directory('${directory.path}/collab_share')..createSync();
    final blocker = File('${root.path}/overthinking_shares')
      ..writeAsBytesSync(png);
    await tester.runAsync(() async {
      await expectLater(
        service().share(
          context,
          PreparedOverthinkingShare(bytes: png, data: _data()),
          EventShareTarget.other,
        ),
        throwsA(isA<FileSystemException>()),
      );
    });
    expect(blocker.readAsBytesSync(), png);
    expect(shares, isEmpty);
  });

  testWidgets('unsafe tokens and duplicate filenames cannot overwrite files', (
    tester,
  ) async {
    final context = await _context(tester);
    final prepared = PreparedOverthinkingShare(bytes: png, data: _data());
    await tester.runAsync(() async {
      await expectLater(
        service(
          randomToken: () => '../../outside',
        ).share(context, prepared, EventShareTarget.other),
        throwsStateError,
      );
      final sharer = service(
        clock: () => DateTime(2026, 9, 10),
        randomToken: () => 'f' * 32,
      );
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

OverthinkingShareData _data({
  String id = 'post-1',
  bool anonymous = false,
  String? avatar,
  String? album,
  bool music = true,
}) => OverthinkingShareData.fromPost(
  OverthinkingPostModel.fromJson({
    'id': id,
    'authorId': 'author-1',
    'authorUsername': 'berna',
    'authorAvatarUrl': avatar,
    'canViewAuthor': true,
    'anonymous': anonymous,
    'visibilityType': anonymous ? 'ANONYMOUS' : 'VISIBLE',
    'title': 'Bir şarkının içinde',
    'content':
        'Bazı şarkılar bir yere götürmez. Olduğun yerde kalmana izin verir.',
    'spotifyTrackName': music ? 'Gece Yolculuğu' : null,
    'spotifyArtistName': music ? 'Kıyı' : null,
    'spotifyAlbumImageUrl': album,
  }),
);

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
  ui.Canvas(recorder).drawColor(const Color(0xFFEF7E88), ui.BlendMode.src);
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

class _Screenshot extends ScreenshotController {
  _Screenshot(this.result);
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
