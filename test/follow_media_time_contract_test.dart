import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';

Map<String, dynamic> wire(String type, String sent, String expiry) => {
  'notificationId': '50000000-0000-4000-8000-000000000001',
  'recipientId': '70000000-0000-4000-8000-000000000001',
  'type': type,
  'presentationVersion': PushTarget.followTypes.contains(type)
      ? 'ANDROID_FOLLOW_V1'
      : PushTarget.mediaTypes.contains(type)
      ? 'ANDROID_MEDIA_V1'
      : 'ANDROID_BAND_V1',
  'displayVariant': 'DEFAULT',
  'sentAt': sent == '<empty>' ? '' : sent,
  'expiresAt': expiry == '<empty>' ? '' : expiry,
};

void main() {
  final cases = File('test/fixtures/follow_media_time_contract.tsv')
      .readAsLinesSync()
      .skip(1)
      .where((line) => line.isNotEmpty)
      .map((line) => line.split('\t'))
      .toList();
  for (final type in {...PushTarget.followTypes, ...PushTarget.mediaTypes}) {
    for (final row in cases) {
      test('$type temporal ${row[0]}', () {
        final result = PushTarget.parse(
          wire(type, row[2], row[3]),
          nowMillis: int.parse(row[1]),
        );
        expect(result != null, row[4] == 'true');
        if (result != null) {
          expect(result.type, type);
          expect(result.notificationId, '50000000-0000-4000-8000-000000000001');
          expect(result.recipientId, '70000000-0000-4000-8000-000000000001');
          expect(result.conversationId, isNull);
        }
      });
    }
    test(
      '$type timestamps require canonical string wire; native handoff stays valid',
      () {
        const now = 1790000000000;
        final data = wire(type, '$now', '${now + 60000}');
        for (final field in ['sentAt', 'expiresAt']) {
          for (final value in [now, now.toDouble(), null, true]) {
            expect(
              PushTarget.parse({...data, field: value}, nowMillis: now),
              isNull,
            );
          }
        }
        expect(
          PushTarget.parse({
            'notificationId': data['notificationId'],
            'recipientId': data['recipientId'],
            'type': type,
          })?.type,
          type,
        );
      },
    );
  }
  for (final type in PushTarget.bandTypes) {
    test('$type keeps bounded skew and its existing temporal contract', () {
      const now = 1790000000000;
      const ttl = 2419200000;
      for (final skew in [0, 640, 5000, 5001]) {
        expect(
          PushTarget.parse(
                wire(type, '${now + skew}', '${now + 60000}'),
                nowMillis: now,
              ) !=
              null,
          skew <= 5000,
        );
      }
      expect(
        PushTarget.parse(wire(type, '$now', '$now'), nowMillis: now),
        isNull,
      );
      expect(
        PushTarget.parse(
          wire(type, '$now', '${now + ttl + 1}'),
          nowMillis: now,
        ),
        isNull,
      );
      // Existing BAND-only parser differences are outside this FOLLOW/MEDIA fix.
      expect(
        PushTarget.parse(wire(type, '+$now', '${now + 60000}'), nowMillis: now),
        isNotNull,
      );
      expect(
        PushTarget.parse(
          wire(type, '${now + 640}', '${now + 640 + ttl}'),
          nowMillis: now,
        ),
        isNotNull,
      );
    });
  }
}
