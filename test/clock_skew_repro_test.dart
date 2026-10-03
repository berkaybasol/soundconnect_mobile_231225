import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';

void main() {
  for (final type in {...PushTarget.followTypes, ...PushTarget.mediaTypes}) {
    test('$type accepts a fast delivery with sentAt 640 ms ahead', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final result = PushTarget.parse({
        'notificationId': '50000000-0000-4000-8000-000000000001',
        'recipientId': '70000000-0000-4000-8000-000000000001',
        'type': type,
        'presentationVersion': PushTarget.followTypes.contains(type)
            ? 'ANDROID_FOLLOW_V1'
            : 'ANDROID_MEDIA_V1',
        'displayVariant': 'DEFAULT',
        'sentAt': '${now + 640}',
        'expiresAt': '${now + 86400000}',
      });
      // Fail separately if host scheduling has consumed the future offset.
      expect(DateTime.now().millisecondsSinceEpoch - now, lessThan(640));
      expect(result?.type, type);
    });
  }
}
