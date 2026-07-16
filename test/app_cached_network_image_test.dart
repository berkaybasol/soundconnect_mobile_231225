import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';

void main() {
  late io.Directory temporaryDirectory;
  late File validImageFile;

  setUp(() async {
    temporaryDirectory = await io.Directory.systemTemp.createTemp(
      'soundconnect-image-test-',
    );
    validImageFile = const LocalFileSystem().file(
      '${temporaryDirectory.path}${io.Platform.pathSeparator}pixel.png',
    );
    await validImageFile.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
        'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  testWidgets('renders a file returned by the persistent cache', (
    tester,
  ) async {
    const url = 'https://cdn.soundconnect.test/avatar.png';
    final cache = _FakeCacheManager();

    await tester.pumpWidget(
      MaterialApp(
        home: AppCachedNetworkImage(
          imageUrl: url,
          width: 48,
          height: 48,
          cacheManager: cache,
        ),
      ),
    );
    cache.emitFile(url, validImageFile);
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(cache.requestedUrls, <String>[url]);
    expect(cache.withProgressValues, <bool>[true]);
  });

  testWidgets('subscribes to the new URL when the widget updates', (
    tester,
  ) async {
    const firstUrl = 'https://cdn.soundconnect.test/first.png';
    const secondUrl = 'https://cdn.soundconnect.test/second.png';
    final cache = _FakeCacheManager();

    await tester.pumpWidget(
      MaterialApp(
        home: AppCachedNetworkImage(imageUrl: firstUrl, cacheManager: cache),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppCachedNetworkImage(imageUrl: secondUrl, cacheManager: cache),
      ),
    );
    cache.emitFile(secondUrl, validImageFile);
    await tester.pump();

    expect(cache.requestedUrls, <String>[firstUrl, secondUrl]);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('progress placeholder preserves the requested dimensions', (
    tester,
  ) async {
    const url = 'https://cdn.soundconnect.test/progress.png';
    final cache = _FakeCacheManager();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AppCachedNetworkImage(
            imageUrl: url,
            width: 120,
            height: 80,
            cacheManager: cache,
          ),
        ),
      ),
    );
    cache.emit(url, const DownloadProgress(url, 100, 50));
    await tester.pump();

    final placeholder = find.byKey(
      const ValueKey('app_cached_network_image.placeholder'),
    );
    expect(placeholder, findsOneWidget);
    expect(tester.getSize(placeholder), const Size(120, 80));
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, 0.5);
  });

  testWidgets('invalid URLs render a dimensioned stable error fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: AppCachedNetworkImage(
            imageUrl: 'file:///private/image.jpg',
            width: 64,
            height: 32,
          ),
        ),
      ),
    );

    final fallback = find.byKey(
      const ValueKey('app_cached_network_image.error'),
    );
    expect(fallback, findsOneWidget);
    expect(tester.getSize(fallback), const Size(64, 32));
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('stream failures render the error fallback', (tester) async {
    const url = 'https://cdn.soundconnect.test/failure.png';
    final cache = _FakeCacheManager();

    await tester.pumpWidget(
      MaterialApp(
        home: AppCachedNetworkImage(imageUrl: url, cacheManager: cache),
      ),
    );
    cache.emitError(url, StateError('download failed'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('app_cached_network_image.error')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('selects the configured cache profile through the resolver', (
    tester,
  ) async {
    const url = 'https://cdn.soundconnect.test/original.png';
    final cache = _FakeCacheManager();
    AppImageCacheProfile? selectedProfile;

    await tester.pumpWidget(
      MaterialApp(
        home: AppCachedNetworkImage(
          imageUrl: url,
          cacheProfile: AppImageCacheProfile.original,
          cacheManagerResolver: (profile) {
            selectedProfile = profile;
            return cache;
          },
        ),
      ),
    );

    expect(selectedProfile, AppImageCacheProfile.original);
    expect(cache.requestedUrls, <String>[url]);
  });
}

class _FakeCacheManager extends Fake implements BaseCacheManager {
  final Map<String, StreamController<FileResponse>> _controllers = {};
  final List<String> requestedUrls = [];
  final List<bool> withProgressValues = [];

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    requestedUrls.add(url);
    withProgressValues.add(withProgress);
    return _controllers
        .putIfAbsent(url, StreamController<FileResponse>.new)
        .stream;
  }

  void emit(String url, FileResponse response) {
    _controllers[url]!.add(response);
  }

  void emitFile(String url, File file) {
    emit(
      url,
      FileInfo(
        file,
        FileSource.Cache,
        DateTime.now().add(const Duration(days: 1)),
        url,
      ),
    );
  }

  void emitError(String url, Object error) {
    _controllers[url]!.addError(error);
  }
}
