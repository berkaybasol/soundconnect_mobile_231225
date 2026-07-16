import 'dart:async';

import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';

enum RecordedHttpMethod { get, post, put, patch, delete }

class RecordedApiRequest {
  const RecordedApiRequest({
    required this.method,
    required this.path,
    this.query,
    this.body,
    this.requestContext,
  });

  final RecordedHttpMethod method;
  final String path;
  final Map<String, dynamic>? query;
  final Object? body;
  final ApiRequestContext? requestContext;
}

typedef ApiResponseHandler =
    FutureOr<Object?> Function(RecordedApiRequest request);

class RecordingApiClient implements ApiClient {
  RecordingApiClient(this._handler);

  final ApiResponseHandler _handler;
  final List<RecordedApiRequest> requests = <RecordedApiRequest>[];

  RecordedApiRequest get lastRequest => requests.last;

  Future<T> _execute<T>(
    RecordedHttpMethod method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    final request = RecordedApiRequest(
      method: method,
      path: path,
      query: query,
      body: body,
      requestContext: requestContext,
    );
    requests.add(request);
    final payload = await Future<Object?>.sync(() => _handler(request));
    return decoder == null ? payload as T : decoder(payload);
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) => _execute(RecordedHttpMethod.get, path, query: query, decoder: decoder);

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute(RecordedHttpMethod.post, path, body: body, decoder: decoder);

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute(RecordedHttpMethod.put, path, body: body, decoder: decoder);

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute(RecordedHttpMethod.patch, path, body: body, decoder: decoder);

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute(RecordedHttpMethod.delete, path, body: body, decoder: decoder);

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) => _execute(
    switch (method) {
      ApiHttpMethod.get => RecordedHttpMethod.get,
      ApiHttpMethod.post => RecordedHttpMethod.post,
      ApiHttpMethod.put => RecordedHttpMethod.put,
      ApiHttpMethod.patch => RecordedHttpMethod.patch,
      ApiHttpMethod.delete => RecordedHttpMethod.delete,
    },
    path,
    body: body,
    query: query,
    decoder: decoder,
    requestContext: requestContext,
  );
}
