/// Canonical STOMP destinations shared by the realtime clients.
///
/// RabbitMQ's STOMP relay accepts broker subscriptions under `/topic`. Client
/// TableGroup chat writes use acknowledged REST in the first release; this
/// catalog therefore exposes only its receive-only broker topic.
abstract final class StompDestinations {
  static const String _notificationsTopic = '/topic/notifications';
  static const String _dmTopic = '/topic/dm';
  static const String _tableGroupTopic = '/topic/table-group';

  static String notifications(String userId) => '$_notificationsTopic.$userId';

  static String notificationsBadge(String userId) =>
      '${notifications(userId)}.badge';

  static String dm(String userId) => '$_dmTopic.$userId';

  static String dmBadge(String userId) => '${dm(userId)}.badge';

  static String tableGroup(String tableGroupId) =>
      '$_tableGroupTopic.$tableGroupId';
}
