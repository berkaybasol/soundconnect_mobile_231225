import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/domain/entities/announcement.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/domain/entities/announcement_statistics.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/data/promotion_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/media_gallery_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';
import 'support/announcement_fixtures.dart';
import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  test(
    'announcement projection retains audience/hidden state and private asset metadata',
    () {
      final item = Announcement.fromJson(
        announcementFixture(hidden: true, media: true),
      );
      expect(item.id, announcementFixtureId);
      expect(item.feedHidden, isTrue);
      expect(item.targetProfiles, {'MUSICIAN', 'LISTENER'});
      expect(item.media!.assetId, announcementFixtureAssetId);
      expect(item.media!.aspectRatio, 1.5);
      expect(item.engagement.likeCount, 7);
    },
  );
  for (final invalid in <Map<String, dynamic>>[
    {'id': '../wrong'},
    {'version': -1},
    {'title': ''},
    {'body': ' '},
    {'targetProfiles': []},
    {
      'targetProfiles': ['ADMIN'],
    },
    {'status': 'UNKNOWN'},
    {'feedHidden': 'false'},
    {'createdAt': '2026-09-13T09:00:00'},
    {
      'engagement': {'likeCount': -1, 'commentCount': 0, 'likedByMe': false},
    },
  ]) {
    test(
      'malformed announcement fails closed: ${invalid.keys.single}',
      () => expect(
        () => Announcement.fromJson({...announcementFixture(), ...invalid}),
        throwsFormatException,
      ),
    );
  }
  test(
    'directory includes hidden records and rejects broken cursor/duplicate pages',
    () {
      final page = AnnouncementPage.fromJson({
        'items': [announcementFixture(hidden: true)],
        'hasMore': true,
        'nextCursor': 'opaque',
      });
      expect(page.items.single.feedHidden, isTrue);
      for (final broken in [
        {'items': [], 'hasMore': true, 'nextCursor': 'cursor'},
        {
          'items': [announcementFixture(), announcementFixture()],
          'hasMore': false,
          'nextCursor': null,
        },
        {
          'items': [announcementFixture()],
          'hasMore': false,
          'nextCursor': 'unused',
        },
      ]) {
        expect(() => AnnouncementPage.fromJson(broken), throwsFormatException);
      }
    },
  );
  test('only published announcements enter the feed parser', () {
    final item =
        MusicianFeedPayload.parse(
              MusicianFeedItemType.announcement,
              announcementFixture(),
              'payload',
            )
            as AnnouncementFeedPayload;
    expect(item.announcement.id, announcementFixtureId);
    expect(
      () => MusicianFeedPayload.parse(
        MusicianFeedItemType.announcement,
        announcementFixture(status: 'DRAFT'),
        'payload',
      ),
      throwsA(isA<MusicianFeedFormatException>()),
    );
  });
  test(
    'CRUD uses Promotion routes, expected versions and UTC schedule',
    () async {
      final sessions = AudienceTestSessions(announcementAdminSession());
      addTearDown(sessions.dispose);
      final api = RecordingApiClient(
        (request) => request.method == RecordedHttpMethod.delete
            ? null
            : announcementFixture(status: 'DRAFT'),
      );
      final repository = PromotionRepositoryImpl(api, sessions: sessions);
      const write = AnnouncementWrite(
        title: ' Başlık ',
        body: ' Metin ',
        targetProfiles: {'MUSICIAN'},
        mediaAssetId: announcementFixtureAssetId,
      );
      expect((await repository.createAnnouncement(write)).isSuccess, isTrue);
      expect(api.lastRequest.path, '/api/v1/admin/feed/announcements');
      expect(api.lastRequest.body, {
        'title': 'Başlık',
        'body': 'Metin',
        'targetProfiles': ['MUSICIAN'],
        'mediaAssetId': announcementFixtureAssetId,
      });
      expect(
        (await repository.updateAnnouncement(
          announcementFixtureId,
          write,
          expectedVersion: 2,
        )).isSuccess,
        isTrue,
      );
      expect((api.lastRequest.body as Map)['expectedVersion'], 2);
      final start = DateTime.parse('2027-01-01T15:00:00+03:00');
      await repository.publishAnnouncement(
        announcementFixtureId,
        expectedVersion: 2,
        startsAt: start,
        endsAt: start.add(const Duration(days: 1)),
      );
      expect(api.lastRequest.path.endsWith('/publish'), isTrue);
      expect(
        (api.lastRequest.body as Map)['startsAt'],
        '2027-01-01T12:00:00.000Z',
      );
      await repository.endAnnouncement(
        announcementFixtureId,
        expectedVersion: 2,
      );
      expect(api.lastRequest.path.endsWith('/end'), isTrue);
      await repository.archiveAnnouncement(
        announcementFixtureId,
        expectedVersion: 2,
      );
      expect(api.lastRequest.path.endsWith('/archive'), isTrue);
      await repository.deleteAnnouncement(
        announcementFixtureId,
        expectedVersion: 2,
      );
      expect(api.lastRequest.query, {'version': 2});
      for (final request in api.requests) {
        expect(request.requestContext?.expectedSessionKey, 'admin');
        expect(request.requestContext?.expectedToken, 'admin-token');
      }
    },
  );
  test(
    'admin permission checked before transport and A-B-A response never escapes fence',
    () async {
      final sessions = AudienceTestSessions(
        announcementAdminSession(permitted: false),
      );
      addTearDown(sessions.dispose);
      final pending = Completer<Object?>();
      final api = RecordingApiClient((_) => pending.future);
      final repository = PromotionRepositoryImpl(api, sessions: sessions);
      expect(
        (await repository.announcement(
          announcementFixtureId,
          admin: true,
        )).isSuccess,
        isFalse,
      );
      expect(api.requests, isEmpty);
      final identity = announcementAdminSession();
      sessions.replace(identity);
      final result = repository.announcement(
        announcementFixtureId,
        admin: true,
      );
      sessions.replace(const AuthSession.guest());
      sessions.replace(identity);
      pending.complete(announcementFixture());
      expect((await result).error?.code, 'announcement_access_changed');
    },
  );
  test(
    'invalid identifiers/limits/public status and nonadvancing cursor do not succeed',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final api = RecordingApiClient(
        (_) => {
          'items': [announcementFixture()],
          'hasMore': true,
          'nextCursor': 'same',
        },
      );
      final repository = PromotionRepositoryImpl(api, sessions: sessions);
      expect((await repository.announcement('../x')).isSuccess, isFalse);
      expect((await repository.announcements(limit: 51)).isSuccess, isFalse);
      expect(
        (await repository.announcements(
          status: AnnouncementStatus.draft,
        )).isSuccess,
        isFalse,
      );
      expect(api.requests, isEmpty);
      expect(
        (await repository.announcements(cursor: 'same')).isSuccess,
        isFalse,
      );
      expect(api.lastRequest.path, '/api/v1/announcements');
    },
  );
  test(
    'private media resolver validates identity/expiry and fences response revocation',
    () async {
      final identity = audienceSession();
      final sessions = AudienceTestSessions(identity);
      addTearDown(sessions.dispose);
      final data = {
        'assetId': announcementFixtureAssetId,
        'accessUrl': 'https://media.example.test/private.jpg?signature=secret',
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
        'thumbnailAccessUrl': null,
        'thumbnailExpiresAt': null,
        'streamingProtocol': null,
      };
      final api = RecordingApiClient((_) => data);
      final repository = MediaGalleryRepositoryImpl(api, sessions: sessions);
      expect(
        (await repository.getAccess(announcementFixtureAssetId)).isSuccess,
        isTrue,
      );
      expect(
        api.lastRequest.path,
        '/api/v1/user/media/$announcementFixtureAssetId/access-url',
      );
      expect(api.lastRequest.requestContext?.expectedToken, identity.token);
      data['assetId'] = announcementFixtureId;
      expect(
        (await repository.getAccess(announcementFixtureAssetId)).isSuccess,
        isFalse,
      );
      data['assetId'] = announcementFixtureAssetId;
      data['expiresAt'] = '2020-01-01T00:00:00Z';
      expect(
        (await repository.getAccess(announcementFixtureAssetId)).isSuccess,
        isFalse,
      );
      final pending = Completer<Object?>();
      final delayed = MediaGalleryRepositoryImpl(
        RecordingApiClient((_) => pending.future),
        sessions: sessions,
      );
      data['expiresAt'] = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 15))
          .toIso8601String();
      final result = delayed.getAccess(announcementFixtureAssetId);
      sessions.replace(const AuthSession.guest());
      sessions.replace(identity);
      pending.complete(data);
      expect((await result).isSuccess, isFalse);
    },
  );
  test(
    'announcement engagement reuses existing requests with scoped attribution',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      for (final source in ['FEED', 'DIRECTORY']) {
        final api = RecordingApiClient((_) => null);
        final repository = EngagementRepositoryImpl(
          api,
          sessions: sessions,
          announcementSource: source,
        );
        expect(
          (await repository.like(
            targetType: 'ANNOUNCEMENT',
            targetId: announcementFixtureId,
          )).isSuccess,
          isTrue,
        );
        expect(
          api.lastRequest.path,
          '/api/v1/likes/ANNOUNCEMENT/$announcementFixtureId',
        );
        expect(api.lastRequest.requestContext?.announcementSource, source);
      }
    },
  );
  test(
    'statistics preserve server unique reach rather than summing daily values',
    () {
      Map<String, int> metrics(int unique) => {
        for (final key in AnnouncementStatistics.metricLabels.keys)
          key: key == 'uniqueReach' ? unique : 1,
      };
      final stats = AnnouncementStatistics.fromJson({
        'announcementId': announcementFixtureId,
        'fromDate': '2026-09-12',
        'toDate': '2026-09-13',
        'timeZone': 'Europe/Istanbul',
        'updatedAt': '2026-09-13T12:00:00Z',
        'metrics': metrics(5),
        'daily': [
          {'date': '2026-09-12', 'metrics': metrics(4)},
          {'date': '2026-09-13', 'metrics': metrics(4)},
        ],
      });
      expect(stats.metrics['uniqueReach'], 5);
      expect(
        stats.daily.fold(0, (sum, day) => sum + day.metrics['uniqueReach']!),
        8,
      );
    },
  );
}
