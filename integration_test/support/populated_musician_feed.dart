import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/band_follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_repository.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';

/// The benchmark never starts the application bootstrap or accesses credentials.
/// Its domain session exists in RAM and is not a JWT accepted by any API.
class BenchmarkSessions extends Fake implements AuthSessionManager {
  @override
  final session = AuthSession.authenticated(
    token: 'in-memory-performance-fixture-not-a-jwt',
    userId: 'performance-fixture-viewer',
    username: 'performans_kontrolu',
    accountStatus: 'ACTIVE',
    roles: ['MUSICIAN'],
    permissions: [],
    expiresAt: DateTime.utc(2100),
    isAdmin: false,
  );
}

// Unused mutations fail closed through Fake.noSuchMethod. No real repository
// implementation, notification service, or analytics transport is constructed.
class BenchmarkEngagement extends Fake implements EngagementRepository {}

class BenchmarkCollab extends Fake implements CollabRepository {}

class BenchmarkFollow extends Fake implements FollowRepository {}

class BenchmarkBandFollow extends Fake implements BandFollowRepository {}

class PopulatedFeedRepository extends Fake implements MusicianFeedRepository {
  PopulatedFeedRepository(this.images);

  final BenchmarkImages images;
  static const totalItems = 126;
  static const mixedEventPosters = bool.fromEnvironment(
    'FEED_PROFILE_MIXED_EVENT_POSTERS',
  );
  final loadCursors = <String?>[];
  final deliveredItemIds = <String>{};
  int impressionCount = 0;
  int _session = 0;

  @override
  Future<Result<MusicianFeedPage>> load({
    required int limit,
    String? cursor,
  }) async {
    loadCursors.add(cursor);
    if (cursor == null) _session++;
    final session = _session;
    final start = cursor == null ? 0 : int.parse(cursor.split(':').last);
    // This is controlled repository latency, not a backend latency measurement.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final end = (start + limit).clamp(0, totalItems);
    final items = [for (var index = start; index < end; index++) _item(index)];
    deliveredItemIds.addAll(items.map((item) => item.id));
    return Result.success(
      MusicianFeedPage(
        schemaVersion: musicianFeedSchemaVersion,
        algorithmVersion: 'performance-fixture-v1',
        feedSessionId: 'fixture-session-$session',
        generatedAt: DateTime.utc(2026, 9, 13),
        items: items,
        nextCursor: end < totalItems ? '$session:$end' : null,
        hasMore: end < totalItems,
      ),
    );
  }

  @override
  Future<Result<void>> recordEvent({
    required String clientEventId,
    required String impressionToken,
    required MusicianFeedTelemetryEventType eventType,
    DateTime? occurredAt,
  }) async {
    if (eventType == MusicianFeedTelemetryEventType.impression) {
      impressionCount++;
    }
    return const Result.success(null);
  }

  MusicianFeedActor _actor(int index) => MusicianFeedActor(
    userId: 'fixture-user-$index',
    profileId: 'fixture-musician-$index',
    profileType: 'MUSICIAN',
    username: ['ada_gitar', 'selin_vokal', 'emre_davul'][index % 3],
    displayName: 'Prova Müzisyeni $index',
    avatarUrl: images.url('avatar-$index.png'),
    followedByViewer: true,
  );

  MusicianFeedItem _item(int index) {
    final actor = _actor(index);
    final image = images.url('poster-$index.png');
    final track = TrackFeedPayload(
      trackId: 'fixture-track-$index',
      mediaAssetId: 'fixture-audio-$index',
      title: 'Gece Provası / Akustik Kayıt $index',
      playbackUrl: null,
      durationSeconds: 183,
      bpm: 112,
    );
    final (type, payload) = switch (index % 7) {
      0 => (
        MusicianFeedItemType.event,
        EventFeedPayload(
          event: {
            'id': 'fixture-event-$index',
            'title': 'Kadıköy Akustik Gecesi $index',
            'performerName': actor.username,
            'musicianProfileId': actor.profileId,
            'performerType': 'MUSICIAN',
            'venueId': 'fixture-venue-$index',
            'venueName': 'Kıyı Sahne',
            'venueCity': 'İstanbul',
            'venueDistrict': 'Kadıköy',
            'eventDate': '2026-09-20',
            'startTime': '20:00',
            'endTime': '23:00',
            'posterImageUrl': mixedEventPosters && index % 14 == 7
                ? null
                : image,
            'description':
                'Bağımsız müzisyenlerle canlı performans ve ortak üretim.',
          },
          note:
              'Bu hafta birlikte sahnedeyiz. Yeni düzenlemelerimizi dinleyin.',
          publicationId: null,
        ),
      ),
      1 => (
        MusicianFeedItemType.profile,
        ProfileFeedPayload(
          profileId: actor.profileId!,
          profileType: actor.profileType,
          userId: actor.userId,
          username: actor.username,
          displayName: actor.displayName,
          avatarUrl: actor.avatarUrl,
          bio:
              'Alternatif rock, caz ve akustik projelerde gitar çalıyorum. '
              'Düzenli provalar ve yeni sahne arkadaşları için buradayım.',
          location: 'İstanbul, Kadıköy',
          followedByViewer: false,
        ),
      ),
      2 => (MusicianFeedItemType.track, track),
      3 => (
        MusicianFeedItemType.profileMedia,
        ProfileMediaFeedPayload(
          mediaAssetId: 'fixture-photo-$index',
          kind: 'IMAGE',
          displayUrl: image,
          playbackUrl: null,
          thumbnailUrl: image,
          title: 'Stüdyodan notlar $index',
          description:
              'Birlikte çalmanın en güzel yanı aynı melodiyi farklı '
              'yorumlarla yeniden keşfetmek. Son provadan bir kare.',
          durationSeconds: null,
          width: 1500,
          height: 450,
        ),
      ),
      4 => (
        MusicianFeedItemType.activityLike,
        ActivityFeedPayload(
          action: 'LIKE',
          actor: actor,
          targetItemType: MusicianFeedItemType.track,
          targetPayload: track,
        ),
      ),
      5 => (
        MusicianFeedItemType.tableGroupProfileShare,
        ProfileShareFeedPayload(
          shareId: 'fixture-share-$index',
          note:
              'Bağımsız sahneler ve ortak üretim üzerine konuşmak isteyenleri '
              'bu masaya bekliyoruz.',
          publishedAt: DateTime.utc(2026, 9, 13),
          source: {
            'tableGroupId': 'fixture-table-$index',
            'title': 'Yeni sahneler, yeni şarkılar: birlikte üretelim',
            'description':
                'Prova deneyimleri, sahne hazırlığı ve kayıt fikirleri.',
          },
        ),
      ),
      _ => (
        MusicianFeedItemType.collab,
        CollabFeedPayload(
          listing: {
            'id': 'fixture-listing-$index',
            'version': 1,
            'status': 'OPEN',
            'cadence': 'REGULAR',
            'wantedType': 'MUSICIAN',
            'instrument': {'id': 'fixture-bass', 'name': 'Bas Gitar'},
            'title': 'Haftalık sahne için bas gitarist aranıyor $index',
            'description':
                'Alternatif rock repertuvarı ve düzenli prova programı.',
            'city': {'id': 'fixture-istanbul', 'name': 'İstanbul'},
            'genres': ['Rock', 'Alternatif'],
            'expiresAt': '2026-10-01T12:00:00Z',
            'feeStatus': 'UNSPECIFIED',
            'publishedAt': '2026-09-13T10:00:00Z',
            'createdAt': '2026-09-13T09:55:00Z',
            'publisher': {
              'actorId': 'fixture-actor-$index',
              'profileType': 'VENUE',
              'sourceProfileId': 'fixture-venue-$index',
              'contactUserId': 'fixture-venue-user-$index',
              'displayName': 'Kıyı Sahne',
              'avatarUrl': actor.avatarUrl,
              'rating': 4.8,
              'reviewCount': 12,
              'completedJobCount': 31,
            },
            'ownedByMe': false,
            'appliedByMe': false,
            'savedByMe': false,
            'applicationCount': 4,
          },
        ),
      ),
    };
    return MusicianFeedItem(
      id: 'fixture-item-$index',
      type: type,
      payloadVersion: 1,
      occurredAt: DateTime.utc(
        2026,
        9,
        13,
        12,
      ).subtract(Duration(minutes: index)),
      position: index,
      impressionToken: 'in-memory-impression-$_session-$index',
      reason: MusicianFeedReason(
        code: type == MusicianFeedItemType.activityLike
            ? 'FOLLOWING_ACTIVITY_LIKE'
            : 'FOLLOWING_PUBLICATION',
        actors: type == MusicianFeedItemType.activityLike ? [actor] : [],
        secondaryActorCount: 0,
      ),
      author: actor,
      target: MusicianFeedTarget(type: 'TRACK', id: 'fixture-track-$index'),
      engagement: MusicianFeedEngagement(
        targetType: 'TRACK',
        targetId: 'fixture-track-$index',
        likeCount: 23 + index * 7,
        commentCount: 3 + index % 12,
        likedByMe: index.isEven,
        likable: true,
        commentable: true,
      ),
      promotion: null,
      feedbackCapabilities: MusicianFeedFeedbackAction.values.toSet(),
      payload: payload,
    );
  }
}

/// Test-only transport boundary. Production HTTPS validation and image widgets
/// stay unchanged. CDN/TLS latency is deliberately outside this render test.
class BenchmarkImages extends HttpOverrides {
  BenchmarkImages._(this.server, this.assets, this.previous);

  final HttpServer server;
  final List<Uint8List> assets;
  final HttpOverrides? previous;
  final urls = <String>{};
  final runId = DateTime.now().microsecondsSinceEpoch.toString();
  int requests = 0;
  int servedBytes = 0;
  int blockedRequests = 0;

  static Future<BenchmarkImages> start() async {
    final assets = await Future.wait([
      rootBundle.load('assets/logo.png'),
      rootBundle.load('assets/buraya_bakarlar_1500x450_v2.png'),
    ]);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final images = BenchmarkImages._(
      server,
      assets.map((asset) => asset.buffer.asUint8List()).toList(),
      HttpOverrides.current,
    );
    server.listen((request) async {
      final bytes = images.assets[request.uri.path.contains('avatar-') ? 0 : 1];
      images.requests++;
      images.servedBytes += bytes.length;
      request.response
        ..headers.contentType = ContentType('image', 'png')
        ..headers.set(HttpHeaders.cacheControlHeader, 'max-age=3600')
        ..contentLength = bytes.length
        ..add(bytes);
      await request.response.close();
    });
    HttpOverrides.global = images;
    return images;
  }

  String url(String name) {
    final url = 'https://feed-profile.invalid/$runId/$name';
    urls.add(url);
    return url;
  }

  Uri route(Uri uri) {
    if (uri.scheme == 'https' && uri.host == 'feed-profile.invalid') {
      return uri.replace(scheme: 'http', host: '127.0.0.1', port: server.port);
    }
    // The integration binding uses the loopback VM service for its timeline.
    if ({'127.0.0.1', 'localhost', '::1'}.contains(uri.host)) return uri;
    blockedRequests++;
    throw StateError('External network is disabled in the feed benchmark.');
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FixtureHttpClient(super.createHttpClient(context), route);

  Future<void> close() async {
    for (final url in urls) {
      // Remove only this run's namespaced fixture entries; retain user imagery.
      await AppImageCacheManager.compact.removeFile(url);
    }
    await server.close(force: true);
    HttpOverrides.global = previous;
  }
}

class _FixtureHttpClient extends Fake implements HttpClient {
  _FixtureHttpClient(this.inner, this.route);
  final HttpClient inner;
  final Uri Function(Uri) route;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      inner.openUrl(method, route(url));

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  String? get userAgent => inner.userAgent;

  @override
  set userAgent(String? value) => inner.userAgent = value;

  @override
  bool get autoUncompress => inner.autoUncompress;

  @override
  set autoUncompress(bool value) => inner.autoUncompress = value;

  @override
  void close({bool force = false}) => inner.close(force: force);
}
