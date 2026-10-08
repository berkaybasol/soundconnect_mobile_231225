import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/models/collab_api_models.dart';
import 'package:soundconnect_23_12_25codx/modules/event/data/models/discovery_event_model.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/preview/data/preview_scenario_store.dart';
import 'package:soundconnect_23_12_25codx/preview/domain/preview_feed_scenario.dart';
import 'package:soundconnect_23_12_25codx/preview/runtime/preview_session.dart';
import 'package:soundconnect_23_12_25codx/preview/services/preview_api_client.dart';

void main() {
  late PreviewScenarioStore store;
  setUp(() => store = PreviewScenarioStore(now: DateTime.utc(2026, 9, 13, 12)));
  tearDown(() => store.dispose());

  test(
    'catalogue covers all production card families with stable unique identities',
    () {
      expect(store.catalogue, hasLength(62));
      expect(
        store.catalogue.map((s) => s.item.type).toSet(),
        MusicianFeedItemType.values.toSet(),
      );
      expect(
        store.catalogue.map((s) => s.id).toSet(),
        hasLength(store.catalogue.length),
      );
      expect(
        store.catalogue.map((s) => s.item.id).toSet(),
        hasLength(store.catalogue.length),
      );
      final other = PreviewScenarioStore(now: DateTime.utc(2027));
      addTearDown(other.dispose);
      expect(
        other.catalogue.map((s) => s.item.id),
        store.catalogue.map((s) => s.item.id),
      );
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      for (final scenario in store.catalogue) {
        expect(
          uuid.hasMatch(scenario.item.target!.id),
          isTrue,
          reason: scenario.id,
        );
      }
    },
  );

  test(
    'feed and nested activity payloads use canonical engagement identities',
    () {
      for (final scenario in store.catalogue) {
        final item = scenario.item;
        final payload = item.payload is ActivityFeedPayload
            ? (item.payload as ActivityFeedPayload).targetPayload
            : item.payload;
        if (payload is TrackFeedPayload) {
          expect(item.target!.type, 'MEDIA');
          expect(item.target!.id, payload.mediaAssetId);
        } else if (payload is ProfileMediaFeedPayload) {
          expect(item.target!.type, 'MEDIA');
          expect(item.target!.id, payload.mediaAssetId);
        } else if (payload is AnnouncementFeedPayload) {
          expect(item.target!.type, 'ANNOUNCEMENT');
          expect(item.target!.id, payload.announcement.id);
          expect(item.feedbackCapabilities, {MusicianFeedFeedbackAction.hide});
        } else if (payload is CollabFeedPayload) {
          final listing = CollabListingModel.fromJson(payload.listing);
          expect(item.target!.type, 'COLLAB');
          expect(item.target!.id, listing.id);
          expect(listing.genres.length, lessThanOrEqualTo(3));
          expect(item.author!.profileId, listing.publisher.sourceProfileId);
          expect(item.engagement, isNull);
        } else if (payload is EventFeedPayload) {
          final event = DiscoveryEventModel.fromJson(payload.event);
          expect(event.id, isNotEmpty);
          expect(event.title, isNotEmpty);
          expect(event.eventDate, isNotNull);
          expect(
            item.target!.type,
            item.type == MusicianFeedItemType.eventProfileShare
                ? 'EVENT_POST'
                : 'EVENT',
          );
          expect(
            item.target!.id,
            item.type == MusicianFeedItemType.eventProfileShare
                ? payload.publicationId
                : event.id,
          );
        } else if (payload is ProfileFeedPayload) {
          expect(item.target!.type, 'PROFILE');
          expect(item.target!.id, payload.profileId);
          if (item.type == MusicianFeedItemType.profile) {
            expect(item.author!.profileId, payload.profileId);
          }
        } else if (payload is CompletionFeedPayload) {
          expect(item.target!.id, previewViewerProfileId);
        }
        if (item.engagement != null) {
          expect(item.engagement!.targetType, item.target!.type);
          expect(item.engagement!.targetId, item.target!.id);
        }
      }
    },
  );

  test(
    'mixed composition is stable, includes three separated announcements and one completion',
    () {
      final mixed = store.mixedFeed;
      expect(mixed, hasLength(58));
      expect(mixed.map((s) => s.id).toSet(), hasLength(mixed.length));
      expect(
        mixed.where((s) => s.item.type == MusicianFeedItemType.announcement),
        hasLength(3),
      );
      expect(
        mixed.where(
          (s) => s.item.type == MusicianFeedItemType.profileCompletion,
        ),
        hasLength(1),
      );
      var normalSinceAnnouncement = 0;
      var announcementsSeen = 0;
      var previousCommercial = false;
      for (final scenario in mixed) {
        final announcement =
            scenario.item.type == MusicianFeedItemType.announcement;
        final commercial = announcement || scenario.item.promotion != null;
        expect(commercial && previousCommercial, isFalse, reason: scenario.id);
        if (announcement) {
          expect(
            normalSinceAnnouncement,
            greaterThanOrEqualTo(announcementsSeen == 0 ? 1 : 4),
          );
          if (announcementsSeen == 0) {
            expect(normalSinceAnnouncement, lessThanOrEqualTo(2));
          }
          announcementsSeen++;
          normalSinceAnnouncement = 0;
        } else if (!commercial) {
          normalSinceAnnouncement++;
        }
        previousCommercial = commercial;
      }
      final initialOrder = mixed.map((s) => s.id).toList();
      store.reset();
      expect(store.mixedFeed.map((s) => s.id), initialOrder);
    },
  );

  test(
    'private announcement media resolves only to reserved preview resources',
    () {
      final references = store.mediaReferences;
      for (final scenario in store.catalogue) {
        final payload = scenario.item.payload;
        if (payload is! AnnouncementFeedPayload ||
            payload.announcement.media == null) {
          continue;
        }
        final media = payload.announcement.media!;
        final reference = references[media.assetId]!;
        expect(reference.kind, media.kind);
        expect(
          reference.url,
          endsWith(media.isVideo ? '/video.mp4' : '/announcement-image.png'),
        );
        expect(
          reference.thumbnailUrl,
          endsWith(
            media.isVideo
                ? '/announcement-video.png'
                : '/announcement-image.png',
          ),
        );
      }
      for (final reference in references.values) {
        for (final url in [
          reference.url,
          if (reference.thumbnailUrl != null) reference.thumbnailUrl!,
        ]) {
          expect(Uri.parse(url).host, 'preview.soundconnect.invalid');
          expect(Uri.parse(url).path, startsWith('/fixtures/'));
        }
      }
    },
  );

  test(
    'every normal card image and playable source exists in preview-only assets',
    () {
      const assetRoot = 'android/app/src/preview/assets/preview';
      final manifest =
          (jsonDecode(File('$assetRoot/manifest.json').readAsStringSync())
                  as List)
              .cast<String>()
              .toSet();
      final available = {...manifest, 'audio.wav', 'video.mp4'};
      for (final name in available) {
        expect(File('$assetRoot/$name').existsSync(), isTrue, reason: name);
      }
      final references = store.mediaReferences;
      for (final scenario in store.catalogue) {
        for (final url in _fixtureUrls(scenario.item, references)) {
          final filename = Uri.parse(url).pathSegments.last;
          if (filename == 'missing.png' || filename == 'loading.png') {
            expect(scenario.includeInMixedFeed, isFalse);
          } else {
            expect(
              available,
              contains(filename),
              reason: '${scenario.id}: $url',
            );
          }
        }
      }
      for (final scenario in store.catalogue) {
        final payload = scenario.item.payload;
        if (payload is TrackFeedPayload) expect(payload.durationSeconds, 8);
        if (payload is ProfileMediaFeedPayload && payload.kind != 'IMAGE') {
          expect(payload.durationSeconds, 8);
        }
        if (payload is AnnouncementFeedPayload &&
            payload.announcement.media?.isVideo == true) {
          expect(payload.announcement.media!.durationSeconds, 8);
        }
      }
    },
  );

  test('likes are idempotent and announcement detail sees the same counts', () {
    final initial = store.scenarioById('announcement-image')!.item;
    final initialCount = initial.engagement!.likeCount;
    store.setLiked(initial.id, true);
    store.setLiked(initial.id, true);
    final updated = store.itemById(initial.id)!;
    expect(updated.engagement!.likeCount, initialCount + 1);
    expect(
      (updated.payload as AnnouncementFeedPayload)
          .announcement
          .engagement
          .likeCount,
      initialCount + 1,
    );
    expect(
      (updated.payload as AnnouncementFeedPayload)
          .announcement
          .engagement
          .likedByMe,
      isTrue,
    );
    store.setLiked(initial.id, false);
    expect(store.itemById(initial.id)!.engagement!.likeCount, initialCount);
  });

  test(
    'hidden announcements remain in catalogue and reset restores all local state',
    () {
      final announcement = store.scenarioById('announcement-text')!.item;
      final track = store.scenarioById('track-normal')!.item;
      store.hide(announcement.id);
      store.hide(announcement.id);
      store.setLiked(track.id, true);
      expect(
        store.visibleMixedFeed.any((s) => s.item.id == announcement.id),
        isFalse,
      );
      expect(
        store.catalogue.where(
          (s) => s.item.type == MusicianFeedItemType.announcement,
        ),
        hasLength(3),
      );
      expect(
        (store.itemById(announcement.id)!.payload as AnnouncementFeedPayload)
            .announcement
            .feedHidden,
        isTrue,
      );
      expect(
        store.isHidden(store.scenarioById('announcement-image')!.item.id),
        isFalse,
      );
      store.reset();
      expect(store.visibleMixedFeed, hasLength(store.mixedFeed.length));
      expect(store.isHidden(announcement.id), isFalse);
      expect(store.itemById(track.id)!.engagement!.likedByMe, isFalse);
      expect(
        (store.itemById(announcement.id)!.payload as AnnouncementFeedPayload)
            .announcement
            .feedHidden,
        isFalse,
      );
    },
  );

  test(
    'save, follow and author mute are local and independently reversible',
    () {
      final collab = store.scenarioById('collab-regular')!.item;
      store.setSaved(collab.id, true);
      expect(
        (store.itemById(collab.id)!.payload as CollabFeedPayload)
            .listing['savedByMe'],
        isTrue,
      );
      final profileItem = store.scenarioById('profile-musician')!.item;
      final profile = profileItem.payload as ProfileFeedPayload;
      store.setFollowed(profile.profileType, profile.profileId, true);
      expect(
        (store.itemById(profileItem.id)!.payload as ProfileFeedPayload)
            .followedByViewer,
        isTrue,
      );
      expect(store.itemById(profileItem.id)!.author!.followedByViewer, isTrue);
      final author = store.scenarioById('track-normal')!.item.author!;
      store.mute(author.profileType, author.profileId!);
      expect(
        store.visibleMixedFeed.any(
          (s) => s.item.author?.profileId == author.profileId,
        ),
        isFalse,
      );
      expect(
        store.visibleMixedFeed.any(
          (s) => s.item.type == MusicianFeedItemType.announcement,
        ),
        isTrue,
      );
      store.unmute(author.profileType, author.profileId!);
      expect(store.visibleMixedFeed.length, store.mixedFeed.length);
      store.reset();
      expect(
        (store.itemById(collab.id)!.payload as CollabFeedPayload)
            .listing['savedByMe'],
        isFalse,
      );
      expect(
        (store.itemById(profileItem.id)!.payload as ProfileFeedPayload)
            .followedByViewer,
        isFalse,
      );
    },
  );

  test(
    'comments and replies update aggregate counts; delete and like are idempotent',
    () {
      final item = store.scenarioById('announcement-video')!.item;
      final initialCount = item.engagement!.commentCount;
      final comment = store.addComment(
        item.id,
        '  Yeni akış çok iyi görünüyor!  ',
      );
      expect(comment.user.id, previewViewerUserId);
      expect(comment.text, 'Yeni akış çok iyi görünüyor!');
      final reply = store.addComment(
        item.id,
        'Birlikte deneyelim.',
        parentCommentId: comment.id,
      );
      expect(store.commentById(comment.id)!.replyCount, 1);
      expect(store.commentsFor(item.id).any((c) => c.id == reply.id), isTrue);
      expect(
        store.itemById(item.id)!.engagement!.commentCount,
        initialCount + 2,
      );
      expect(
        (store.itemById(item.id)!.payload as AnnouncementFeedPayload)
            .announcement
            .engagement
            .commentCount,
        initialCount + 2,
      );
      store.setCommentLiked(comment.id, true);
      store.setCommentLiked(comment.id, true);
      expect(store.commentById(comment.id)!.likeCount, 1);
      store.deleteComment(reply.id);
      store.deleteComment(reply.id);
      expect(store.commentById(reply.id)!.deleted, isTrue);
      expect(store.commentById(comment.id)!.replyCount, 0);
      expect(
        store.itemById(item.id)!.engagement!.commentCount,
        initialCount + 1,
      );
      store.reset();
      expect(store.commentById(comment.id), isNull);
      expect(store.itemById(item.id)!.engagement!.commentCount, initialCount);
    },
  );

  test(
    'popular fixture paginates all208 comments and real detail header retains its feed count',
    () async {
      final sessions = await createPreviewSession();
      addTearDown(sessions.dispose);
      final api = PreviewApiClient(store, sessions);
      final repository = EngagementRepositoryImpl(api, sessions: sessions);
      final stats = InteractionStatsCubit(repository, sessions: sessions);
      addTearDown(stats.close);
      final item = store.scenarioById('track-popular')!.item;
      final target = item.engagement!;
      expect(target.commentCount, 208);
      expect(store.commentsFor(item.id), hasLength(208));
      final seen = <String>{};
      for (var page = 0; page < 5; page++) {
        final response = await repository.listComments(
          targetType: target.targetType,
          targetId: target.targetId,
          page: page,
          size: 50,
        );
        expect(response.isSuccess, isTrue, reason: response.error?.message);
        expect(response.data!.totalElements, 208);
        expect(response.data!.items, hasLength(page == 4 ? 8 : 50));
        for (final comment in response.data!.items) {
          expect(seen.add(comment.id), isTrue);
          expect(
            Uri.parse(comment.user.avatarUrl!).pathSegments.last,
            matches(RegExp(r'^avatar-[0-5]\.png$')),
          );
        }
      }
      expect(seen, hasLength(208));
      await stats.load(
        targetType: target.targetType,
        targetId: target.targetId,
      );
      final header =
          stats.state.items['${target.targetType}:${target.targetId}']!;
      expect(header.error, isNull);
      expect(header.visibleCommentCount, target.commentCount);
      expect(api.rejectedPaths, isEmpty);
    },
  );

  test(
    'invalid comment targets and cross-content replies cannot mutate state',
    () {
      final track = store.scenarioById('track-normal')!.item;
      final announcement = store.scenarioById('announcement-text')!.item;
      final before = track.engagement!.commentCount;
      final foreignComment = store.commentsFor(announcement.id).first;
      expect(
        () => store.addComment(
          track.id,
          'Yanlış başlık',
          parentCommentId: foreignComment.id,
        ),
        throwsArgumentError,
      );
      expect(() => store.addComment(track.id, '  '), throwsArgumentError);
      expect(() => store.addComment('missing', 'Yorum'), throwsArgumentError);
      expect(
        () => store.addComment(
          store.scenarioById('collab-regular')!.item.id,
          'Yorum',
        ),
        throwsArgumentError,
      );
      expect(store.itemById(track.id)!.engagement!.commentCount, before);
      store.hide('unknown');
      store.setLiked('unknown', true);
      expect(store.hiddenItemIds, isEmpty);
      expect(store.commentById('unknown'), isNull);
    },
  );
}

Iterable<String> _fixtureUrls(
  MusicianFeedItem item,
  Map<String, PreviewMediaReference> references,
) sync* {
  Iterable<String> walk(Object? value) sync* {
    if (value is String && value.startsWith('$previewMediaBaseUrl/')) {
      yield value;
    }
    if (value is Map) {
      for (final nested in value.values) {
        yield* walk(nested);
      }
    }
    if (value is Iterable) {
      for (final nested in value) {
        yield* walk(nested);
      }
    }
  }

  Iterable<String> payloadUrls(MusicianFeedPayload payload) sync* {
    if (payload is TrackFeedPayload) yield* walk(payload.playbackUrl);
    if (payload is ProfileMediaFeedPayload) {
      yield* walk([
        payload.displayUrl,
        payload.playbackUrl,
        payload.thumbnailUrl,
      ]);
    }
    if (payload is CollabFeedPayload) yield* walk(payload.listing);
    if (payload is EventFeedPayload) yield* walk(payload.event);
    if (payload is ProfileShareFeedPayload) yield* walk(payload.source);
    if (payload is ProfileFeedPayload) yield* walk(payload.avatarUrl);
    if (payload is SponsoredFeedPayload) yield* walk(payload.mediaUrl);
    if (payload is AnnouncementFeedPayload) {
      final media = references[payload.announcement.media?.assetId];
      yield* walk([media?.url, media?.thumbnailUrl]);
    }
    if (payload is ActivityFeedPayload) {
      yield* walk(payload.actor.avatarUrl);
      yield* payloadUrls(payload.targetPayload);
    }
  }

  yield* walk(item.author?.avatarUrl);
  for (final actor in item.reason.actors) {
    yield* walk(actor.avatarUrl);
  }
  yield* payloadUrls(item.payload);
}
