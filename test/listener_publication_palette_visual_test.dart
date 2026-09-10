import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_profile_share.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_overthinking_share_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_table_group_share_card.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_profile_share.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/event_poster_fallback.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

final _previewNow = DateTime(2026, 9, 10, 22, 30);
const _longTitle =
    'Bir şarkının içinde kaybolup yeniden kendimizi bulduğumuz akşamlar';
const _longContent =
    'Koca bir sessizliğin içinde aynı melodiyi duyunca insan kendini daha az '
    'yalnız hissediyor. Bazen bir konserden geriye kalan, şarkılardan çok '
    'yanımızda duran insanların sesleri oluyor. O anları yeniden hatırlamak '
    've müzikle paylaşmak istediğimiz daha pek çok hikâye var.';

void main() {
  testWidgets(
    'anonymous long source keeps attribution private and actions reachable at 320px',
    (tester) async {
      final calls = <String>[];
      await _pump(
        tester,
        _overthinking(
          longContent: true,
          onOpen: () => calls.add('open'),
          onLike: () => calls.add('like'),
          onComments: () => calls.add('comments'),
        ),
        width: 320,
        textScale: 1.6,
      );
      expect(find.text('Anonim yazar'), findsOneWidget);
      expect(find.textContaining('private_source_author'), findsNothing);
      expect(find.text('@berna'), findsOneWidget);
      for (final action in ['open', 'like', 'comments']) {
        final target = find.byKey(
          ValueKey('listener-overthinking-$action-ot-share'),
        );
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        final bounds = tester.getRect(target);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(320));
        await tester.tap(target);
      }
      expect(calls, ['open', 'like', 'comments']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ended event with long metadata and no poster retains source and discussion access',
    (tester) async {
      final calls = <String>[];
      await _pump(
        tester,
        _event(
          longContent: true,
          ended: true,
          onOpen: () => calls.add('open'),
          onLike: () => calls.add('like'),
          onComments: () => calls.add('comments'),
        ),
        width: 320,
        textScale: 1.6,
      );
      expect(find.byType(EventPosterFallback), findsOneWidget);
      expect(find.text('Bu etkinliğe gitmeyi planlamıştı.'), findsOneWidget);
      expect(find.text('Bu etkinliğe katılmayı planlamıştın.'), findsOneWidget);
      expect(find.text('Ben de gidiyorum'), findsNothing);
      for (final action in ['open', 'like', 'comments']) {
        final target = find.byKey(ValueKey('listener-event-$action-event'));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        final bounds = tester.getRect(target);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(320));
        await tester.tap(target);
      }
      expect(calls, ['open', 'like', 'comments']);
      expect(tester.takeException(), isNull);
    },
  );

  final outputPath = Platform.environment['LISTENER_PUBLICATION_RENDER_DIR'];
  testWidgets(
    'render matching published surfaces and actual draft card slots',
    (tester) async {
      await tester.runAsync(_loadFonts);
      for (final width in [390.0, 320.0]) {
        final fixtures = <String, Widget>{
          'profile': Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Paylaşımlar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _table(),
              const SizedBox(height: 16),
              _overthinking(),
              const SizedBox(height: 16),
              _event(),
            ],
          ),
          'table-draft': _table(draft: true),
          'overthinking-draft': _overthinking(draft: true),
          'event-draft': _event(draft: true),
          'anonymous-long': _overthinking(longContent: true),
          'event-ended-long': _event(longContent: true, ended: true),
        };
        for (final fixture in fixtures.entries) {
          final capture = GlobalKey();
          await _pump(
            tester,
            fixture.value,
            width: width,
            textScale: width == 320 ? 1.6 : 1,
            capture: capture,
          );
          // Decode the exact asset provider used by the fallback (including its
          // resize key) before the first capture, not just later cached frames.
          final bundledImages = find
              .byType(Image)
              .evaluate()
              .map((element) => (element.widget as Image).image);
          await tester.runAsync(() async {
            for (final provider in bundledImages) {
              await precacheImage(provider, capture.currentContext!);
            }
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: fixture.key);
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final pixels = await boundary.toImage(pixelRatio: 2);
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(outputPath!).create(recursive: true);
            await File(
              '$outputPath/${fixture.key}-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            pixels.dispose();
          });
        }
      }
    },
    skip: outputPath == null,
  );
}

Widget _table({bool draft = false}) {
  final source = TableGroupProfileShareSource(
    id: 'table',
    description: 'Gelin',
    venueName: null,
    cityName: 'Ankara',
    districtName: 'Çankaya',
    meetingAt: _previewNow.add(const Duration(minutes: 30)),
    expiresAt: _previewNow.add(const Duration(hours: 1)),
    status: 'ACTIVE',
    maxPersonCount: 4,
    acceptedCount: 1,
  );
  if (draft) {
    return ListenerTableGroupShareCard.draft(
      tableGroup: source,
      username: 'berna',
      now: _previewNow,
      noteEditor: _noteEditor('Bu masa için birkaç söz ekle…'),
      actions: _draftActions(),
    );
  }
  return ListenerTableGroupShareCard(
    share: TableGroupProfileShare(
      shareId: 'table-share',
      note: 'Heyooo',
      publishedAt: _previewNow,
      tableGroup: source,
      likeCount: 3,
      commentCount: 7,
      likedByMe: false,
    ),
    username: 'berna',
    now: _previewNow,
    onOpen: () {},
    onRemove: () {},
    onLike: () {},
    onComments: () {},
    likeCount: 3,
    commentCount: 7,
  );
}

Widget _overthinking({
  bool draft = false,
  bool longContent = false,
  VoidCallback? onOpen,
  VoidCallback? onLike,
  VoidCallback? onComments,
}) {
  final source = OverthinkingPostModel.fromJson({
    'id': 'overthinking',
    'title': longContent ? _longTitle : 'remembrance',
    'content': longContent
        ? _longContent
        : 'Koca bir saçmalık raylar wont black down olunca insanın aklına '
              'düşen bütün o şarkılar…',
    'authorId': 'source-author',
    'authorUsername': longContent ? 'private_source_author' : 'berna',
    'anonymous': longContent,
    'visibilityType': longContent ? 'ANONYMOUS' : 'VISIBLE',
    'canViewAuthor': !longContent,
    'spotifyTrackName': 'How to Disappear Completely',
    'spotifyArtistName': 'Radiohead',
    'likeCount': 12,
    'commentCount': 4,
  });
  if (draft) {
    return ListenerOverthinkingShareCard.draft(
      post: source,
      username: 'berna',
      noteEditor: _noteEditor('Bu yazı için birkaç söz ekle…'),
      actions: _draftActions(),
    );
  }
  return ListenerOverthinkingShareCard(
    share: OverthinkingProfileShare(
      shareId: 'ot-share',
      note: 'Bu şarkının bıraktığı his…',
      publishedAt: _previewNow,
      post: source,
    ),
    username: 'berna',
    onOpen: onOpen ?? () {},
    onRemove: () {},
    onLike: onLike ?? () {},
    onComments: onComments ?? () {},
  );
}

Widget _event({
  bool draft = false,
  bool longContent = false,
  bool ended = false,
  VoidCallback? onOpen,
  VoidCallback? onLike,
  VoidCallback? onComments,
}) => ListenerEventPostCard(
  event: VenueEventDetail(
    id: 'event',
    shareUrl: null,
    posterImage: null,
    performerName: longContent
        ? 'Ankara Bağımsız Müzisyenler ve Arkadaşları'
        : 'Büyük Ev Ablukada',
    musicianProfileId: null,
    title: longContent ? _longTitle : 'Bir akşam, aynı şarkılar',
    eventDate: _previewNow.subtract(Duration(days: ended ? 1 : 0)),
    startTime: '20:30',
    endTime: '23:30',
    venueName: longContent
        ? 'Kavaklıdere Müzik Atölyesi ve Kültür Buluşmaları Sahnesi'
        : '6:45 KK Ankara',
    venueCity: 'Ankara',
    venueDistrict: 'Çankaya',
  ),
  username: 'berna',
  intentLabel: 'Gidiyorum',
  owner: true,
  ended: ended,
  note: 'Bu akşam aynı şarkılara eşlik edelim.',
  visibilityLabel: draft ? 'Taslak · Henüz paylaşılmadı' : null,
  onOpen: draft ? null : onOpen ?? () {},
  onIntent: null,
  onDelete: draft ? null : () {},
  onLike: draft ? null : onLike ?? () {},
  onComments: draft ? null : onComments ?? () {},
  likeCount: draft ? null : 8,
  commentCount: draft ? null : 2,
  noteEditor: draft ? _noteEditor('Bu etkinlik için birkaç söz ekle…') : null,
  actions: draft ? _draftActions() : null,
);

// Card-slot fixtures use the production input/button widgets; repository and
// composer lifecycle behavior is covered by each existing composer test suite.
Widget _noteEditor(String hint) => TextField(
  minLines: 3,
  maxLines: 5,
  decoration: InputDecoration(
    labelText: 'Açıklama (isteğe bağlı)',
    hintText: hint,
    counterText: '0/500',
    alignLabelWithHint: true,
  ),
);

Widget _draftActions() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const SizedBox(height: 12),
    GradientOutlineButton(
      label: 'Paylaş',
      strokeWidth: .7,
      leading: const Icon(Icons.publish_rounded, size: 18),
      onPressed: () {},
    ),
    TextButton(onPressed: () {}, child: const Text('Vazgeç')),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double textScale = 1,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = Size(width, capture == null ? 900 : 4400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: capture == null
          ? AppTheme.navy
          : AppTheme.navy.copyWith(
              textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
              primaryTextTheme: AppTheme.navy.primaryTextTheme.apply(
                fontFamily: 'Roboto',
              ),
            ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: ListenerProfileTheme(
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: capture == null
                ? child
                : RepaintBoundary(
                    key: capture,
                    child: ColoredBox(
                      color: listenerProfileDeepSurface,
                      child: child,
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _loadFonts() async {
  final fonts =
      '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
  final loader = FontLoader('Roboto');
  for (final font in [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    loader.addFont(
      File('$fonts/$font').readAsBytes().then(ByteData.sublistView),
    );
  }
  await loader.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}
