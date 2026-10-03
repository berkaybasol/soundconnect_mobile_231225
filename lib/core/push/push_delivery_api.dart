import '../auth/auth_session.dart';
import '../network/api_client.dart';
import 'push_provider.dart';

/// Read-only comparison with the current account's authoritative inbox.
abstract interface class PushDeliveryApi {
  Future<Set<String>> dismissedIds(
    AuthSession session,
    List<String> notificationIds,
  );
}

class HttpPushDeliveryApi implements PushDeliveryApi {
  HttpPushDeliveryApi(this._client);
  final ApiClient _client;

  @override
  Future<Set<String>> dismissedIds(
    AuthSession session,
    List<String> notificationIds,
  ) {
    if (notificationIds.length > 100 ||
        notificationIds.any((id) => !PushTarget.isUuid(id))) {
      return Future.error(ArgumentError('Invalid delivered notification IDs'));
    }
    if (notificationIds.isEmpty) return Future.value(<String>{});
    final requested = notificationIds.map((id) => id.toLowerCase()).toSet();
    return _client.request<Set<String>>(
      ApiHttpMethod.post,
      session.isVenueApplicationSession
          ? '${session.venueApplicationSessionBase}/notifications/delivery-state'
          : '/api/v1/user/notifications/delivery-state',
      body: {'notificationIds': requested.toList()},
      requestContext: ApiRequestContext(
        expectedSessionKey: session.userId,
        expectedToken: session.token,
      ),
      decoder: (json) {
        // DioApiClient already unwraps BaseResponse.data before this decoder.
        final data = json;
        final ids = data is Map ? data['dismissedIds'] : null;
        if (ids is! List ||
            ids.length > 100 ||
            ids.any((id) => !PushTarget.isUuid(id)) ||
            ids.any(
              (id) => !requested.contains((id as String).toLowerCase()),
            )) {
          throw const FormatException('Invalid notification delivery state');
        }
        return ids.cast<String>().map((id) => id.toLowerCase()).toSet();
      },
    );
  }
}
