import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/models/comment_item_model.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/comment_age.dart';

import 'support/recording_api_client.dart';

void main() {
  for (final parent in <String?>[null, 'root']) {
    test(
      'fresh legacy UTC ${parent == null ? 'root' : 'reply'} is not three hours old on a local clock',
      () {
        final localNow = DateTime.utc(2026, 9, 8, 12, 0, 10).toLocal();
        // The focused Turkey run opts in so a UTC-only test environment cannot
        // silently pass as evidence that the reported device bug is reproduced.
        if (const bool.fromEnvironment('COMMENT_TEST_REQUIRE_ISTANBUL')) {
          expect(localNow.timeZoneOffset, const Duration(hours: 3));
          expect(
            localNow.difference(DateTime.parse('2026-09-08T12:00:00')),
            const Duration(hours: 3, seconds: 10),
          );
        }
        expect(localNow.isUtc, isFalse);
        final item = CommentItemModel.fromJson(
          _comment('2026-09-08T12:00:00', parent: parent),
        );
        expect(
          localNow.difference(item.createdAt!),
          const Duration(seconds: 10),
        );
        expect(item.createdAt!.isUtc, isTrue);
      },
    );
  }

  for (final wire in [
    '2026-09-08T12:00:00',
    '2026-09-08T12:00:00Z',
    '2026-09-08T15:00:00+03:00',
    '2026-09-08T05:00:00-07:00',
    '2026-09-08T17:30:00+05:30',
  ]) {
    test('$wire preserves the same UTC instant without a fixed shift', () {
      final item = CommentItemModel.fromJson(_comment(wire));
      expect(item.createdAt, DateTime.utc(2026, 9, 8, 12));
      expect(item.createdAt!.isUtc, isTrue);
      for (final currentClock in [
        DateTime.utc(2026, 9, 8, 12, 0, 10),
        DateTime.utc(2026, 9, 8, 12, 0, 10).toLocal(),
      ]) {
        expect(
          currentClock.difference(item.createdAt!),
          const Duration(seconds: 10),
        );
      }
    });
  }

  test('legacy and offset fractional timestamps preserve microseconds', () {
    for (final wire in [
      '2026-09-08T12:00:00.123456789',
      '2026-09-08T12:00:00.123456789Z',
      '2026-09-08T15:00:00.123456789+03:00',
    ]) {
      expect(
        CommentItemModel.fromJson(_comment(wire)).createdAt,
        DateTime.utc(2026, 9, 8, 12, 0, 0, 123, 456),
      );
    }
  });

  test('explicit offset crossing midnight preserves the preceding UTC day', () {
    expect(
      CommentItemModel.fromJson(
        _comment('2026-09-09T00:00:00+03:00'),
      ).createdAt,
      DateTime.utc(2026, 9, 8, 21),
    );
  });

  test('missing or malformed timestamp does not become a fabricated time', () {
    for (final raw in [null, '', 'not-a-timestamp']) {
      expect(CommentItemModel.fromJson(_comment(raw)).createdAt, isNull);
    }
  });

  test(
    'missing age is empty and future timestamps never show negative age',
    () {
      final now = DateTime.utc(2026, 9, 8, 12);
      expect(formatCommentAge(null, now: now), '');
      for (final ahead in [
        Duration.zero,
        const Duration(seconds: 30),
        const Duration(hours: 3),
      ]) {
        expect(formatCommentAge(now.add(ahead), now: now), 'Az önce');
      }
    },
  );

  for (final boundary in <(Duration, String)>[
    (const Duration(seconds: 59), 'Az önce'),
    (const Duration(seconds: 60), '1 dk önce'),
    (const Duration(minutes: 59), '59 dk önce'),
    (const Duration(minutes: 60), '1 saat önce'),
    (const Duration(hours: 23), '23 saat önce'),
    (const Duration(hours: 24), '1 gün önce'),
    (const Duration(days: 3), '3 gün önce'),
  ]) {
    test(
      'comment age ${boundary.$1} renders ${boundary.$2} for every zone form',
      () {
        for (final wire in [
          '2026-09-08T12:00:00',
          '2026-09-08T12:00:00Z',
          '2026-09-08T15:00:00+03:00',
          '2026-09-08T05:00:00-07:00',
        ]) {
          final createdAt = CommentItemModel.fromJson(_comment(wire)).createdAt;
          final instantNow = DateTime.utc(2026, 9, 8, 12).add(boundary.$1);
          expect(formatCommentAge(createdAt, now: instantNow), boundary.$2);
          expect(
            formatCommentAge(createdAt, now: instantNow.toLocal()),
            boundary.$2,
          );
        }
      },
    );
  }

  for (final target in ['EVENT', 'MEDIA', 'OVERTHINKING_POST']) {
    for (final parent in <String?>[null, 'root']) {
      test(
        '$target ${parent == null ? 'root' : 'reply'} create and page use UTC comment decoding',
        () async {
          for (final wire in [
            '2026-09-08T12:00:00',
            '2026-09-08T12:00:00Z',
            '2026-09-08T15:00:00+03:00',
          ]) {
            final api = RecordingApiClient(
              (request) => request.method == RecordedHttpMethod.post
                  ? _comment(wire, parent: parent)
                  : {
                      'content': [_comment(wire, parent: parent)],
                      'totalElements': 1,
                      'number': 0,
                      'size': 20,
                    },
            );
            final repository = EngagementRepositoryImpl(api);
            final page = parent == null
                ? await repository.listComments(
                    targetType: target,
                    targetId: 'target',
                  )
                : await repository.listReplyPage(
                    parent,
                    eventId: target == 'EVENT' ? 'target' : null,
                  );
            final created = await repository.createComment(
              targetType: target,
              targetId: 'target',
              text: 'a',
              parentCommentId: parent,
            );
            expect(page.isSuccess, isTrue);
            expect(created.isSuccess, isTrue);
            for (final item in [page.data!.items.single, created.data!]) {
              expect(item.createdAt, DateTime.utc(2026, 9, 8, 12));
              expect(item.createdAt!.isUtc, isTrue);
            }
          }
        },
      );
    }
  }
}

Map<String, dynamic> _comment(Object? createdAt, {String? parent}) => {
  'id': 'comment',
  'text': 'a',
  'parentCommentId': parent,
  'deleted': false,
  'anonymousAuthor': false,
  'replyCount': 0,
  'createdAt': createdAt,
  'user': {'id': 'author', 'username': 'Ada'},
};
