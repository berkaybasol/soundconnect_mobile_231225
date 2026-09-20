import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/shared/images/private_media_image_cache.dart';

import 'marketplace_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MarketplaceTestSessions sessions;
  late _Adapter adapter;
  late Dio dio;
  late PrivateMediaImageCache cache;
  late DateTime now;

  setUp(() {
    sessions = MarketplaceTestSessions(marketSession());
    adapter = _Adapter();
    dio = Dio()..httpClientAdapter = adapter;
    now = DateTime.now();
    cache = PrivateMediaImageCache(
      sessions: sessions,
      dio: dio,
      clock: () => now,
    );
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed);
  });
  tearDown(() {
    cache.dispose();
    sessions.dispose();
    dio.close(force: true);
  });

  Future<Uint8List> load({
    String asset = marketAssetId,
    String variant = 'thumbnail',
    String scope = 'marketplace',
    String signature = 'one',
    String? url,
    DateTime? expiresAt,
    AuthSession? session,
  }) => cache.getOrLoad(
    session: session ?? sessions.session,
    assetId: asset,
    variant: variant,
    accessScope: scope,
    authorizedUrl:
        url ??
        'https://storage.example.test/$asset/$variant.jpg?signature=$signature',
    expiresAt: expiresAt ?? now.add(const Duration(minutes: 5)),
  );

  test(
    'renewed signatures reuse authorized bytes; variants and scopes are isolated',
    () async {
      final first = await load();
      final renewed = await load(signature: 'renewed');
      expect(identical(first, renewed), isTrue);
      expect(adapter.requests, hasLength(1));
      expect(() => first[0] = 9, throwsUnsupportedError);
      await load(variant: 'original');
      await load(scope: 'marketplace-moderator');
      await load(url: 'https://storage.example.test/new-version.jpg');
      expect(adapter.requests, hasLength(4));
      for (final request in adapter.requests) {
        expect(
          request.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(request.followRedirects, isFalse);
      }
    },
  );

  test('expired access and unsafe URLs cannot use an existing hit', () async {
    await load();
    await expectLater(
      load(expiresAt: now),
      throwsA(isA<PrivateMediaImageUnavailable>()),
    );
    await expectLater(
      load(url: 'http://storage.example.test/image.jpg'),
      throwsA(isA<PrivateMediaImageUnavailable>()),
    );
    await expectLater(
      load(url: 'https://user:password@storage.example.test/image.jpg'),
      throwsA(isA<PrivateMediaImageUnavailable>()),
    );
    expect(adapter.requests, hasLength(1));
    now = now.add(const Duration(minutes: 6));
    await load(signature: 'fresh-after-expiry');
    expect(adapter.requests, hasLength(2));
  });

  test(
    'same user with a new session cannot reuse previous session bytes',
    () async {
      final old = sessions.session;
      await load();
      sessions.replace(marketSession());
      await expectLater(
        load(session: old),
        throwsA(isA<PrivateMediaImageUnavailable>()),
      );
      await load();
      expect(adapter.requests, hasLength(2));
      sessions.replace(const AuthSession.guest());
      await expectLater(load(), throwsA(isA<PrivateMediaImageUnavailable>()));
    },
  );

  test('background and memory pressure clear encoded bytes', () async {
    await load();
    cache.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await expectLater(load(), throwsA(isA<PrivateMediaImageUnavailable>()));
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await load();
    cache.didHaveMemoryPressure();
    await load();
    expect(adapter.requests, hasLength(3));
  });

  test('bounded LRU evicts least recently read bytes', () async {
    cache.dispose();
    cache = PrivateMediaImageCache(
      sessions: sessions,
      dio: dio,
      maxEntries: 2,
      maxBytes: 6,
    );
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await load(asset: 'a');
    await load(asset: 'b');
    await load(asset: 'a');
    await load(asset: 'c');
    await load(asset: 'a');
    expect(adapter.requests, hasLength(3));
    await load(asset: 'b');
    expect(adapter.requests, hasLength(4));
  });

  test('simultaneous requests deduplicate storage downloads', () async {
    final gate = Completer<ResponseBody>();
    adapter.respond = (_) => gate.future;
    final first = load();
    final second = load(signature: 'renewed');
    await adapter.waitForRequests(1);
    expect(adapter.requests, hasLength(1));
    gate.complete(_image());
    final results = await Future.wait([first, second]);
    expect(identical(results.first, results.last), isTrue);
  });

  test(
    'queue limits concurrency and logout rejects active and pending loads',
    () async {
      cache.dispose();
      cache = PrivateMediaImageCache(
        sessions: sessions,
        dio: dio,
        maxConcurrent: 1,
        maxPending: 1,
      );
      cache.didChangeAppLifecycleState(AppLifecycleState.resumed);
      final gate = Completer<ResponseBody>();
      adapter.respond = (_) => gate.future;
      final first = load(asset: 'a');
      final second = load(asset: 'b');
      final firstCheck = expectLater(
        first,
        throwsA(isA<PrivateMediaImageUnavailable>()),
      );
      final secondCheck = expectLater(
        second,
        throwsA(isA<PrivateMediaImageUnavailable>()),
      );
      await expectLater(
        load(asset: 'c'),
        throwsA(isA<PrivateMediaImageUnavailable>()),
      );
      await adapter.waitForRequests(1);
      expect(adapter.requests, hasLength(1));
      sessions.replace(const AuthSession.guest());
      await Future.wait([firstCheck, secondCheck]);
      gate.complete(_image());
      await Future<void>.delayed(Duration.zero);
      sessions.replace(marketSession());
      adapter.respond = (_) async => _image();
      await load(asset: 'a');
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'denial evicts matching scope and cannot be repopulated by late work',
    () async {
      final gate = Completer<ResponseBody>();
      adapter.respond = (_) => gate.future;
      final pending = load();
      final rejected = expectLater(
        pending,
        throwsA(isA<PrivateMediaImageUnavailable>()),
      );
      await adapter.waitForRequests(1);
      cache.evict(
        session: sessions.session,
        assetId: marketAssetId,
        accessScope: 'marketplace',
      );
      await rejected;
      gate.complete(_image());
      await Future<void>.delayed(Duration.zero);
      adapter.respond = (_) async => _image();
      await load();
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'rejects oversized announced or streamed files and permits retry',
    () async {
      cache.dispose();
      cache = PrivateMediaImageCache(
        sessions: sessions,
        dio: dio,
        maxFileBytes: 3,
      );
      cache.didChangeAppLifecycleState(AppLifecycleState.resumed);
      adapter.respond = (_) async => ResponseBody.fromBytes(
        [1],
        200,
        headers: {
          'content-type': ['image/jpeg'],
          'content-length': ['100'],
        },
      );
      await expectLater(load(), throwsA(isA<PrivateMediaImageUnavailable>()));
      adapter.respond = (_) async => ResponseBody(
        Stream.fromIterable([
          Uint8List.fromList([1, 2]),
          Uint8List.fromList([3, 4]),
        ]),
        200,
        headers: {
          'content-type': ['image/jpeg'],
        },
      );
      await expectLater(load(), throwsA(isA<PrivateMediaImageUnavailable>()));
      adapter.respond = (_) async => _image();
      expect(await load(), [1, 2, 3]);
      expect(adapter.requests, hasLength(3));
    },
  );

  test('a renewed grant replaces an expired in-flight download', () async {
    final oldResponse = Completer<ResponseBody>();
    adapter.respond = (_) => oldResponse.future;
    final old = load(expiresAt: now.add(const Duration(seconds: 1)));
    final oldRejected = expectLater(
      old,
      throwsA(isA<PrivateMediaImageUnavailable>()),
    );
    await adapter.waitForRequests(1);
    now = now.add(const Duration(seconds: 2));
    adapter.respond = (_) async => _image();
    expect(await load(signature: 'renewed'), [1, 2, 3]);
    await oldRejected;
    oldResponse.complete(_image());
    expect(adapter.requests, hasLength(2));
  });

  test(
    'rejects storage errors and non-image content without caching them',
    () async {
      adapter.respond = (_) async =>
          ResponseBody.fromString('AccessDenied', 403);
      await expectLater(load(), throwsA(isA<PrivateMediaImageUnavailable>()));
      adapter.respond = (_) async => ResponseBody.fromString(
        'html',
        200,
        headers: {
          'content-type': ['text/html'],
        },
      );
      await expectLater(load(), throwsA(isA<PrivateMediaImageUnavailable>()));
      adapter.respond = (_) async => _image();
      await load();
      expect(adapter.requests, hasLength(3));
    },
  );
}

ResponseBody _image() => ResponseBody.fromBytes(
  [1, 2, 3],
  200,
  headers: {
    'content-type': ['image/jpeg'],
    'content-length': ['3'],
  },
);

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final _started = <int, Completer<void>>{};
  Future<ResponseBody> Function(RequestOptions) respond = (_) async => _image();

  Future<void> waitForRequests(int count) => requests.length >= count
      ? Future<void>.value()
      : (_started[count] ??= Completer<void>()).future;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    for (final count
        in _started.keys.where((count) => count <= requests.length).toList()) {
      _started.remove(count)!.complete();
    }
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}
