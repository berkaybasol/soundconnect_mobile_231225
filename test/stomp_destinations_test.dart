import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/realtime/stomp_destinations.dart';

void main() {
  group('StompDestinations', () {
    test('broker subscriptions use Rabbit-compatible topic destinations', () {
      expect(
        StompDestinations.notifications('user-1'),
        '/topic/notifications.user-1',
      );
      expect(
        StompDestinations.notificationsBadge('user-1'),
        '/topic/notifications.user-1.badge',
      );
      expect(StompDestinations.dm('user-1'), '/topic/dm.user-1');
      expect(StompDestinations.dmBadge('user-1'), '/topic/dm.user-1.badge');
      expect(
        StompDestinations.tableGroup('group-1'),
        '/topic/table-group.group-1',
      );
    });
  });
}
