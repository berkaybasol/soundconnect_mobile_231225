import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/models/dm_conversation_preview_model.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/models/dm_message_model.dart';

void main() {
  // The DM API uses UTC LocalDateTime values without an offset. The actual
  // studio device fixture was shown as 01:12 in Istanbul instead of 04:12.
  test(
    'DM UTC wall-clock fields preserve the actual instant and precision',
    () {
      const raw = '2026-09-24T01:12:37.842987';
      final expected = DateTime.utc(2026, 9, 24, 1, 12, 37, 842, 987);
      final message = DmMessageModel.fromJson({
        'sentAt': raw,
        'readAt': raw,
        'deletedAt': raw,
      });
      final preview = DmConversationPreviewModel.fromJson({
        'lastMessageAt': raw,
      });

      for (final value in [
        message.sentAt,
        message.readAt,
        message.deletedAt,
        preview.lastMessageAt,
      ]) {
        expect(value, expected);
        expect(value!.isUtc, isTrue);
        expect(value.toLocal(), expected.toLocal());
      }
    },
  );

  final explicitZones = {
    '2026-09-24T01:12:37.842987Z': DateTime.utc(
      2026,
      9,
      24,
      1,
      12,
      37,
      842,
      987,
    ),
    '2026-09-24T04:12:37.842987+03:00': DateTime.utc(
      2026,
      9,
      24,
      1,
      12,
      37,
      842,
      987,
    ),
    '2026-09-23T18:12:37.842987-07:00': DateTime.utc(
      2026,
      9,
      24,
      1,
      12,
      37,
      842,
      987,
    ),
  };
  for (final entry in explicitZones.entries) {
    test('DM retains an explicit timestamp offset: ${entry.key}', () {
      final message = DmMessageModel.fromJson({'sentAt': entry.key});
      final preview = DmConversationPreviewModel.fromJson({
        'lastMessageAt': entry.key,
      });
      expect(message.sentAt, entry.value);
      expect(preview.lastMessageAt, entry.value);
    });
  }

  test('naive UTC timestamp near midnight retains the UTC calendar date', () {
    const raw = '2026-09-23T23:59:00';
    final message = DmMessageModel.fromJson({'sentAt': raw});
    final preview = DmConversationPreviewModel.fromJson({'lastMessageAt': raw});
    final expected = DateTime.utc(2026, 9, 23, 23, 59);
    expect(message.sentAt, expected);
    expect(message.sentAt!.isUtc, isTrue);
    expect(preview.lastMessageAt, expected);
    // Presentation already calls toLocal; the model must supply the same
    // instant on UTC, Istanbul and other device time zones.
    expect(message.sentAt!.toLocal(), expected.toLocal());
  });

  test(
    'DM timestamp parsing trims whitespace and keeps absent values null',
    () {
      final message = DmMessageModel.fromJson({
        'sentAt': ' 2026-09-24T01:12:00 ',
        'readAt': ' ',
        'deletedAt': 'invalid',
      });
      expect(message.sentAt, DateTime.utc(2026, 9, 24, 1, 12));
      expect(message.readAt, isNull);
      expect(message.deletedAt, isNull);
      expect(DmConversationPreviewModel.fromJson({}).lastMessageAt, isNull);
    },
  );
}
