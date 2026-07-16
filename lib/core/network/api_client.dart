enum ApiHttpMethod { get, post, put, patch, delete }

class ApiRequestContext {
  const ApiRequestContext({this.expectedSessionKey});

  final String? expectedSessionKey;
}

abstract class ApiClient {
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  });
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  });
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  });
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  });
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  });

  /// Dispatches a request with transport-level metadata.
  ///
  /// Implementations that can guarantee an authenticated session fence must
  /// override this method. The default path deliberately rejects fenced
  /// requests instead of silently degrading to a racy preflight check.
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) {
    if (requestContext?.expectedSessionKey?.trim().isNotEmpty == true) {
      return Future<T>.error(
        UnsupportedError(
          'This ApiClient does not support transport-level session fencing',
        ),
      );
    }
    return switch (method) {
      ApiHttpMethod.get => get<T>(path, query: query, decoder: decoder),
      ApiHttpMethod.post => post<T>(path, body: body, decoder: decoder),
      ApiHttpMethod.put => put<T>(path, body: body, decoder: decoder),
      ApiHttpMethod.patch => patch<T>(path, body: body, decoder: decoder),
      ApiHttpMethod.delete => delete<T>(path, body: body, decoder: decoder),
    };
  }
}
