import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';

void main() {
  const now = 1790000000000;
  for (final type in PushTarget.collabTypes) {
    test('$type closed native wire, exact identity and expiry boundaries', () {
      final identity = <String, dynamic>{
        'notificationId': '50000000-0000-4000-8000-000000000001',
        'recipientId': '70000000-0000-4000-8000-000000000001',
        'type': type,
      };
      final wire = <String, dynamic>{
        ...identity,
        'presentationVersion': 'ANDROID_COLLAB_V1',
        'displayVariant': type == 'COLLAB_REPORT_RESOLVED'
            ? 'REMOVE_LISTING'
            : 'DEFAULT',
        'sentAt': '$now',
        'expiresAt': '${now + 60000}',
      };
      expect(PushTarget.parse(identity)?.isCollab, isTrue);
      expect(PushTarget.parse(wire, nowMillis: now)?.isCollab, isTrue);
      for (final skew in [1, 640, 5000]) {
        expect(
          PushTarget.parse({
            ...wire,
            'sentAt': '${now + skew}',
          }, nowMillis: now)?.isCollab,
          isTrue,
        );
      }
      if (type == 'COLLAB_REPORT_RESOLVED') {
        expect(
          PushTarget.parse({
            ...wire,
            'displayVariant': 'DISMISS',
          }, nowMillis: now)?.isCollab,
          isTrue,
        );
        expect(
          PushTarget.parse({
            ...wire,
            'displayVariant': 'DEFAULT',
          }, nowMillis: now),
          isNull,
        );
      }
      for (final key in wire.keys) {
        expect(
          PushTarget.parse({...wire}..remove(key), nowMillis: now),
          isNull,
          reason: key,
        );
      }
      for (final key in [
        'listingId',
        'applicationId',
        'jobId',
        'reviewId',
        'reportId',
        'actorId',
        'phone',
        'note',
        'title',
        'message',
        'avatarUrl',
        'deepLink',
        'conversationId',
      ]) {
        expect(
          PushTarget.parse({...wire, key: 'private'}, nowMillis: now),
          isNull,
          reason: key,
        );
      }
      for (final patch in [
        {'presentationVersion': 'ANDROID_TABLE_V1'},
        {'presentationVersion': 'ANDROID_COLLAB_V2'},
        {'type': 'COLLAB_UNKNOWN'},
        {'type': 'TABLE_EXPIRED'},
        {'displayVariant': 'BAD'},
        {'recipientId': 'wrong'},
        {'notificationId': '1-1-1-1-1'},
        {'sentAt': '${now + 5001}'},
        {'sentAt': '+$now'},
        {'sentAt': '0$now'},
        {'sentAt': now},
        {'sentAt': '9223372036854775808'},
        {'expiresAt': '$now'},
        {'expiresAt': '${now + const Duration(days: 28).inMilliseconds + 1}'},
      ]) {
        expect(
          PushTarget.parse({...wire, ...patch}, nowMillis: now),
          isNull,
          reason: '$patch',
        );
      }
      expect(PushTarget.parse(wire, nowMillis: -1), isNull);
    });
  }
}
