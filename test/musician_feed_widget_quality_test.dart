import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_registry.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('musician feed card layout quality', () {
    testWidgets(
      'completion carousel stays usable at 320dp and 200 percent text',
      (tester) async {
        MusicianFeedCompletionTask? openedTask;
        final actions = _actions(
          openCompletionTask: (task) => openedTask = task,
        );
        final task = _completionTask(
          code: 'INSTRUMENTS',
          ctaLabel: 'Enstrümanlarımı düzenle',
        );
        final item = _item(
          id: 'completion',
          type: MusicianFeedItemType.profileCompletion,
          payload: CompletionFeedPayload(
            completed: 1,
            total: 3,
            tasks: [
              task,
              _completionTask(
                code: 'STAGE_NAME_AND_BIO',
                ctaLabel: 'Profil bilgilerimi düzenle',
                priority: 2,
              ),
            ],
          ),
          reasonCode: 'PROFILE_INCOMPLETE',
        );

        await _pumpNarrowCard(tester, item, actions);

        expect(tester.takeException(), isNull);
        final cta = find.text('Enstrümanlarımı düzenle');
        expect(cta, findsOneWidget);
        await tester.tap(cta);
        await tester.pump();
        expect(openedTask, same(task));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('sponsor card has a tappable CTA without narrow-screen overflow', (
      tester,
    ) async {
      MusicianFeedItem? openedPromotion;
      final actions = _actions(openPromotion: (item) => openedPromotion = item);
      final item = _item(
        id: 'sponsor',
        type: MusicianFeedItemType.sponsored,
        payload: const SponsoredFeedPayload(
          title:
              'Turne hazırlığındaki müzisyenler için yeni nesil sahne ekipmanları',
          body:
              'Uzun provalarda ve şehir dışı konserlerde ihtiyacın olan ayrıntıları tek yerde karşılaştır.',
          mediaUrl: null,
          ctaLabel: 'Sponsorlu içeriği ayrıntılı incele',
          ctaUrl: '/collab',
        ),
        reasonCode: 'SPONSORED',
        promotion: const MusicianFeedPromotion(
          campaignId: 'campaign-id',
          disclosure: 'SPONSORED',
          ctaLabel: 'Sponsorlu içeriği ayrıntılı incele',
          ctaUrl: '/collab',
        ),
      );

      await _pumpNarrowCard(tester, item, actions);

      expect(tester.takeException(), isNull);
      final cta = find.text('Sponsorlu içeriği ayrıntılı incele');
      expect(cta, findsOneWidget);
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      expect(cta.hitTestable(), findsOneWidget);
      await tester.tap(cta.hitTestable());
      await tester.pumpAndSettle();
      expect(openedPromotion, same(item));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'promoted native event keeps its native renderer and open action',
      (tester) async {
        MusicianFeedItem? openedItem;
        MusicianFeedItem? openedPromotion;
        final actions = _actions(
          openItem: (item) => openedItem = item,
          openPromotion: (item) => openedPromotion = item,
        );
        final item = _item(
          id: 'promoted-event',
          type: MusicianFeedItemType.event,
          payload: const EventFeedPayload(
            event: {
              'id': 'event-id',
              'title': 'Sponsor destekli bağımsız sahne buluşması',
              'performerName': 'Uzun İsimli Müzik Kolektifi',
              'venueName': 'Kadıköy Bağımsız Sahne',
              'venueCity': 'İstanbul',
              'eventDate': '2026-09-18',
              'startTime': '20:30',
              'endTime': null,
            },
            note: null,
            publicationId: null,
          ),
          reasonCode: 'DISCOVERY',
          promotion: const MusicianFeedPromotion(
            campaignId: 'campaign-id',
            disclosure: 'sponsored',
            ctaLabel: 'Etkinliği incele',
            ctaUrl: '/events',
          ),
        );

        await _pumpNarrowCard(tester, item, actions);

        expect(tester.takeException(), isNull);
        expect(find.text('Sponsorlu'), findsOneWidget);
        expect(find.text('Senin için keşfedildi'), findsNothing);
        final nativeTitle = find.text(
          'Sponsor destekli bağımsız sahne buluşması',
        );
        expect(nativeTitle, findsOneWidget);
        expect(find.text('Etkinliği incele'), findsNothing);
        await tester.tap(nativeTitle);
        await tester.pump();
        expect(openedItem, same(item));
        expect(openedPromotion, isNull);
      },
    );

    testWidgets(
      'lowercase featured promotion visibly highlights a native Collab card',
      (tester) async {
        final item = _item(
          id: 'promoted-collab',
          type: MusicianFeedItemType.collab,
          payload: CollabFeedPayload(listing: _collabListingJson()),
          reasonCode: 'CITY_MATCH',
          promotion: const MusicianFeedPromotion(
            campaignId: 'campaign-id',
            disclosure: 'featured',
            ctaLabel: 'İlanı incele',
            ctaUrl: '/collab',
          ),
        );

        await _pumpCard(
          tester,
          item,
          _actions(),
          size: const Size(420, 900),
          textScale: 1,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Öne Çıkan'), findsNWidgets(2));
        expect(find.text('Fırsat görmek istediğin şehirde'), findsNothing);
      },
    );

    testWidgets(
      'profile recommendation keeps follow action reachable at large text',
      (tester) async {
        MusicianFeedItem? followed;
        final actions = _actions(followProfile: (item) => followed = item);
        final item = _item(
          id: 'profile',
          type: MusicianFeedItemType.profile,
          payload: const ProfileFeedPayload(
            profileId: 'venue-profile-id',
            profileType: 'VENUE',
            userId: 'venue-owner-id',
            username: 'uzunmekanadi',
            displayName: 'İstanbul Bağımsız Müzik ve Performans Sahnesi',
            avatarUrl: null,
            bio:
                'Canlı performanslar, prova buluşmaları ve yeni müzik keşifleri için bağımsız sahne.',
            location: 'Kadıköy, İstanbul',
            followedByViewer: false,
          ),
          reasonCode: 'DISCOVERY',
        );

        await _pumpNarrowCard(tester, item, actions);

        expect(tester.takeException(), isNull);
        final cta = find.text('Takip et');
        expect(cta, findsOneWidget);
        await tester.tap(cta);
        await tester.pump();
        expect(followed, same(item));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'social activity target remains tappable without narrow overflow',
      (tester) async {
        MusicianFeedItem? opened;
        final actions = _actions(openItem: (item) => opened = item);
        final item = _item(
          id: 'activity',
          type: MusicianFeedItemType.activityLike,
          payload: ActivityFeedPayload(
            action: 'LIKE',
            actor: _listener,
            targetItemType: MusicianFeedItemType.profile,
            targetPayload: const ProfileFeedPayload(
              profileId: 'studio-id',
              profileType: 'STUDIO',
              userId: 'studio-owner-id',
              username: 'analogkayit',
              displayName: 'Analog Kayıt ve Prodüksiyon Stüdyosu',
              avatarUrl: null,
              bio:
                  'Akustik kayıt, prova ve canlı oturumlar için ayrıntılı stüdyo profili.',
              location: 'Beşiktaş, İstanbul',
              followedByViewer: false,
            ),
          ),
          reasonCode: 'FOLLOWED_USER_LIKED',
          reasonActors: const [_listener],
          author: _listener,
        );

        await _pumpNarrowCard(tester, item, actions);

        expect(tester.takeException(), isNull);
        expect(
          find.text('Müzik Arşivcisi Dinleyici bunu beğendi'),
          findsOneWidget,
        );
        expect(find.text(_listener.displayName), findsNothing);
        final title = find.text('Analog Kayıt ve Prodüksiyon Stüdyosu');
        expect(title, findsOneWidget);
        await tester.tap(title);
        await tester.pump();
        expect(opened, same(item));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('listener TableGroup share CTA remains reachable at large text', (
      tester,
    ) async {
      MusicianFeedItem? opened;
      final actions = _actions(openItem: (item) => opened = item);
      final item = _item(
        id: 'listener-share',
        type: MusicianFeedItemType.tableGroupProfileShare,
        payload: ProfileShareFeedPayload(
          shareId: 'share-id',
          note:
              'Bu uzun tartışmayı takip ettiğim müzisyenlerle paylaşmak istedim.',
          publishedAt: DateTime.utc(2026, 9, 11),
          source: const {
            'tableGroupId': 'table-id',
            'title': 'Bağımsız müzisyenler için sürdürülebilir turne planlama',
            'content':
                'Şehirler arası yolculuk, ekipman ve sahne programı üzerine ayrıntılı bir masa konuşması.',
          },
        ),
        author: _listener,
        reasonCode: 'FOLLOWING_PUBLICATION',
      );

      await _pumpNarrowCard(tester, item, actions);

      expect(tester.takeException(), isNull);
      final cta = find.text('Masaya git');
      expect(cta, findsOneWidget);
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pump();
      expect(opened, same(item));
      expect(tester.takeException(), isNull);
    });

    testWidgets('engagement actions remain usable at 320dp and large text', (
      tester,
    ) async {
      MusicianFeedItem? liked;
      final actions = _actions(toggleLike: (item) => liked = item);
      final item = _item(
        id: 'listener-share-with-engagement',
        type: MusicianFeedItemType.tableGroupProfileShare,
        payload: ProfileShareFeedPayload(
          shareId: 'share-id-with-engagement',
          note: null,
          publishedAt: DateTime.utc(2026, 9, 11),
          source: const {
            'tableGroupId': 'table-id-with-engagement',
            'title': 'Turne planlama masası',
          },
        ),
        author: _listener,
        reasonCode: 'FOLLOWING_PUBLICATION',
        engagement: const MusicianFeedEngagement(
          targetType: 'TABLEGROUP_PROFILE_SHARE',
          targetId: 'share-id-with-engagement',
          likeCount: 12,
          commentCount: 4,
          likedByMe: false,
          likable: true,
          commentable: true,
        ),
      );

      await _pumpNarrowCard(tester, item, actions);

      expect(tester.takeException(), isNull);
      for (final label in const ['Beğen', 'Yorum', 'Aç']) {
        final action = find.text(label);
        expect(action, findsOneWidget);
        expect(action.hitTestable(), findsOneWidget);
      }
      await tester.tap(find.text('Beğen').hitTestable());
      await tester.pump();
      expect(liked, same(item));
      expect(tester.takeException(), isNull);
    });
  });
}

const MusicianFeedActor _listener = MusicianFeedActor(
  userId: 'listener-user-id',
  profileId: 'listener-profile-id',
  profileType: 'LISTENER',
  username: 'uzundinleyiciadi',
  displayName: 'Müzik Arşivcisi Dinleyici',
  avatarUrl: null,
  followedByViewer: true,
);

MusicianFeedCompletionTask _completionTask({
  required String code,
  required String ctaLabel,
  int priority = 1,
}) => MusicianFeedCompletionTask(
  code: code,
  title:
      'Sana uygun fırsatları daha doğru eşleştirebilmemiz için profilini tamamla',
  description:
      'Şehir, enstrüman ve sahne bilgilerin akıştaki Collab, mekân ve etkinlik önerilerini güçlendirir.',
  ctaLabel: ctaLabel,
  route: '/backstage/profile',
  priority: priority,
  complete: false,
);

MusicianFeedItem _item({
  required String id,
  required MusicianFeedItemType type,
  required MusicianFeedPayload payload,
  required String reasonCode,
  List<MusicianFeedActor> reasonActors = const [],
  MusicianFeedActor? author,
  MusicianFeedPromotion? promotion,
  MusicianFeedEngagement? engagement,
}) => MusicianFeedItem(
  id: id,
  type: type,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 11),
  position: 0,
  impressionToken: 'delivery-token-$id',
  reason: MusicianFeedReason(
    code: reasonCode,
    actors: reasonActors,
    secondaryActorCount: 0,
  ),
  author: author,
  target: MusicianFeedTarget(type: type.apiValue, id: '$id-target'),
  engagement: engagement,
  promotion: promotion,
  feedbackCapabilities: const {},
  payload: payload,
);

MusicianFeedCardActions _actions({
  void Function(MusicianFeedItem)? openItem,
  void Function(MusicianFeedCompletionTask)? openCompletionTask,
  void Function(MusicianFeedItem)? openPromotion,
  void Function(MusicianFeedItem)? followProfile,
  void Function(MusicianFeedItem)? toggleLike,
}) => MusicianFeedCardActions(
  openItem: openItem ?? (_) {},
  openAuthor: (_, _) {},
  toggleLike: toggleLike ?? (_) {},
  openComments: (_) {},
  feedback: (_, _) {},
  muteAuthor: (_, _) {},
  openCompletionTask: openCompletionTask ?? (_) {},
  openPromotion: openPromotion ?? (_) {},
  toggleCollabSaved: (_, _) {},
  followProfile: followProfile ?? (_) {},
);

Future<void> _pumpNarrowCard(
  WidgetTester tester,
  MusicianFeedItem item,
  MusicianFeedCardActions actions,
) => _pumpCard(tester, item, actions, size: const Size(320, 900), textScale: 2);

Future<void> _pumpCard(
  WidgetTester tester,
  MusicianFeedItem item,
  MusicianFeedCardActions actions, {
  required Size size,
  required double textScale,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final registry = MusicianFeedCardRegistry.standard();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Builder(
              builder: (context) => registry.build(context, item, actions),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Map<String, dynamic> _collabListingJson() => <String, dynamic>{
  'id': 'listing-id',
  'version': 1,
  'status': 'OPEN',
  'closureReason': null,
  'cadence': 'REGULAR',
  'wantedType': 'MUSICIAN',
  'instrument': <String, dynamic>{'id': 'bass-id', 'name': 'Bas Gitar'},
  'branch': null,
  'customSpecialty': null,
  'title': 'Bas gitarist aranıyor',
  'description': 'Haftalık sahne programı için ekip arkadaşı arıyoruz.',
  'city': <String, dynamic>{'id': 'istanbul-id', 'name': 'İstanbul'},
  'genres': <String>['Rock'],
  'scheduledAt': null,
  'expiresAt': '2026-10-01T12:00:00Z',
  'feeAmountMinor': null,
  'currency': null,
  'feeStatus': 'UNSPECIFIED',
  'publishedAt': '2026-09-11T10:00:00Z',
  'createdAt': '2026-09-11T09:55:00Z',
  'closedAt': null,
  'publisher': <String, dynamic>{
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
};
