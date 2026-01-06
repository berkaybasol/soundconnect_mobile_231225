import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../error/app_error.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'base_response.dart';
import 'network_config.dart';

class DioApiClient implements ApiClient {
  final Dio _dio;
  final TokenStore _tokenStore;

  DioApiClient({
    Dio? dio,
    required TokenStore tokenStore,
    String? baseUrl,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? NetworkConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: const {'Content-Type': 'application/json'},
              ),
            ),
        _tokenStore = tokenStore {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!_isPublicPath(options.path)) {
            final token = await _tokenStore.readToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  bool _isPublicPath(String path) {
    return path.startsWith('/api/v1/auth') ||
        path.startsWith('/api/v1/cities') ||
        path.startsWith('/api/v1/districts') ||
        path.startsWith('/api/v1/neighborhoods');
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) {
    return _request<T>('GET', path, query: query, decoder: decoder);
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) {
    return _request<T>('POST', path, body: body, decoder: decoder);
  }

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) {
    return _request<T>('PUT', path, body: body, decoder: decoder);
  }

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) {
    return _request<T>('DELETE', path, body: body, decoder: decoder);
  }

  Future<T> _request<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );

      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        final baseResponse = BaseResponse<T>.fromJson(payload, decoder);
        if (baseResponse.success == true) {
          return baseResponse.data as T;
        }
        throw ApiException(
          AppError(
            code: (baseResponse.code ?? response.statusCode ?? 0).toString(),
            message: baseResponse.message ?? 'Request failed',
          ),
        );
      }

      if (decoder != null) {
        return decoder(payload);
      }

      return payload as T;
    } on DioException catch (e) {
      throw ApiException(
        AppError(
          code: e.response?.statusCode?.toString() ?? 'network',
          message: e.message ?? 'Network error',
        ),
      );
    }
  }
}
