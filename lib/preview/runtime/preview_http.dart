import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'preview_media.dart';

/// Serves bundled bytes to the unchanged Flutter image/cache widgets. This
/// adapter never creates a socket, DNS lookup, delegate client or redirect.
class PreviewHttpOverrides extends HttpOverrides {
  PreviewHttpOverrides(this.images);
  final Map<String, Uint8List> images;
  int servedImages = 0;
  int rejectedRequests = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _PreviewHttpClient(this);
}

class _PreviewHttpClient implements HttpClient {
  _PreviewHttpClient(this.owner);
  final PreviewHttpOverrides owner;
  bool _closed = false;
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (_closed) throw StateError('Preview image client is closed');
    try {
      if (method != 'GET') throw StateError('Preview media is read only');
      final name = previewFixtureName(url);
      final bytes = owner.images[name];
      if (bytes == null && name != 'missing.png' && name != 'loading.png') {
        throw StateError('Unknown preview image: $name');
      }
      return _PreviewRequest(url, name, bytes, owner);
    } catch (_) {
      owner.rejectedRequests++;
      rethrow;
    }
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  void close({bool force = false}) {
    _closed = true;
  }

  // Unused transport APIs fail closed instead of falling through to dart:io.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Preview transport: ${invocation.memberName}');
}

class _PreviewRequest implements HttpClientRequest {
  _PreviewRequest(this.uri, this.name, this.bytes, this.owner);
  final String name;
  final Uint8List? bytes;
  final PreviewHttpOverrides owner;
  bool _aborted = false;
  Future<HttpClientResponse>? _response;
  @override
  final Uri uri;
  @override
  String get method => 'GET';
  @override
  final HttpHeaders headers = _PreviewHeaders();
  @override
  bool followRedirects = false;
  @override
  int maxRedirects = 0;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = false;
  @override
  bool bufferOutput = true;

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      if (chunk.isNotEmpty) throw StateError('Preview GET cannot have a body');
    }
  }

  @override
  Future<HttpClientResponse> close() => _response ??= _complete();
  @override
  Future<HttpClientResponse> get done => close();
  Future<HttpClientResponse> _complete() async {
    if (_aborted) throw StateError('Preview image request cancelled');
    if (bytes != null) owner.servedImages++;
    return _PreviewResponse(bytes, loading: name == 'loading.png');
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    _aborted = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Preview request: ${invocation.memberName}');
}

class _PreviewResponse extends Stream<List<int>> implements HttpClientResponse {
  _PreviewResponse(this.bytes, {required this.loading}) {
    headers.set(HttpHeaders.contentTypeHeader, 'image/png');
    headers.set(HttpHeaders.cacheControlHeader, 'max-age=86400');
    if (!loading) headers.contentLength = contentLength;
  }
  final Uint8List? bytes;
  final bool loading;
  @override
  final HttpHeaders headers = _PreviewHeaders();
  @override
  int get statusCode => bytes != null || loading ? 200 : 404;
  @override
  String get reasonPhrase => statusCode == 200 ? 'OK' : 'Not Found';
  @override
  int get contentLength => loading ? -1 : bytes?.length ?? 0;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  List<Cookie> get cookies => const [];
  @override
  X509Certificate? get certificate => null;
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // An explicitly selected catalogue fixture remains in its loading state.
    // A controller has no timer/socket; cancelling the image subscription
    // releases it. Normal feed fixtures always complete.
    final stream = loading
        ? StreamController<List<int>>().stream
        : Stream<List<int>>.value(bytes ?? Uint8List(0));
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Preview response: ${invocation.memberName}');
}

class _PreviewHeaders implements HttpHeaders {
  final _values = <String, List<String>>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    (_values[name.toLowerCase()] ??= []).add(value.toString());
  }

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];
  @override
  String? value(String name) => this[name]?.join(', ');
  @override
  void forEach(void Function(String, List<String>) action) =>
      _values.forEach(action);
  @override
  int get contentLength =>
      int.tryParse(value(HttpHeaders.contentLengthHeader) ?? '') ?? -1;
  @override
  set contentLength(int value) => set(HttpHeaders.contentLengthHeader, value);
  @override
  ContentType? get contentType {
    final raw = value(HttpHeaders.contentTypeHeader);
    return raw == null ? null : ContentType.parse(raw);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Preview headers: ${invocation.memberName}');
}
