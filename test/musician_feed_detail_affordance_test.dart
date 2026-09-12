import 'dart:ui' show SemanticsAction;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_discovery_models.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/widgets/collab_discovery_widgets.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/musician_feed_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_registry.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_detail_link.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _AudioHandler audio;

  setUp(() {
    serviceLocator.pushNewScope();
    audio = _AudioHandler();
    serviceLocator.registerSingleton<AudioHandler>(audio);
  });

  tearDown(() async {
    await serviceLocator.popScope();
  });

  testWidgets('feed Collab chevron opens detail and save stays independent', (
    tester,
  ) async {
    final item = _item(MusicianFeedItemType.collab, _collab());
    final opened = <MusicianFeedItem>[];
    final saved = <(MusicianFeedItem, bool)>[];
    await _pumpCard(
      tester,
      item,
      _actions(
        openItem: opened.add,
        toggleCollabSaved: (item, value) => saved.add((item, value)),
      ),
    );

    expect(find.byType(MusicianFeedDetailChevron), findsOneWidget);
    await tester.tap(find.byTooltip('İlanı kaydet'));
    expect(saved, [(item, true)]);
    expect(opened, isEmpty);

    await tester.tap(find.byType(MusicianFeedDetailChevron));
    expect(opened, [item]);
    expect(saved, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared Collab card remains unchanged without feed opt-in', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: Scaffold(
          body: CollabListingCard(
            listing: const CollabDiscoveryListing(
              id: 'regular-listing',
              ownerName: 'Kadıköy Sahne',
              ownerInitials: 'KS',
              profileKind: CollabProfileKind.venue,
              wantedKind: CollabProfileKind.musician,
              title: 'Bas gitarist aranıyor',
              cadence: CollabCadence.regular,
              location: 'İstanbul',
              role: 'Bas Gitar',
            ),
            saved: false,
            onTap: () {},
            onSave: () {},
          ),
        ),
      ),
    );
    expect(find.byType(MusicianFeedDetailChevron), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final type in [
    MusicianFeedItemType.overthinkingProfileShare,
    MusicianFeedItemType.tableGroupProfileShare,
  ]) {
    testWidgets(
      '${type.name} preview opens while share engagement stays local',
      (tester) async {
        final item = _item(
          type,
          ProfileShareFeedPayload(
            shareId: 'listener-profile-share',
            note: 'Profilimde kalsın.',
            publishedAt: DateTime.utc(2026, 9, 11),
            source: const {
              'overthinkingId': 'source-overthinking',
              'tableGroupId': 'source-table',
              'title': 'Bugünün tekrar tuşu',
              'content': 'Bu parçada her dinleyişte başka bir ayrıntı var.',
            },
          ),
          engagement: const MusicianFeedEngagement(
            targetType: 'PROFILE_SHARE',
            targetId: 'listener-profile-share',
            likeCount: 7,
            commentCount: 3,
            likedByMe: false,
            likable: true,
            commentable: true,
          ),
        );
        final opened = <MusicianFeedItem>[];
        final liked = <MusicianFeedItem>[];
        final commented = <MusicianFeedItem>[];
        await _pumpCard(
          tester,
          item,
          _actions(
            openItem: opened.add,
            toggleLike: liked.add,
            openComments: commented.add,
          ),
        );

        expect(find.text('Overthinking’e git'), findsNothing);
        expect(find.text('Masaya git'), findsNothing);
        expect(find.byType(MusicianFeedDetailChevron), findsWidgets);

        await tester.tap(find.text('Beğen'));
        await tester.tap(find.text('Yorum'));
        expect(liked.single, same(item));
        expect(commented.single, same(item));
        expect(opened, isEmpty);

        await tester.tap(
          find.text('Bu parçada her dinleyişte başka bir ayrıntı var.'),
        );
        expect(opened.single, same(item));
        expect(opened.single.engagement!.targetId, 'listener-profile-share');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final type in [
    MusicianFeedItemType.event,
    MusicianFeedItemType.eventProfileShare,
    MusicianFeedItemType.profile,
    MusicianFeedItemType.activityFollow,
    MusicianFeedItemType.activityLike,
    MusicianFeedItemType.activityComment,
  ]) {
    testWidgets('${type.name} uses the common actionable detail chevron', (
      tester,
    ) async {
      final payload = switch (type) {
        MusicianFeedItemType.event ||
        MusicianFeedItemType.eventProfileShare => _event,
        MusicianFeedItemType.profile => _profile,
        _ => ActivityFeedPayload(
          action: type == MusicianFeedItemType.activityFollow
              ? 'FOLLOW'
              : 'LIKE',
          actor: _actor,
          targetItemType: MusicianFeedItemType.profile,
          targetPayload: _profile,
        ),
      };
      final item = _item(type, payload);
      final opened = <MusicianFeedItem>[];
      await _pumpCard(tester, item, _actions(openItem: opened.add));

      expect(find.byType(MusicianFeedDetailChevron), findsOneWidget);
      await tester.tap(find.byType(MusicianFeedDetailChevron));
      expect(opened.single, same(item));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('track heading opens detail without taking over audio playback', (
    tester,
  ) async {
    final item = _item(
      MusicianFeedItemType.track,
      const TrackFeedPayload(
        trackId: 'track-id',
        mediaAssetId: 'current-audio',
        title: 'Gece kaydı',
        playbackUrl: 'https://example.test/track.mp3',
        durationSeconds: 90,
        bpm: 110,
      ),
    );
    audio.mediaItem.add(
      const MediaItem(id: 'current-audio', title: 'Gece kaydı'),
    );
    final opened = <MusicianFeedItem>[];
    await _pumpCard(tester, item, _actions(openItem: opened.add));

    await tester.tap(find.byTooltip('Çal'));
    expect(audio.playCalls, 1);
    expect(opened, isEmpty);
    await tester.tap(find.byType(MusicianFeedDetailChevron));
    expect(opened.single, same(item));
    expect(audio.playCalls, 1);
    expect(tester.takeException(), isNull);
  });

  for (final kind in ['AUDIO', 'IMAGE', 'VIDEO']) {
    for (final title in <String?>[null, 'Bir sahne hikâyesi']) {
      testWidgets('$kind media with ${title ?? 'no title'} exposes detail', (
        tester,
      ) async {
        final item = _item(
          MusicianFeedItemType.profileMedia,
          _media(kind, title: title),
        );
        final opened = <MusicianFeedItem>[];
        await _pumpCard(tester, item, _actions(openItem: opened.add));

        final heading = find.byType(MusicianFeedDetailHeading);
        expect(heading, findsOneWidget);
        final expectedTitle =
            title ??
            switch (kind) {
              'AUDIO' => 'Ses kaydı',
              'VIDEO' => 'Video',
              _ => 'Fotoğraf',
            };
        expect(
          find.descendant(of: heading, matching: find.text(expectedTitle)),
          findsOneWidget,
        );
        await tester.tap(find.byType(MusicianFeedDetailChevron));
        expect(opened.single, same(item));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final kind in ['IMAGE', 'VIDEO']) {
    testWidgets('$kind without a usable URL does not promise detail', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _item(
          MusicianFeedItemType.profileMedia,
          _media(kind, available: false),
        ),
        _actions(),
      );
      expect(find.byType(MusicianFeedDetailHeading), findsNothing);
      expect(find.byType(MusicianFeedDetailChevron), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final type in [
    MusicianFeedItemType.collab,
    MusicianFeedItemType.event,
  ]) {
    testWidgets('unavailable ${type.name} has no misleading detail cue', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _item(
          type,
          type == MusicianFeedItemType.collab
              ? const CollabFeedPayload(listing: {})
              : const EventFeedPayload(
                  event: {},
                  note: null,
                  publicationId: null,
                ),
        ),
        _actions(),
      );
      expect(find.byType(MusicianFeedDetailChevron), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sponsor keeps its CTA label and original promotion action', (
    tester,
  ) async {
    final item = _item(
      MusicianFeedItemType.sponsored,
      const SponsoredFeedPayload(
        title: 'Sahnede buluşalım',
        body: 'SoundConnect dünyasından yeni bir fırsat.',
        mediaUrl: null,
        ctaLabel: 'Fırsatı incele',
        ctaUrl: '/events',
      ),
    );
    final promoted = <MusicianFeedItem>[];
    final opened = <MusicianFeedItem>[];
    await _pumpCard(
      tester,
      item,
      _actions(openItem: opened.add, openPromotion: promoted.add),
    );
    expect(find.text('Fırsatı incele'), findsOneWidget);
    expect(find.byType(MusicianFeedDetailChevron), findsOneWidget);
    await tester.tap(find.text('Fırsatı incele'));
    expect(promoted.single, same(item));
    expect(opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile completion keeps its distinct task action', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _item(
        MusicianFeedItemType.profileCompletion,
        const CompletionFeedPayload(
          completed: 0,
          total: 1,
          tasks: [
            MusicianFeedCompletionTask(
              code: 'INSTRUMENTS',
              title: 'Enstrümanlarını ekle',
              description: 'Sana uygun fırsatları keşfet.',
              ctaLabel: 'Enstrümanlarımı düzenle',
              route: '/backstage/profile',
              priority: 1,
              complete: false,
            ),
          ],
        ),
      ),
      _actions(),
    );
    expect(find.byType(MusicianFeedDetailChevron), findsNothing);
    expect(find.text('Enstrümanlarımı düzenle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long Collab title and chevron fit 320dp at 200 percent text', (
    tester,
  ) async {
    final item = _item(
      MusicianFeedItemType.collab,
      _collab(
        title:
            'Birlikte uzun soluklu sahne projeleri için bas gitarist aranıyor',
      ),
    );
    final opened = <MusicianFeedItem>[];
    await _pumpCard(
      tester,
      item,
      _actions(openItem: opened.add),
      size: const Size(320, 900),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    final chevron = find.byType(MusicianFeedDetailChevron);
    await tester.ensureVisible(chevron);
    await tester.tap(chevron);
    expect(opened.single, same(item));
  });

  for (final likable in [false, true]) {
    for (final commentable in [false, true]) {
      for (final hasCounts in [false, true]) {
        testWidgets(
          'no redundant open: likes=$likable comments=$commentable counts=$hasCounts',
          (tester) async {
            final item = _item(
              MusicianFeedItemType.eventProfileShare,
              _event,
              engagement: MusicianFeedEngagement(
                targetType: 'EVENT_PROFILE_SHARE',
                targetId: 'event-publication',
                likeCount: hasCounts ? 7 : 0,
                commentCount: hasCounts ? 3 : 0,
                likedByMe: false,
                likable: likable,
                commentable: commentable,
              ),
            );
            final opened = <MusicianFeedItem>[];
            final liked = <MusicianFeedItem>[];
            final commented = <MusicianFeedItem>[];
            final actions = _actions(
              openItem: opened.add,
              toggleLike: liked.add,
              openComments: commented.add,
            );
            await _pumpCard(tester, item, actions);

            expect(find.text('Beğen'), likable ? findsOneWidget : findsNothing);
            expect(
              find.text('Yorum'),
              commentable ? findsOneWidget : findsNothing,
            );
            expect(find.text('7'), hasCounts ? findsOneWidget : findsNothing);
            expect(
              find.text('3 yorum'),
              hasCounts ? findsOneWidget : findsNothing,
            );
            if (likable) {
              await tester.tap(find.text('Beğen'));
              expect(liked.single, same(item));
            }
            if (commentable) {
              await tester.tap(find.text('Yorum'));
              expect(commented.single, same(item));
            }
            expect(opened, isEmpty);
            await tester.tap(find.byType(MusicianFeedDetailChevron));
            expect(opened.single, same(item));

            if (!likable && !commentable && !hasCounts) {
              final withoutActionsHeight = tester
                  .getSize(find.byKey(ValueKey('musician-feed-${item.id}')))
                  .height;
              await _pumpCard(
                tester,
                _item(MusicianFeedItemType.eventProfileShare, _event),
                actions,
              );
              expect(
                tester
                    .getSize(find.byKey(ValueKey('musician-feed-${item.id}')))
                    .height,
                withoutActionsHeight,
                reason:
                    'Removing the last action must not leave an empty footer gap.',
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('detail link provides a 48dp screen-reader tap target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var opened = 0;
      const key = ValueKey('accessible-detail-link');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: Scaffold(
            body: MusicianFeedDetailLink(
              key: key,
              semanticLabel: 'Bugünün tekrar tuşu detayını aç',
              onTap: () => opened++,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Detay'), MusicianFeedDetailChevron()],
              ),
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byKey(key));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.label, contains('Bugünün tekrar tuşu detayını aç'));
      expect(node.label, contains('Detay'));
      expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(48));
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}

class _AudioHandler extends BaseAudioHandler {
  int playCalls = 0;

  @override
  Future<void> play() async {
    playCalls++;
  }
}

const _actor = MusicianFeedActor(
  userId: 'listener-user',
  profileId: 'listener-profile',
  profileType: 'LISTENER',
  username: 'dinleyici',
  displayName: 'Dinleyici',
  avatarUrl: null,
  followedByViewer: true,
);

const _profile = ProfileFeedPayload(
  profileId: 'musician-profile',
  profileType: 'MUSICIAN',
  userId: 'musician-user',
  username: 'basgitarci',
  displayName: 'Kullanılmayan Sahne Adı',
  avatarUrl: null,
  bio: 'Birlikte sahnede.',
  location: 'İstanbul',
  followedByViewer: false,
);

const _event = EventFeedPayload(
  event: {
    'id': 'event-id',
    'title': 'Şehrin Altında',
    'performerName': 'Bora Güneş Akustik Set',
    'venueName': 'Kızılay Frekans',
    'venueCity': 'Ankara',
    'eventDate': '2026-09-18',
    'startTime': '20:30',
    'endTime': null,
  },
  note: null,
  publicationId: 'event-publication',
);

ProfileMediaFeedPayload _media(
  String kind, {
  String? title,
  bool available = true,
}) => ProfileMediaFeedPayload(
  mediaAssetId: 'media-id',
  kind: kind,
  displayUrl: available && kind == 'IMAGE'
      ? 'https://example.test/image.jpg'
      : null,
  playbackUrl: available && kind != 'IMAGE'
      ? 'https://example.test/media.mp4'
      : null,
  thumbnailUrl: null,
  title: title,
  description: null,
  durationSeconds: 90,
  width: 640,
  height: 480,
);

CollabFeedPayload _collab({String title = 'Bas gitarist aranıyor'}) =>
    CollabFeedPayload(
      listing: {
        'id': 'listing-id',
        'version': 1,
        'status': 'OPEN',
        'cadence': 'REGULAR',
        'wantedType': 'MUSICIAN',
        'instrument': {'id': 'bass-id', 'name': 'Bas Gitar'},
        'title': title,
        'description': 'Haftalık sahne programı için ekip arkadaşı arıyoruz.',
        'city': {'id': 'istanbul-id', 'name': 'İstanbul'},
        'genres': ['Rock'],
        'expiresAt': '2026-10-01T12:00:00Z',
        'feeStatus': 'UNSPECIFIED',
        'publishedAt': '2026-09-11T10:00:00Z',
        'createdAt': '2026-09-11T09:55:00Z',
        'publisher': {
          'actorId': 'venue-actor-id',
          'profileType': 'VENUE',
          'sourceProfileId': 'venue-profile-id',
          'contactUserId': 'venue-user-id',
          'displayName': 'Kadıköy Sahne',
          'avatarUrl': null,
          'rating': 4.8,
          'reviewCount': 12,
          'completedJobCount': 31,
        },
        'ownedByMe': false,
        'appliedByMe': false,
        'savedByMe': false,
        'applicationCount': 2,
      },
    );

MusicianFeedItem _item(
  MusicianFeedItemType type,
  MusicianFeedPayload payload, {
  MusicianFeedEngagement? engagement,
}) => MusicianFeedItem(
  id: 'feed-${type.name}',
  type: type,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 11),
  position: 0,
  impressionToken: 'delivery-token',
  reason: const MusicianFeedReason(
    code: 'DISCOVERY',
    actors: [],
    secondaryActorCount: 0,
  ),
  author: null,
  target: MusicianFeedTarget(type: type.apiValue, id: 'original-target'),
  engagement: engagement,
  promotion: null,
  feedbackCapabilities: const {},
  payload: payload,
);

MusicianFeedCardActions _actions({
  void Function(MusicianFeedItem)? openItem,
  void Function(MusicianFeedItem)? toggleLike,
  void Function(MusicianFeedItem)? openComments,
  void Function(MusicianFeedItem)? openPromotion,
  void Function(MusicianFeedItem, bool)? toggleCollabSaved,
}) => MusicianFeedCardActions(
  openItem: openItem ?? (_) {},
  openAuthor: (_, _) {},
  toggleLike: toggleLike ?? (_) {},
  openComments: openComments ?? (_) {},
  openLikes: (_) {},
  feedback: (_, _) {},
  muteAuthor: (_, _) {},
  openCompletionTask: (_) {},
  openPromotion: openPromotion ?? (_) {},
  toggleCollabSaved: toggleCollabSaved ?? (_, _) {},
  followProfile: (_) {},
);

Future<void> _pumpCard(
  WidgetTester tester,
  MusicianFeedItem item,
  MusicianFeedCardActions actions, {
  Size size = const Size(390, 900),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: MusicianFeedThemeScope(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Builder(
                builder: (context) => MusicianFeedCardRegistry.standard().build(
                  context,
                  item,
                  actions,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(find.text('Aç'), findsNothing);
}
