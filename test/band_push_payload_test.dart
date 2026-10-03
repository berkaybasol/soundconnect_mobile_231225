import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';

void main() {
  for (final type in PushTarget.bandTypes) {
    test('$type accepts only closed BAND wire or bound native handoff', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final identity = <String, dynamic>{
        'notificationId': '50000000-0000-4000-8000-000000000001',
        'recipientId': '70000000-0000-4000-8000-000000000001',
        'type': type,
      };
      final wire = <String, dynamic>{
        ...identity,
        'presentationVersion': 'ANDROID_BAND_V1',
        'displayVariant': 'DEFAULT',
        'sentAt': '${now - 1000}',
        'expiresAt': '${now + 300000}',
      };
      expect(PushTarget.parse(identity)?.isBand, isTrue);
      expect(PushTarget.parse(wire)?.isBand, isTrue);
      // Real Vivo clock measured about 640 ms behind the API during fast FCM delivery.
      expect(PushTarget.parse({...wire, 'sentAt': '${now + 1000}'})?.isBand, isTrue);
      expect(PushTarget.parse({...wire, 'sentAt': '${now + 1000}', 'expiresAt': '${now - 1}'}), isNull);
      for (final field in wire.keys) {
        final bad = {...wire}..remove(field);
        expect(PushTarget.parse(bad), isNull, reason: field);
      }
      for (final field in [
        'bandId',
        'invitationId',
        'inviterId',
        'memberId',
        'requesterId',
        'actorId',
        'targetId',
        'avatarUrl',
        'commentId',
        'sourceUrl',
        'conversationId',
      ]) {
        expect(
          PushTarget.parse({...wire, field: 'private'}),
          isNull,
          reason: field,
        );
      }
      for (final update in [
        {'presentationVersion': 'ANDROID_FOLLOW_V1'},
        {'presentationVersion': 'ANDROID_BAND_V2'},
        {'displayVariant': 'OTHER'},
        {'sentAt': '${now + 60000}'},
        {'expiresAt': '${now - 1}'},
        {'recipientId': 'wrong'},
      ]) {
        expect(PushTarget.parse({...wire, ...update}), isNull);
      }
    });
  }
}
