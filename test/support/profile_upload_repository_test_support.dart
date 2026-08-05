part of '../profile_upload_repository_test.dart';

class _UploadAdapter implements HttpClientAdapter {
  _UploadAdapter({required this.statusCode});

  final int statusCode;
  final List<_UploadRequest> requests = <_UploadRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    requests.add(
      _UploadRequest(
        method: options.method,
        path: options.path,
        headers: Map<String, dynamic>.from(options.headers),
        bytes: bytes,
      ),
    );
    return ResponseBody.fromString('', statusCode);
  }

  @override
  void close({bool force = false}) {}
}

class _CancellableUploadAdapter implements HttpClientAdapter {
  final Completer<void> started = Completer<void>();
  bool cancelFutureObserved = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final subscription = requestStream?.listen((_) {});
    if (!started.isCompleted) started.complete();
    try {
      if (cancelFuture == null) {
        throw StateError('Dio did not forward the cancellation future');
      }
      await cancelFuture;
      cancelFutureObserved = true;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        message: 'cancelled by test',
      );
    } finally {
      await subscription?.cancel();
    }
  }

  @override
  void close({bool force = false}) {}
}

class _CommittedThenResponseLostUploadAdapter implements HttpClientAdapter {
  final List<int> committedBytes = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        committedBytes.addAll(chunk);
      }
    }
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'Response lost after remote commit',
    );
  }

  @override
  void close({bool force = false}) {}
}

class _UploadRequest {
  const _UploadRequest({
    required this.method,
    required this.path,
    required this.headers,
    required this.bytes,
  });

  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final List<int> bytes;
}
