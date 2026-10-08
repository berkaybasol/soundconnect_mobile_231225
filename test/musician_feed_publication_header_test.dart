import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/musician_feed_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_chrome.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_registry.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  group('musician feed publication header', () {
    testWidgets(
      'surface shows one author for their own publication and keeps hide and menu',
      (tester) async {
        for (final useReasonActor in [true, false]) {
          final author = _actor(
            username: 'cok_uzun_bir_muzisyen_kullanici_adi_ve_devami',
          );
          final item = _item(
            author: author,
            reasonActors: useReasonActor ? [_actor()] : const [],
            feedbackCapabilities: const {
              MusicianFeedFeedbackAction.hide,
              MusicianFeedFeedbackAction.showLess,
            },
          );
          final calls = _Calls();
          await _pumpSurface(
            tester,
            item,
            calls,
            size: const Size(320, 640),
            textScale: 2,
          );

          expect(find.byType(MusicianFeedReasonRow), findsNothing);
          expect(find.byType(MusicianFeedAuthorHeader), findsOneWidget);
          expect(find.byType(AppCachedNetworkImage), findsOneWidget);
          expect(
            find.textContaining('paylaştı', findRichText: true),
            findsNothing,
          );
          expect(find.byTooltip('Kart seçenekleri'), findsOneWidget);
          expect(find.byTooltip('Bu kartı gizle'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(find.byTooltip('Bu kartı gizle'));
          await tester.pump();
          expect(calls.feedbackItems, [item]);
          expect(calls.feedbackActions, [MusicianFeedFeedbackAction.hide]);
          expect(calls.openedAuthors, isEmpty);
          expect(calls.openedItems, isEmpty);

          await tester.tap(find.byTooltip('Kart seçenekleri'));
          await tester.pumpAndSettle();
          expect(find.text('Bunun gibi daha az göster'), findsOneWidget);
          await tester.tap(find.text('Bunun gibi daha az göster'));
          await tester.pumpAndSettle();
          expect(calls.feedbackItems, [item, item]);
          expect(
            calls.feedbackActions.last,
            MusicianFeedFeedbackAction.showLess,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'surface keeps a distinct publisher and original content author independently tappable',
      (tester) async {
        final publisher = _actor();
        // The same account can own different profile families. Identity must
        // use the profile type and profile ID, not account ID or display name.
        final author = _actor(
          profileType: 'VENUE',
          profileId: 'venue-profile-id',
          username: 'venue-account',
          displayName: 'Kadıköy Sahne',
        );
        final item = _item(author: author, reasonActors: [publisher]);
        final calls = _Calls();
        await _pumpSurface(tester, item, calls);

        expect(find.byType(MusicianFeedReasonRow), findsOneWidget);
        expect(find.byType(MusicianFeedAuthorHeader), findsOneWidget);
        await tester.tap(find.text('selinaksoy paylaştı', findRichText: true));
        await tester.pump();
        await tester.tap(find.text('Kadıköy Sahne'));
        await tester.pump();
        expect(calls.openedAuthors, [publisher, author]);
        expect(calls.authorItems, [item, item]);
        expect(calls.openedItems, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'surface never removes promotion disclosure when publisher matches author',
      (tester) async {
        for (final disclosure in const [
          ('SPONSORED', 'Sponsorlu'),
          ('FEATURED', 'Öne Çıkan'),
          ('PLATFORM_ANNOUNCEMENT', 'SoundConnect duyurusu'),
          ('FUTURE_PROMOTION', 'Sponsorlu'),
        ]) {
          final item = _item(
            author: _actor(),
            reasonActors: [_actor()],
            promotion: MusicianFeedPromotion(
              campaignId: 'campaign-id',
              disclosure: disclosure.$1,
              ctaLabel: null,
              ctaUrl: null,
            ),
          );
          await _pumpSurface(tester, item, _Calls());
          expect(find.text(disclosure.$2), findsOneWidget);
          expect(find.byType(MusicianFeedReasonRow), findsOneWidget);
          expect(find.byType(MusicianFeedAuthorHeader), findsOneWidget);
          expect(
            find.textContaining('paylaştı', findRichText: true),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'surface preserves publication when its author header is absent',
      (tester) async {
        final author = _actor();
        final item = _item(author: author, reasonActors: [author]);
        final calls = _Calls();
        await _pumpSurface(tester, item, calls, showAuthor: false);

        expect(find.byType(MusicianFeedReasonRow), findsOneWidget);
        expect(find.byType(MusicianFeedAuthorHeader), findsNothing);
        await tester.tap(find.text('selinaksoy paylaştı', findRichText: true));
        await tester.pump();
        expect(calls.openedAuthors, [author]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'reason actor owns both name and avatar navigation, not content author',
      (tester) async {
        final publisher = _actor();
        final item = _item(
          author: _actor(
            profileType: 'VENUE',
            profileId: 'venue-id',
            username: 'venue-account',
            displayName: 'Kadıköy Sahne',
          ),
          reasonActors: [publisher],
        );
        final calls = _Calls();
        await _pumpHeader(tester, item, calls);

        final label = find.text('selinaksoy paylaştı', findRichText: true);
        expect(label, findsOneWidget);
        expect(find.textContaining('Eski Sahne Adı'), findsNothing);
        expect(find.textContaining('Kadıköy Sahne'), findsNothing);
        expect(find.textContaining('Takip ettiğin bir profil'), findsNothing);
        expect(_profileSemantics('selinaksoy'), findsOneWidget);

        await tester.tap(label);
        await tester.pump();
        await tester.tap(find.byType(AppCachedNetworkImage));
        await tester.pump();

        expect(calls.openedAuthors, [publisher, publisher]);
        expect(calls.authorItems, [item, item]);
        expect(calls.openedItems, isEmpty);
      },
    );

    testWidgets('author is used when older responses have no reason actors', (
      tester,
    ) async {
      final author = _actor();
      final item = _item(author: author);
      final calls = _Calls();
      await _pumpHeader(tester, item, calls);

      await tester.tap(find.text('selinaksoy paylaştı', findRichText: true));
      await tester.pump();

      expect(calls.openedAuthors, [author]);
      expect(calls.openedItems, isEmpty);
    });

    testWidgets('all profile families keep their canonical visible name', (
      tester,
    ) async {
      for (final profile in const [
        ('VENUE', 'Kadıköy Sahne'),
        ('STUDIO', 'Harbiye Katman'),
        ('BAND', 'Gece Yolcuları'),
        ('LISTENER', 'defnepolat'),
      ]) {
        final publisher = _actor(
          profileType: profile.$1,
          username: 'different-account-name',
          displayName: profile.$2,
        );
        final calls = _Calls();
        await _pumpHeader(tester, _item(author: publisher), calls);

        final label = find.text('${profile.$2} paylaştı', findRichText: true);
        expect(label, findsOneWidget);
        expect(find.textContaining('different-account-name'), findsNothing);
        await tester.tap(label);
        await tester.pump();
        expect(calls.openedAuthors, [publisher]);
        expect(calls.openedItems, isEmpty);
      }
      await _pumpHeader(
        tester,
        _item(author: _actor(username: null)),
        _Calls(),
      );

      expect(
        find.text('Müzisyen paylaştı', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('Eski Sahne Adı'), findsNothing);
    });

    testWidgets('promotion disclosure takes precedence over organic sharing', (
      tester,
    ) async {
      for (final disclosure in const [
        ('SPONSORED', 'Sponsorlu'),
        ('FEATURED', 'Öne Çıkan'),
        ('PLATFORM_ANNOUNCEMENT', 'SoundConnect duyurusu'),
        ('FUTURE_PROMOTION', 'Sponsorlu'),
      ]) {
        final calls = _Calls();
        await _pumpHeader(
          tester,
          _item(
            author: _actor(),
            reasonActors: [_actor()],
            promotion: MusicianFeedPromotion(
              campaignId: 'campaign-id',
              disclosure: disclosure.$1,
              ctaLabel: null,
              ctaUrl: null,
            ),
          ),
          calls,
        );

        expect(find.text(disclosure.$2), findsOneWidget);
        expect(
          find.textContaining('paylaştı', findRichText: true),
          findsNothing,
        );
        expect(find.byType(AppCachedNetworkImage), findsNothing);
        expect(_profileSemantics('selinaksoy'), findsNothing);
        expect(calls.openedAuthors, isEmpty);
      }
    });

    testWidgets(
      'missing reason actor and absent or unfollowed author remain neutral',
      (tester) async {
        for (final author in [null, _actor(followedByViewer: false)]) {
          final calls = _Calls();
          await _pumpHeader(tester, _item(author: author), calls);

          expect(find.text('Paylaşım'), findsOneWidget);
          expect(find.byType(AppCachedNetworkImage), findsNothing);
          expect(_activeHeaderLinks(), findsNothing);
          expect(find.textContaining('Takip ettiğin bir profil'), findsNothing);
          expect(calls.openedAuthors, isEmpty);
        }
      },
    );

    testWidgets('invalid profile IDs disable profile navigation', (
      tester,
    ) async {
      for (final invalidId in <String?>[null, '', ' ', '../another-profile']) {
        final calls = _Calls();
        await _pumpHeader(
          tester,
          _item(author: _actor(profileId: invalidId)),
          calls,
        );

        expect(
          find.text('selinaksoy paylaştı', findRichText: true),
          findsOneWidget,
        );
        expect(_activeHeaderLinks(), findsNothing);
        await tester.tap(find.text('selinaksoy paylaştı', findRichText: true));
        await tester.pump();
        expect(calls.openedAuthors, isEmpty);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('missing or unusable avatars show the canonical initial', (
      tester,
    ) async {
      for (final avatar in <String?>[null, 'file:///private/avatar.jpg']) {
        await _pumpHeader(
          tester,
          _item(author: _actor(avatarUrl: avatar)),
          _Calls(),
        );

        expect(find.byType(AppCachedNetworkImage), findsOneWidget);
        expect(find.text('S'), findsOneWidget);
        expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
      'long names fit at 320dp and 200 percent text with both controls',
      (tester) async {
        final calls = _Calls();
        final item = _item(
          author: _actor(
            username: 'cok_uzun_bir_muzisyen_kullanici_adi_ve_devami',
          ),
          feedbackCapabilities: const {
            MusicianFeedFeedbackAction.hide,
            MusicianFeedFeedbackAction.showLess,
          },
        );
        await _pumpHeader(
          tester,
          item,
          calls,
          size: const Size(320, 640),
          textScale: 2,
          showOverflow: true,
        );

        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Kart seçenekleri'), findsOneWidget);
        expect(find.byTooltip('Bu kartı gizle'), findsOneWidget);

        await tester.tap(find.byTooltip('Bu kartı gizle'));
        await tester.pump();
        expect(calls.feedbackItems, [item]);
        expect(calls.feedbackActions, [MusicianFeedFeedbackAction.hide]);
        expect(calls.openedAuthors, isEmpty);
        expect(calls.openedItems, isEmpty);

        await tester.tap(find.byTooltip('Kart seçenekleri'));
        await tester.pumpAndSettle();
        expect(find.text('Bunun gibi daha az göster'), findsOneWidget);
        expect(calls.openedAuthors, isEmpty);
        expect(calls.openedItems, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Finder _profileSemantics(String name) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.button == true &&
      widget.properties.label == '$name profilini aç',
);

Finder _activeHeaderLinks() => find.descendant(
  of: find.byType(MusicianFeedReasonRow),
  matching: find.byWidgetPredicate(
    (widget) => widget is InkWell && widget.onTap != null,
  ),
);

MusicianFeedActor _actor({
  String profileType = 'MUSICIAN',
  String? profileId = 'musician-profile-id',
  String? username = 'selinaksoy',
  String displayName = 'Eski Sahne Adı',
  String? avatarUrl,
  bool followedByViewer = true,
}) => MusicianFeedActor(
  userId: 'actor-user-id',
  profileId: profileId,
  profileType: profileType,
  username: username,
  displayName: displayName,
  avatarUrl: avatarUrl,
  followedByViewer: followedByViewer,
);

MusicianFeedItem _item({
  MusicianFeedActor? author,
  List<MusicianFeedActor> reasonActors = const [],
  MusicianFeedPromotion? promotion,
  Set<MusicianFeedFeedbackAction> feedbackCapabilities = const {},
}) => MusicianFeedItem(
  id: 'event-feed-item',
  type: MusicianFeedItemType.event,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 12),
  position: 0,
  impressionToken: 'test-delivery-token',
  reason: MusicianFeedReason(
    code: 'FOLLOWING_PUBLICATION',
    actors: reasonActors,
    secondaryActorCount: 0,
  ),
  author: author,
  target: const MusicianFeedTarget(type: 'EVENT', id: 'event-id'),
  engagement: null,
  promotion: promotion,
  feedbackCapabilities: feedbackCapabilities,
  payload: const EventFeedPayload(event: {}, note: null, publicationId: null),
);

class _Calls {
  final openedAuthors = <MusicianFeedActor>[];
  final authorItems = <MusicianFeedItem>[];
  final openedItems = <MusicianFeedItem>[];
  final feedbackItems = <MusicianFeedItem>[];
  final feedbackActions = <MusicianFeedFeedbackAction>[];

  late final actions = MusicianFeedCardActions(
    openItem: openedItems.add,
    openAuthor: (item, actor) {
      authorItems.add(item);
      openedAuthors.add(actor);
    },
    toggleLike: (_) {},
    openComments: (_) {},
    openLikes: (_) {},
    feedback: (item, action) {
      feedbackItems.add(item);
      feedbackActions.add(action);
    },
    muteAuthor: (_, _) {},
    openCompletionTask: (_) {},
    openPromotion: (_) {},
    toggleCollabSaved: (_, _) {},
    followProfile: (_) {},
  );
}

Future<void> _pumpHeader(
  WidgetTester tester,
  MusicianFeedItem item,
  _Calls calls, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool showOverflow = false,
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
              child: Material(
                child: InkWell(
                  onTap: () => calls.actions.openItem(item),
                  child: MusicianFeedReasonRow(
                    item: item,
                    actions: calls.actions,
                    showOverflow: showOverflow,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpSurface(
  WidgetTester tester,
  MusicianFeedItem item,
  _Calls calls, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool showAuthor = true,
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
              child: MusicianFeedSurface(
                item: item,
                actions: calls.actions,
                showAuthor: showAuthor,
                child: const Text('Etkinlik içeriği'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
