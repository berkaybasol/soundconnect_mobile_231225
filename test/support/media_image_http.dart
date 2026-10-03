import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Controlled HTTP bytes; the real Image widget still has to decode and paint.
class MediaImageHttp extends Fake implements HttpClient {
  static final pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  Future<List<int>> Function(Uri) response = (_) async => pixel;
  final urls = <Uri>[];
  static MediaImageHttp? active;
  HttpOverrides? _previous;
  void install() {
    active = this;
    _previous = HttpOverrides.current;
    HttpOverrides.global = _MediaOverrides();
  }

  void dispose() {
    active = null;
    HttpOverrides.global = _previous;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    urls.add(url);
    return _Request(() => response(url));
  }
}

class _MediaOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _RoutingClient();
}

class _RoutingClient extends Fake implements HttpClient {
  @override
  set autoUncompress(bool value) {}
  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      MediaImageHttp.active!.getUrl(url);
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.bytes);
  final Future<List<int>> Function() bytes;
  @override
  final headers = _Headers();
  @override
  Future<HttpClientResponse> close() async => _Response(await bytes());
}

class _Headers extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final List<int> bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> paintMedia(WidgetTester tester) async {
  await tester.pump();
  var settledFrames = 0;
  // Engine image decoding uses real time. Keep yielding to it rather than
  // exhausting fake time inside pumpAndSettle while its spinner is active.
  for (var frame = 0; frame < 80; frame++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 100));
    settledFrames = tester.binding.hasScheduledFrame ? 0 : settledFrames + 1;
    if (settledFrames >= 2) return;
  }
  throw TestFailure('Media UI did not settle after yielding to image decoding');
}

Future<void> backgroundAndResume(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
}
