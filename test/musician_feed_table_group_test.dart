import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/musician_feed_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_registry.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_detail_link.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_profile_share_source_model.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/widgets/table_group_share_preview.dart';
import 'package:soundconnect_23_12_25codx/preview/data/preview_feed_catalogue.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'feed reuses public table details with independent share actions',
    (tester) async {
      final item = _item(_source());
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

      final preview = tester.widget<TableGroupSharePreview>(
        find.byType(TableGroupSharePreview),
      );
      expect(preview.compact, isTrue);
      expect(preview.table.id, 'source-table');
      expect(find.text('Kadıköy · İstanbul'), findsOneWidget);
      expect(find.text('Arka Oda'), findsOneWidget);
      expect(find.text('3/6 kişi'), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.person_outline_rounded), findsNWidgets(3));
      expect(find.text('Masayı gör'), findsOneWidget);

      await tester.tap(find.text('Beğen'));
      await tester.tap(find.text('Yorum'));
      expect(liked.single, same(item));
      expect(commented.single, same(item));
      expect(liked.single.engagement!.targetType, 'TABLE_GROUP_POST');
      expect(liked.single.engagement!.targetId, 'listener-share');
      expect(opened, isEmpty);

      await tester.tap(find.text('Masayı gör'));
      expect(opened.single, same(item));
      expect(
        (opened.single.payload as ProfileShareFeedPayload).source['id'],
        'source-table',
      );
      expect(opened.single.target!.id, 'listener-share');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final status in ['ACTIVE', 'INACTIVE', 'CANCELLED']) {
    testWidgets('$status ended table disables source navigation only', (
      tester,
    ) async {
      final opened = <MusicianFeedItem>[];
      final commented = <MusicianFeedItem>[];
      final item = _item(_source(status: status, ended: true));
      await _pumpCard(
        tester,
        item,
        _actions(openItem: opened.add, openComments: commented.add),
      );

      expect(find.byType(TableGroupSharePreview), findsOneWidget);
      expect(find.text('Masayı gör'), findsNothing);
      expect(find.byType(MusicianFeedDetailLink), findsNothing);
      expect(
        find.text(
          status == 'CANCELLED'
              ? 'Bu masa kapatıldı'
              : 'Bu masanın süresi doldu',
        ),
        findsOneWidget,
      );
      expect(
        find.text('3/6 kişi'),
        status == 'ACTIVE' ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('Katılımcı bilgisi güncelleniyor…'),
        status == 'ACTIVE' ? findsOneWidget : findsNothing,
      );

      await tester.tap(find.text('Konser öncesi müzik konuşalım.'));
      expect(opened, isEmpty);
      await tester.tap(find.text('Yorum'));
      expect(commented.single, same(item));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('fresh final snapshot replaces pending participant information', (
    tester,
  ) async {
    await _pumpCard(tester, _item(_source(ended: true)), _actions());
    expect(find.text('Katılımcı bilgisi güncelleniyor…'), findsOneWidget);

    await _pumpCard(
      tester,
      _item({..._source(status: 'INACTIVE', ended: true), 'acceptedCount': 5}),
      _actions(),
    );
    expect(find.text('Katılımcı bilgisi güncelleniyor…'), findsNothing);
    expect(find.text('5/6 kişi'), findsOneWidget);
    expect(find.text('Masayı gör'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('incomplete source keeps detail access without inventing seats', (
    tester,
  ) async {
    final opened = <MusicianFeedItem>[];
    final item = _item(const {
      'id': 'source-table',
      'description': 'Eski bir masa paylaşımı.',
    });
    await _pumpCard(tester, item, _actions(openItem: opened.add));

    expect(find.byType(TableGroupSharePreview), findsNothing);
    expect(find.text('Eski bir masa paylaşımı.'), findsOneWidget);
    expect(find.text('Masa ayrıntılarını gör'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d+/\d+ kişi')), findsNothing);
    expect(find.byIcon(Icons.person_rounded), findsNothing);
    expect(find.text('Bu masanın süresi doldu'), findsNothing);
    await tester.tap(find.text('Masa ayrıntılarını gör'));
    expect(opened.single, same(item));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('table metadata fits 320 dp with double text size', (
    tester,
  ) async {
    final item = _item({
      ..._source(),
      'description':
          'Konserden önce bir araya gelip bağımsız müzik üretimini '
          've yeni sahneleri konuşmak isteyen herkes masamıza katılabilir.',
      'venueName': 'Çok uzun adı olan bağımsız müzik ve kültür sahnesi',
      'districtName': 'Uzun bir ilçe adı',
    });
    await _pumpCard(
      tester,
      item,
      _actions(),
      size: const Size(320, 900),
      textScale: 2,
    );

    expect(find.byType(TableGroupSharePreview), findsOneWidget);
    expect(find.text('3/6 kişi'), findsOneWidget);
    expect(find.text('Masayı gör'), findsOneWidget);
    await tester.ensureVisible(find.text('Masayı gör'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'all preview tables use canonical public snapshots and share targets',
    () {
      final now = DateTime.utc(2026, 9, 13, 18);
      final scenarios = buildPreviewFeedCatalogue(now: now)
          .where(
            (scenario) =>
                scenario.item.type ==
                MusicianFeedItemType.tableGroupProfileShare,
          )
          .toList();
      expect(scenarios, hasLength(4));
      for (final scenario in scenarios) {
        final payload = scenario.item.payload as ProfileShareFeedPayload;
        final table = parseTableGroupProfileShareSource(payload.source);
        expect(table.id, isNot(payload.shareId), reason: scenario.id);
        expect(
          scenario.item.target!.type,
          'TABLE_GROUP_POST',
          reason: scenario.id,
        );
        expect(scenario.item.target!.id, payload.shareId, reason: scenario.id);
        expect(
          scenario.item.engagement!.targetId,
          payload.shareId,
          reason: scenario.id,
        );
        expect(
          table.acceptedCount,
          lessThanOrEqualTo(table.maxPersonCount),
          reason: scenario.id,
        );
        expect(
          table.isActiveAt(now),
          scenario.id != 'tablegroup-long',
          reason: scenario.id,
        );
      }
    },
  );
}

Map<String, dynamic> _source({String status = 'ACTIVE', bool ended = false}) {
  final expiry = DateTime.now().toUtc().add(
    ended ? const Duration(hours: -1) : const Duration(hours: 3),
  );
  return {
    'id': 'source-table',
    'description': 'Konser öncesi müzik konuşalım.',
    'venueName': 'Arka Oda',
    'cityName': 'İstanbul',
    'districtName': 'Kadıköy',
    'meetingAt': expiry.toIso8601String(),
    'expiresAt': expiry.toIso8601String(),
    'status': status,
    'maxPersonCount': 6,
    'acceptedCount': 3,
  };
}

MusicianFeedItem _item(Map<String, dynamic> source) => MusicianFeedItem(
  id: 'table-profile-share',
  type: MusicianFeedItemType.tableGroupProfileShare,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 13),
  position: 0,
  impressionToken: 'table-delivery-token',
  reason: const MusicianFeedReason(
    code: 'DISCOVERY',
    actors: [],
    secondaryActorCount: 0,
  ),
  author: null,
  target: const MusicianFeedTarget(
    type: 'TABLE_GROUP_POST',
    id: 'listener-share',
  ),
  engagement: const MusicianFeedEngagement(
    targetType: 'TABLE_GROUP_POST',
    targetId: 'listener-share',
    likeCount: 7,
    commentCount: 3,
    likedByMe: false,
    likable: true,
    commentable: true,
  ),
  promotion: null,
  feedbackCapabilities: const {},
  payload: ProfileShareFeedPayload(
    shareId: 'listener-share',
    note: 'Konserden önce burada buluşuyoruz.',
    publishedAt: DateTime.utc(2026, 9, 13),
    source: source,
  ),
);

MusicianFeedCardActions _actions({
  void Function(MusicianFeedItem)? openItem,
  void Function(MusicianFeedItem)? toggleLike,
  void Function(MusicianFeedItem)? openComments,
}) => MusicianFeedCardActions(
  openItem: openItem ?? (_) {},
  openAuthor: (_, _) {},
  toggleLike: toggleLike ?? (_) {},
  openComments: openComments ?? (_) {},
  openLikes: (_) {},
  feedback: (_, _) {},
  muteAuthor: (_, _) {},
  openCompletionTask: (_) {},
  openPromotion: (_) {},
  toggleCollabSaved: (_, _) {},
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
}
