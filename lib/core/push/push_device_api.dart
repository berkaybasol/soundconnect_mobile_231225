import 'package:dio/dio.dart';

import '../auth/auth_session.dart';
import '../network/api_client.dart';
import '../network/network_config.dart';
import 'push_provider.dart';

class PushPreferences {
  const PushPreferences({
    required this.enabled,
    this.disabledCategories = const {},
  });
  final bool enabled;
  final Set<String> disabledCategories;
}

abstract interface class PushDeviceApi {
  Future<void> register({
    required AuthSession session,
    required String installationId,
    required int clientRevision,
    required String token,
    required String platform,
    required PushPermission permission,
  });
  Future<void> revoke({
    required AuthSession session,
    required String installationId,
    required int clientRevision,
  });
  Future<PushPreferences> preferences(AuthSession session);
  Future<void> savePreferences(
    AuthSession session,
    PushPreferences preferences,
  );
}

class HttpPushDeviceApi implements PushDeviceApi {
  HttpPushDeviceApi(this._client);
  final ApiClient _client;
  static const _base = '/api/v1/user/notifications/push';
  String _deviceBase(AuthSession session) => session.isVenueApplicationSession
      ? '${session.venueApplicationSessionBase}/push'
      : _base;
  ApiRequestContext _context(AuthSession session) => ApiRequestContext(
    expectedSessionKey: session.userId,
    expectedToken: session.token,
  );
  @override
  Future<void> register({
    required AuthSession session,
    required String installationId,
    required int clientRevision,
    required String token,
    required String platform,
    required PushPermission permission,
  }) => _client.request<void>(
    ApiHttpMethod.put,
    '${_deviceBase(session)}/devices/$installationId',
    body: {
      'token': token,
      'platform': platform,
      'permission': permission.apiValue,
      'clientRevision': clientRevision,
      if (platform == 'ANDROID') 'presentationVersion': 'ANDROID_NATIVE_V10',
    },
    requestContext: _context(session),
  );

  @override
  Future<void> revoke({
    required AuthSession session,
    required String installationId,
    required int clientRevision,
  }) async {
    // Logout immediately hides the authenticated UI. Only this revocation uses
    // the captured old bearer; never adopt a newer account's credential.
    final dio = Dio(
      BaseOptions(
        baseUrl: NetworkConfig.baseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        sendTimeout: const Duration(seconds: 4),
      ),
    );
    try {
      await dio.delete<void>(
        '${_deviceBase(session)}/devices/$installationId',
        queryParameters: {'clientRevision': clientRevision},
        options: Options(
          headers: {'Authorization': 'Bearer ${session.token}'},
          followRedirects: false,
        ),
      );
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<PushPreferences> preferences(AuthSession session) =>
      _client.request<PushPreferences>(
        ApiHttpMethod.get,
        '$_base/preferences',
        requestContext: _context(session),
        decoder: (json) {
          final map = json as Map<String, dynamic>;
          final data = (map['data'] ?? map) as Map<String, dynamic>;
          return PushPreferences(
            enabled: data['enabled'] == true,
            disabledCategories:
                ((data['disabledCategories'] as List?) ?? const [])
                    .whereType<String>()
                    .toSet(),
          );
        },
      );
  @override
  Future<void> savePreferences(
    AuthSession session,
    PushPreferences preferences,
  ) => _client.request<void>(
    ApiHttpMethod.put,
    '$_base/preferences',
    requestContext: _context(session),
    body: {
      'enabled': preferences.enabled,
      'disabledCategories': preferences.disabledCategories.toList(),
    },
  );
}
