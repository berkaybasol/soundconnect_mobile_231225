import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_like_users_target.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/musician_feed_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_chrome.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_registry.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  for (final reason in ['FOLLOWED_USER_LIKED', 'FOLLOWING_LIKED']) {
    testWidgets('$reason opens likers, never the enclosing content', (
      tester,
    ) async {
      final item = _item(reason: reason);
      final calls = _Calls();
      await _pump(tester, item, calls);
      await tester.tap(find.text('leylasaman ve 6 kişi daha bunu beğendi'));
      expect(calls.likes, [item]);
      expect(calls.opened, isEmpty);
      expect(calls.hidden, isEmpty);
      expect(musicianFeedLikeUsersTarget(calls.likes.single), (
        targetType: 'OVERTHINKING_PROFILE_SHARE',
        targetId: 'profile-share-id',
      ));
      expect(
        find.bySemanticsLabel(RegExp('Beğenenleri göster')),
        findsOneWidget,
      );
    });
  }

  testWidgets('narrow large text preserves independent hide and menu taps', (
    tester,
  ) async {
    final calls = _Calls();
    final item = _item();
    await _pump(tester, item, calls, narrow: true);
    final button = find
        .descendant(
          of: find.byType(MusicianFeedReasonRow),
          matching: find.byWidgetPredicate(
            (w) => w is InkWell && w.onTap != null,
          ),
        )
        .first;
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Bu kartı gizle'));
    expect(calls.hidden, [item]);
    expect(calls.likes, isEmpty);
    expect(calls.opened, isEmpty);
    await tester.tap(find.byTooltip('Kart seçenekleri'));
    await tester.pumpAndSettle();
    expect(find.text('Bunun gibi daha az göster'), findsOneWidget);
    expect(calls.likes, isEmpty);
    expect(calls.opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comment activity is not a likers link', (tester) async {
    final calls = _Calls();
    await _pump(tester, _item(reason: 'FOLLOWED_USER_COMMENTED'), calls);
    expect(find.bySemanticsLabel(RegExp('Beğenenleri göster')), findsNothing);
  });

  testWidgets('missing engagement never guesses from target or actor', (
    tester,
  ) async {
    final item = _item(hasEngagement: false);
    await _pump(tester, item, _Calls());
    expect(musicianFeedLikeUsersTarget(item), isNull);
    expect(find.bySemanticsLabel(RegExp('Beğenenleri göster')), findsNothing);
  });

  testWidgets('promotion disclosure does not turn into likers action', (
    tester,
  ) async {
    await _pump(tester, _item(promoted: true), _Calls());
    expect(find.bySemanticsLabel(RegExp('Beğenenleri göster')), findsNothing);
  });

  test('all feed engagement families preserve their exact target identity', () {
    for (final targetType in [
      'MEDIA',
      'EVENT',
      'EVENT_POST',
      'TABLE_GROUP_POST',
      'OVERTHINKING_PROFILE_SHARE',
    ]) {
      expect(musicianFeedLikeUsersTarget(_item(targetType: targetType)), (
        targetType: targetType,
        targetId: 'profile-share-id',
      ));
    }
    expect(musicianFeedLikeUsersTarget(_item(targetType: 'PROFILE')), isNull);
    for (final id in [
      '',
      ' bad',
      '../bad',
      'bad\\id',
      'bad\u0000id',
      'a' * 129,
    ]) {
      expect(musicianFeedLikeUsersTarget(_item(targetId: id)), isNull);
    }
  });
}

MusicianFeedItem _item({
  String reason = 'FOLLOWED_USER_LIKED',
  String targetType = 'OVERTHINKING_PROFILE_SHARE',
  String targetId = 'profile-share-id',
  bool hasEngagement = true,
  bool promoted = false,
}) => MusicianFeedItem(
  id: 'activity-like-card',
  type: MusicianFeedItemType.activityLike,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 12),
  position: 0,
  impressionToken: 'test-token',
  reason: MusicianFeedReason(
    code: reason,
    actors: const [
      MusicianFeedActor(
        userId: 'actor-user-id',
        profileId: 'actor-profile-id',
        profileType: 'MUSICIAN',
        username: 'leylasaman',
        displayName: 'Legacy name must not appear',
        avatarUrl: null,
        followedByViewer: true,
      ),
    ],
    secondaryActorCount: 6,
  ),
  author: null,
  target: const MusicianFeedTarget(type: 'OVERTHINKING', id: 'wrong-source-id'),
  engagement: hasEngagement
      ? MusicianFeedEngagement(
          targetType: targetType,
          targetId: targetId,
          likeCount: 20,
          commentCount: 2,
          likedByMe: false,
          likable: true,
          commentable: true,
        )
      : null,
  promotion: promoted
      ? const MusicianFeedPromotion(
          campaignId: 'campaign',
          disclosure: 'SPONSORED',
          ctaLabel: null,
          ctaUrl: null,
        )
      : null,
  feedbackCapabilities: const {
    MusicianFeedFeedbackAction.hide,
    MusicianFeedFeedbackAction.showLess,
  },
  payload: const EventFeedPayload(event: {}, note: null, publicationId: null),
);

class _Calls {
  final likes = <MusicianFeedItem>[];
  final opened = <MusicianFeedItem>[];
  final hidden = <MusicianFeedItem>[];
  late final actions = MusicianFeedCardActions(
    openItem: opened.add,
    openAuthor: (_, _) {},
    toggleLike: (_) {},
    openComments: (_) {},
    openLikes: likes.add,
    feedback: (item, _) => hidden.add(item),
    muteAuthor: (_, _) {},
    openCompletionTask: (_) {},
    openPromotion: (_) {},
    toggleCollabSaved: (_, _) {},
    followProfile: (_) {},
  );
}

Future<void> _pump(
  WidgetTester tester,
  MusicianFeedItem item,
  _Calls calls, {
  bool narrow = false,
}) async {
  final size = Size(narrow ? 320 : 390, 844);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(narrow ? 2 : 1),
        ),
        child: Scaffold(
          body: MusicianFeedThemeScope(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: MusicianFeedSurface(
                item: item,
                actions: calls.actions,
                showAuthor: false,
                onTap: () => calls.opened.add(item),
                child: const Text('İçerik'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
