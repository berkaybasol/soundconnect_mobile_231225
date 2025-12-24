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
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  });
}
