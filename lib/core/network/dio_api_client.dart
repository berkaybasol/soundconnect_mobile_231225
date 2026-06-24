import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/token_store.dart';
import '../error/app_error.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'base_response.dart';
import 'network_config.dart';

class DioApiClient implements ApiClient {
  final Dio _dio;
  final TokenStore _tokenStore;

  DioApiClient({Dio? dio, required TokenStore tokenStore, String? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: _resolveBaseUrl(baseUrl),
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

  static String _resolveBaseUrl(String? baseUrl) {
    if (baseUrl == null) {
      return NetworkConfig.baseUrl;
    }
    return resolveNetworkBaseUrl(
      configuredBaseUrl: baseUrl,
      isDebugBuild: kDebugMode,
      debugFallbackBaseUrl: NetworkConfig.debugFallbackBaseUrl,
      allowDebugFallback: false,
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
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) {
    return _request<T>('PATCH', path, body: body, decoder: decoder);
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
      final errorPayload = e.response?.data;
      final String message = _messageFromErrorPayload(errorPayload) ??
          _mapDioErrorMessage(e);
      final String code =
          _codeFromErrorPayload(errorPayload) ??
          e.response?.statusCode?.toString() ??
          'network';
      throw ApiException(
        AppError(
          code: code,
          message: message,
          details: _detailsFromErrorPayload(errorPayload),
        ),
      );
    }
  }

  String? _messageFromErrorPayload(Object? payload) {
    if (payload is! Map<String, dynamic>) return null;
    final details = _detailsFromErrorPayload(payload);
    if (details.isNotEmpty) return details.first;
    final message = payload['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
    return null;
  }

  String? _codeFromErrorPayload(Object? payload) {
    if (payload is! Map<String, dynamic>) return null;
    final raw = payload['code'];
    final code = raw?.toString().trim();
    return code == null || code.isEmpty ? null : code;
  }

  List<String> _detailsFromErrorPayload(Object? payload) {
    if (payload is! Map<String, dynamic>) return const [];
    final rawDetails = payload['details'];
    if (rawDetails is List) {
      return rawDetails
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String _mapDioErrorMessage(DioException e) {
    final String fallback = e.message ?? 'Network error';
    final Uri uri = e.requestOptions.uri;
    final String host = uri.host.trim().toLowerCase();

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      if (host == '10.0.2.2') {
        return 'Baglanti zaman asimi: ${uri.origin}. '
            '10.0.2.2 sadece emulator icin.';
      }
      return 'Baglanti zaman asimi: ${uri.origin}. '
          'Backend/Ag/Firewall kontrol et.';
    }

    if (e.type == DioExceptionType.connectionError) {
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'Baglanti reddedildi: ${uri.origin}. '
            'Emulator icin 10.0.2.2 kullan.';
      }
      if (host == '10.0.2.2') {
        return 'Baglanti reddedildi: ${uri.origin}. '
            'Gercek cihazda PC LAN IP kullan.';
      }
    }

    return fallback;
  }
}
