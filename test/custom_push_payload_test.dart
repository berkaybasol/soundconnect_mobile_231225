import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';

void main() {
  const now = 1790000000000;
  const identity = <String, dynamic>{
    'notificationId': '50000000-0000-4000-8000-000000000001',
    'recipientId': '70000000-0000-4000-8000-000000000001',
    'type': 'ADMIN_BROADCAST',
  };
  Map<String, dynamic> wire() => {
    ...identity,
    'presentationVersion': 'ANDROID_CUSTOM_V1',
    'title': 'Soundconnect\'te yeni bir şey var 🎵',
    'body': 'Birlikte müzik yapmaya hazır mısın?',
    'sentAt': '$now',
    'expiresAt': '${now + 60000}',
  };

  test('custom wire and native identity have separate closed contracts', () {
    final valid = wire();
    expect(PushTarget.parse(valid, nowMillis: now)?.isCustom, isTrue);
    expect(PushTarget.parse(identity, nowMillis: now), isNull);
    expect(PushTarget.parseNativeMetadata(identity)?.isCustom, isTrue);
    expect(PushTarget.parseNativeMetadata(valid), isNull);
    for (final key in valid.keys) {
      expect(
        PushTarget.parse({...valid}..remove(key), nowMillis: now),
        isNull,
        reason: 'missing $key',
      );
    }
    for (final key in [
      'route',
      'url',
      'announcementId',
      'conversationId',
      'displayVariant',
      'avatarUrl',
    ]) {
      expect(
        PushTarget.parse({...valid, key: 'untrusted'}, nowMillis: now),
        isNull,
        reason: key,
      );
      expect(
        PushTarget.parseNativeMetadata({...identity, key: 'untrusted'}),
        isNull,
        reason: key,
      );
    }
    for (final patch in [
      {'type': 'ADMIN_UNKNOWN'},
      {'type': 'SOCIAL_NEW_FOLLOWER'},
      {'presentationVersion': 'ANDROID_CUSTOM_V2'},
      {'presentationVersion': 'ANDROID_OVERTHINKING_V1'},
      {'notificationId': 'broken'},
      {'recipientId': '1-1-1-1-1'},
    ]) {
      expect(
        PushTarget.parse({...valid, ...patch}, nowMillis: now),
        isNull,
        reason: '$patch',
      );
    }
    expect(
      PushTarget.parseNativeMetadata({...identity, 'type': 'ADMIN_UNKNOWN'}),
      isNull,
    );
  });

  for (final entry in {'title': 120, 'body': 500}.entries) {
    test(
      'custom ${entry.key} enforces UTF16 limits and safe normalized display copy',
      () {
        final valid = wire();
        for (final text in ['a' * entry.value, '🎵' * (entry.value ~/ 2)]) {
          expect(
            PushTarget.parse({...valid, entry.key: text}, nowMillis: now),
            isNotNull,
          );
        }
        for (final text in <Object?>[
          null,
          1,
          '',
          ' ',
          ' leading',
          'trailing ',
          'a' * (entry.value + 1),
          '${'🎵' * (entry.value ~/ 2)}a',
          'a\nline',
          'a\ttext',
          'a\u0000text',
          'a\u007Ftext',
          'a\u0085text',
          'a\u202Etext',
          'a\u2066text',
          'a\u200Btext',
          'a\u2028text',
          'a\u2029text',
          'a\uD800',
        ]) {
          expect(
            PushTarget.parse({...valid, entry.key: text}, nowMillis: now),
            isNull,
            reason: '${entry.key}: ${text.runtimeType}',
          );
        }
      },
    );
  }

  test(
    'custom times are canonical positive Longs with bounded skew and TTL',
    () {
      final valid = wire();
      for (final field in ['sentAt', 'expiresAt']) {
        for (final value in <Object?>[
          now,
          '+$now',
          '0$now',
          ' $now',
          '0',
          '-1',
          '9223372036854775808',
        ]) {
          expect(
            PushTarget.parse({...valid, field: value}, nowMillis: now),
            isNull,
            reason: '$field $value',
          );
        }
      }
      const ttl = Duration(days: 28);
      for (final patch in [
        {'sentAt': '${now + 5001}'},
        {'expiresAt': '$now'},
        {'expiresAt': '${now + ttl.inMilliseconds + 1}'},
        {'sentAt': '${now - ttl.inMilliseconds}', 'expiresAt': '${now + 1}'},
      ]) {
        expect(
          PushTarget.parse({...valid, ...patch}, nowMillis: now),
          isNull,
          reason: '$patch',
        );
      }
      expect(
        PushTarget.parse({...valid, 'sentAt': '${now + 5000}'}, nowMillis: now),
        isNotNull,
      );
      expect(
        PushTarget.parse({
          ...valid,
          'expiresAt': '${now + ttl.inMilliseconds}',
        }, nowMillis: now),
        isNotNull,
      );
      expect(PushTarget.parse(valid, nowMillis: -1), isNull);
    },
  );
}
