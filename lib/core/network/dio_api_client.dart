import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_session_manager.dart';
import '../auth/jwt_claims.dart';
import '../auth/token_store.dart';
import '../error/app_error.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'base_response.dart';
import 'network_config.dart';

const Set<String> _publicAuthPaths = <String>{
  '/api/v1/auth/login',
  '/api/v1/auth/register',
  '/api/v1/auth/verify-code',
  '/api/v1/auth/resend-code',
  '/api/v1/auth/forgot-password',
  '/api/v1/auth/reset-password',
  '/api/v1/auth/google-sign-in',
};

@visibleForTesting
bool isPublicApiRequest(String method, String rawPath) {
  final normalizedMethod = method.trim().toUpperCase();
  final path = Uri.tryParse(rawPath)?.path ?? rawPath;
  if (normalizedMethod == 'POST') {
    return _publicAuthPaths.contains(path) ||
        path == '/api/v1/spotify/tracks/by-ids';
  }
  if (normalizedMethod != 'GET') return false;

  // These read routes live under the public URL namespace but expose mutable
  // listener identity/visibility projections only to authenticated app
  // sessions. Classifying them as private ensures the JWT is attached and an
  // authoritative 401 invalidates the rejected session.
  if (_isPathOrDescendant(path, '/api/v1/public/listener-profiles') ||
      _isPathOrDescendant(path, '/api/v1/public/profiles')) {
    return false;
  }

  return path.startsWith('/api/v1/public/') ||
      path == '/api/v1/public' ||
      _isPathOrDescendant(path, '/api/v1/cities') ||
      _isPathOrDescendant(path, '/api/v1/districts') ||
      _isPathOrDescendant(path, '/api/v1/neighborhoods') ||
      (path == '/api/v1/venues' || path.startsWith('/api/v1/venues/')) ||
      (path == '/api/v1/events' || path.startsWith('/api/v1/events/')) ||
      (path == '/api/v1/promotions/displayable' ||
          path.startsWith('/api/v1/promotions/displayable/')) ||
      path == '/api/v1/spotify/search/tracks' ||
      (path.startsWith('/api/v1/spotify/tracks/') &&
          path != '/api/v1/spotify/tracks/by-ids') ||
      RegExp(r'^/api/v1/profiles/[^/]+/[^/]+/media$').hasMatch(path);
}

bool _isPathOrDescendant(String path, String basePath) {
  return path == basePath || path.startsWith('$basePath/');
}

class DioApiClient implements ApiClient {
  final Dio _dio;
  final TokenStore _tokenStore;
  final AuthSessionManager? _sessionManager;

  static const String _requestTokenKey = 'soundconnect.request_token';
  static const String _expectedSessionKey = 'soundconnect.expected_session_key';

  DioApiClient({
    Dio? dio,
    required TokenStore tokenStore,
    AuthSessionManager? sessionManager,
    String? baseUrl,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: _resolveBaseUrl(baseUrl),
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 15),
               headers: const {'Content-Type': 'application/json'},
             ),
           ),
       _tokenStore = tokenStore,
       _sessionManager = sessionManager {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isPublic = isPublicApiRequest(options.method, options.path);
          final expectedSession =
              options.extra[_expectedSessionKey]?.toString().trim() ?? '';
          if (!isPublic || expectedSession.isNotEmpty) {
            final token = await _tokenStore.readToken();
            if (expectedSession.isNotEmpty) {
              final tokenSession = JwtClaims.tryParse(token)?.subject?.trim();
              final activeSession = _sessionManager?.session.userId?.trim();
              final sessionChanged =
                  tokenSession != expectedSession ||
                  (_sessionManager != null && activeSession != expectedSession);
              if (sessionChanged) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.cancel,
                    error: const ApiSessionFenceException(),
                    message: 'Authenticated session changed before dispatch',
                  ),
                );
                return;
              }
            }
            if (!isPublic && token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
              options.extra[_requestTokenKey] = token;
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (_codeFromErrorPayload(error.response?.data) == '1308') {
            await _requireListenerChoiceForRequest(error.requestOptions);
          }
          if (error.response?.statusCode == 401) {
            await _rejectUnauthorizedRequest(error.requestOptions);
          }
          handler.next(error);
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

  bool _isPublicRequest(RequestOptions options) {
    return isPublicApiRequest(options.method, options.path);
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

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) {
    return _request<T>(
      method.name.toUpperCase(),
      path,
      body: body,
      query: query,
      decoder: decoder,
      requestContext: requestContext,
    );
  }

  Future<T> _request<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          extra: <String, Object?>{
            if (requestContext?.expectedSessionKey case final value?)
              _expectedSessionKey: value,
          },
        ),
      );

      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        final baseResponse = BaseResponse<T>.fromJson(payload, decoder);
        if (baseResponse.success == true) {
          return baseResponse.data as T;
        }
        if (baseResponse.code == 401) {
          await _rejectUnauthorizedRequest(response.requestOptions);
        }
        if (baseResponse.code?.toString() == '1308') {
          await _requireListenerChoiceForRequest(response.requestOptions);
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
      if (e.error is ApiSessionFenceException) {
        throw ApiException(
          const AppError(
            code: 'api_session_fence',
            message: 'Oturum istek gonderilmeden once degisti',
          ),
        );
      }
      final errorPayload = e.response?.data;
      final String message =
          _messageFromErrorPayload(errorPayload) ?? _mapDioErrorMessage(e);
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

  Future<void> _rejectUnauthorizedRequest(RequestOptions options) async {
    if (_isPublicRequest(options)) return;
    final rejectedToken = options.extra[_requestTokenKey]?.toString();
    await _sessionManager?.rejectUnauthorizedToken(rejectedToken);
  }

  Future<void> _requireListenerChoiceForRequest(RequestOptions options) async {
    if (_isPublicRequest(options)) return;
    final manager = _sessionManager;
    final requestToken = options.extra[_requestTokenKey]?.toString().trim();
    if (manager == null || requestToken == null || requestToken.isEmpty) return;
    final expectedUserId = JwtClaims.tryParse(requestToken)?.subject?.trim();
    if (expectedUserId == null || expectedUserId.isEmpty) return;
    try {
      await manager.requireListenerProfileChoice(
        expectedUserId: expectedUserId,
        expectedToken: requestToken,
      );
    } catch (_) {
      // Session recovery is best effort and must never hide the API failure.
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

class ApiSessionFenceException implements Exception {
  const ApiSessionFenceException();
}
