import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';

void main() {
  const now = 1790000000000;
  for (final type in PushTarget.overthinkingTypes) {
    test('$type separates native identity from complete six-key raw wire', () {
      final identity = <String, dynamic>{
        'notificationId': '50000000-0000-4000-8000-000000000001',
        'recipientId': '70000000-0000-4000-8000-000000000001',
        'type': type,
      };
      final wire = {...identity, 'presentationVersion': 'ANDROID_OVERTHINKING_V1',
        'sentAt': '$now', 'expiresAt': '${now + 60000}'};
      expect(PushTarget.parse(identity), isNull);
      expect(PushTarget.parseNativeMetadata(identity)?.isOverthinking, isTrue);
      expect(PushTarget.parseNativeMetadata(wire), isNull);
      expect(PushTarget.parse(wire, nowMillis: now)?.isOverthinking, isTrue);
      for (final key in wire.keys) {
        expect(PushTarget.parse({...wire}..remove(key), nowMillis: now), isNull, reason: key);
      }
      for (final key in ['postId','revealRequestId','authorId','requesterId','postTitle',
        'content','authorName','avatarUrl','conversationId','displayVariant','canViewAuthor']) {
        expect(PushTarget.parse({...wire,key:'private'},nowMillis:now),isNull,reason:key);
      }
      for (final patch in [
        {'presentationVersion':'ANDROID_COLLAB_V1'}, {'presentationVersion':'ANDROID_OVERTHINKING_V2'},
        {'type':'OVERTHINKING_UNKNOWN'}, {'type':'COLLAB_APPLICATION_RECEIVED'},
        {'recipientId':'bad'}, {'notificationId':'1-1-1-1-1'}, {'sentAt':now},
        {'sentAt':'+$now'}, {'sentAt':'0$now'}, {'sentAt':'${now + 5001}'},
        {'sentAt':'9223372036854775808'}, {'expiresAt':'$now'},
        {'expiresAt':'${now + const Duration(days:28).inMilliseconds + 1}'},
      ]) {
        expect(PushTarget.parse({...wire,...patch},nowMillis:now),isNull,reason:'$patch');
      }
      expect(PushTarget.parse({...wire,'sentAt':'${now + 5000}'},nowMillis:now),isNotNull);
      expect(PushTarget.parse(wire,nowMillis:-1),isNull);
    });
  }
}
