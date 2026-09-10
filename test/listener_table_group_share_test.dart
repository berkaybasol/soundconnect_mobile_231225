import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/policy/stage_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_thread_view.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_posts.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_table_group_share_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_table_group_share_tile.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';

const _likeKey = Key('listener-table-group-like-publication');
const _commentsKey = Key('listener-table-group-comments-publication');
const _externalShareKey = Key(
  'listener-table-group-external-share-publication',
);

void main() {
  if (Platform.environment['LISTENER_TABLE_CARD_RENDER_DIR'] != null) {
    testWidgets('render table share cards with real fonts', (tester) async {
      await tester.runAsync(() async {
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
      });
      final previewNow = DateTime(2026, 9, 10, 22, 30);
      for (final variant in [
        'published',
        'draft',
        'expired',
        'closed',
        'long',
      ]) {
        final draft = variant == 'draft';
        final longContent = variant == 'long';
        for (final width in [320.0, 390.0]) {
          final capture = GlobalKey();
          final source = _share(
            variant == 'expired'
                ? previewNow.subtract(const Duration(days: 1))
                : previewNow,
            note: longContent
                ? 'Bu akşam sevdiğimiz şarkıları, unutamadığımız konserleri ve '
                      'yeni keşiflerimizi konuşmak için buluşuyoruz. '
                      'Kendine bir yer ayır, sohbetimize katıl!'
                : 'Heyooo',
            description: longContent
                ? 'Biraz müzik, biraz sohbet; bu akşam aynı masada buluşalım.'
                : 'Gelin',
            venueName: longContent
                ? 'Kavaklıdere Müzik Atölyesi ve Kültür Buluşmaları'
                : null,
            status: switch (variant) {
              'expired' => 'INACTIVE',
              'closed' => 'CANCELLED',
              _ => 'ACTIVE',
            },
            acceptedCount: variant == 'expired' ? 3 : 1,
          );
          final username = longContent
              ? 'uzun_kullanici_adi_icin_tasarim_kontrolu'
              : 'berna';
          tester.view.physicalSize = Size(width, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.navy.copyWith(
                textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 1.6 : 1),
                ),
                child: child!,
              ),
              home: ListenerProfileTheme(
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: RepaintBoundary(
                      key: capture,
                      child: draft
                          ? ListenerTableGroupShareCard.draft(
                              tableGroup: source.tableGroup,
                              username: username,
                              now: previewNow,
                              noteEditor: const TextField(
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: 'Bir not ekle…',
                                ),
                              ),
                              actions: Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () {},
                                      child: const Text('Vazgeç'),
                                    ),
                                  ),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () {},
                                      child: const Text('Paylaş'),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListenerTableGroupShareCard(
                              share: source,
                              username: username,
                              now: previewNow,
                              likeCount: 3,
                              commentCount: 7,
                              onOpen: () {},
                              onRemove: () {},
                              onLike: () {},
                              onComments: () {},
                              onShare: () {},
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final pixels =
                await (capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final output = Directory(
              Platform.environment['LISTENER_TABLE_CARD_RENDER_DIR']!,
            );
            await output.create(recursive: true);
            await File(
              '${output.path}/$variant-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            pixels.dispose();
          });
        }
      }
    });
  }

  late _Shares shares;
  late _Engagement engagement;
  late AudienceTestSessions sessions;
  late ValueNotifier<TableGroupProfileShare> row;
  late DateTime now;
  late bool current;
  late int refreshes;
  late List<String> removed;
  late List<String> errors;
  late List<String> opened;
  late List<(int, int, bool)> savedEngagement;
  late GlobalKey<NavigatorState> navigator;
  TableGroupDetailArgs? openedArgs;

  setUp(() {
    shares = _Shares();
    engagement = _Engagement();
    sessions = AudienceTestSessions(audienceSession(user: 'sharer'));
    now = DateTime.utc(2026, 9, 10, 12);
    row = ValueNotifier(_share(now));
    current = true;
    refreshes = 0;
    removed = [];
    errors = [];
    opened = [];
    savedEngagement = [];
    navigator = GlobalKey<NavigatorState>();
    openedArgs = null;
  });

  tearDown(() {
    shares.signal.dispose();
    sessions.dispose();
    row.dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    bool owner = true,
    bool useRoute = false,
    bool lazy = false,
    bool persistEngagement = false,
    Future<void> Function()? onSourceRefresh,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final tile = ValueListenableBuilder<TableGroupProfileShare>(
      valueListenable: row,
      builder: (_, share, _) => ListenerTableGroupShareTile(
        share: share,
        username: 'sharer',
        ownerUserId: owner ? 'sharer' : null,
        sessions: sessions,
        repository: shares,
        engagementRepository: engagement,
        now: () => now,
        isCurrent: () => current,
        onRefresh: () async => refreshes++,
        onSourceRefresh: onSourceRefresh,
        onRemoved: removed.add,
        onError: errors.add,
        onEngagementChanged: persistEngagement
            ? (stats) {
                savedEngagement.add((
                  stats.likeCount,
                  stats.commentCount,
                  stats.isLiked,
                ));
                row.value = TableGroupProfileShare(
                  shareId: share.shareId,
                  note: share.note,
                  publishedAt: share.publishedAt,
                  tableGroup: share.tableGroup,
                  likeCount: stats.likeCount,
                  commentCount: stats.commentCount,
                  likedByMe: stats.isLiked,
                );
              }
            : null,
        onOpenSource: useRoute ? null : (id) async => opened.add(id),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        onGenerateRoute: (settings) {
          if (settings.name != AppRoutes.tableGroupDetail) return null;
          openedArgs = settings.arguments! as TableGroupDetailArgs;
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Masa detayı')),
          );
        },
        home: ListenerProfileTheme(
          child: Scaffold(
            body: lazy
                ? ListView.builder(
                    cacheExtent: 0,
                    itemCount: 15,
                    itemBuilder: (_, index) => index == 0
                        ? tile
                        : SizedBox(height: 300, child: Text('Satır $index')),
                  )
                : SingleChildScrollView(child: tile),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDelete(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const Key('listener-table-group-remove-publication')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paylaşımı sil'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'source navigation opens overview with viewer stage and refreshes on return',
    (tester) async {
      await mount(tester, useRoute: true);
      await tester.tap(find.text('Masayı gör'));
      await tester.pumpAndSettle();
      expect(openedArgs?.tableGroupId, 'source-table');
      expect(openedArgs?.openChat, isFalse);
      expect(openedArgs?.bottomBarStageMode, StageMode.mainstage);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      expect(shares.deleted, isEmpty);
    },
  );

  testWidgets(
    'explicit confirmation removes publication identity with the captured session',
    (tester) async {
      await mount(tester);
      final expectedSession = sessions.session;
      await openDelete(tester);
      expect(shares.deleted, isEmpty);
      await tester.tap(
        find.byKey(const Key('listener-table-group-remove-confirm')),
      );
      await tester.pumpAndSettle();
      expect(shares.deleted, ['publication']);
      expect(identical(shares.expectedSession, expectedSession), isTrue);
      expect(removed, ['publication']);
      expect(refreshes, 1);
    },
  );

  testWidgets('public viewer can share but cannot delete the publication', (
    tester,
  ) async {
    await mount(tester, owner: false);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byKey(_externalShareKey), findsOneWidget);
    await tester.tap(find.text('Masayı gör'));
    await tester.pumpAndSettle();
    expect(opened, ['source-table']);
  });

  List<String> captureClipboard(
    WidgetTester tester, {
    Future<void> Function()? onWrite,
  }) {
    final writes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          writes.add((call.arguments as Map)['text'] as String);
          await onWrite?.call();
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return writes;
  }

  testWidgets(
    'share copies only the placeholder and confirms after completion',
    (tester) async {
      final pending = Completer<void>();
      final writes = captureClipboard(tester, onWrite: () => pending.future);
      await mount(tester, owner: false);
      final action = tester
          .widget<IconButton>(find.byKey(_externalShareKey))
          .onPressed!;
      action();
      action();
      await tester.pump();
      expect(writes, ['Buraya link gelecek']);
      expect(find.text('Kopyalandı'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(shares.lookups, isEmpty);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Kopyalandı'), findsOneWidget);
      expect(shares.deleted, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clipboard failure allows retry without claiming success', (
    tester,
  ) async {
    var fail = true;
    final writes = captureClipboard(
      tester,
      onWrite: () async {
        if (fail) throw PlatformException(code: 'clipboard_unavailable');
      },
    );
    await mount(tester);
    await tester.tap(find.byKey(_externalShareKey));
    await tester.pumpAndSettle();
    expect(find.text('Kopyalandı'), findsNothing);
    expect(find.text('Kopyalanamadı. Yeniden deneyebilirsin.'), findsOneWidget);
    fail = false;
    await tester.tap(find.byKey(_externalShareKey));
    await tester.pumpAndSettle();
    expect(writes, ['Buraya link gelecek', 'Buraya link gelecek']);
    expect(find.text('Kopyalandı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale share actions and late clipboard feedback remain inert', (
    tester,
  ) async {
    final pending = Completer<void>();
    final writes = captureClipboard(tester, onWrite: () => pending.future);
    await mount(tester);
    final action = tester
        .widget<IconButton>(find.byKey(_externalShareKey))
        .onPressed!;
    current = false;
    action();
    await tester.pump();
    expect(writes, isEmpty);
    current = true;
    action();
    await tester.pump();
    expect(writes, ['Buraya link gelecek']);
    current = false;
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Kopyalandı'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'placeholder sharing remains available for expired publications',
    (tester) async {
      final writes = captureClipboard(tester);
      row.value = _share(now, lifetime: Duration.zero);
      await mount(tester);
      await tester.tap(find.byKey(_externalShareKey));
      await tester.pumpAndSettle();
      row.value = _share(now, status: 'INACTIVE', lifetime: Duration.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_externalShareKey));
      await tester.pumpAndSettle();
      expect(writes, ['Buraya link gelecek', 'Buraya link gelecek']);
      expect(find.text('Masayı gör'), findsNothing);
      expect(find.text('Bu masanın süresi doldu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel never mutates and a replaced projection cannot inherit an open menu',
    (tester) async {
      await mount(tester);
      await openDelete(tester);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(shares.deleted, isEmpty);
      expect(refreshes, 0);
      await tester.tap(
        find.byKey(const Key('listener-table-group-remove-publication')),
      );
      await tester.pumpAndSettle();
      row.value = _share(now, note: 'Yeni görünüm');
      await tester.pump();
      await tester.tap(find.text('Paylaşımı sil'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('listener-share-delete-dialog')),
        findsNothing,
      );
      expect(shares.deleted, isEmpty);
    },
  );

  testWidgets(
    'session replacement revokes confirmation and pending completion cannot remove next account row',
    (tester) async {
      final pending = Completer<Result<void>>();
      shares.onDelete = () => pending.future;
      await mount(tester);
      await openDelete(tester);
      await tester.tap(
        find.byKey(const Key('listener-table-group-remove-confirm')),
      );
      await tester.pumpAndSettle();
      sessions.replace(audienceSession(user: 'other'));
      await tester.pumpAndSettle();
      pending.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(removed, isEmpty);
      expect(refreshes, 0);
      expect(find.byType(ListenerTableGroupShareCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uncertain deletion refreshes authoritative feed and preserves visible row',
    (tester) async {
      shares.onDelete = () async => const Result.failure(
        AppError(code: 'network', message: 'Bağlantı kesildi'),
      );
      await mount(tester);
      await openDelete(tester);
      await tester.tap(
        find.byKey(const Key('listener-table-group-remove-confirm')),
      );
      await tester.pumpAndSettle();
      expect(removed, isEmpty);
      expect(refreshes, 1);
      expect(find.text('Bağlantı kesildi'), findsOneWidget);
      expect(find.byType(ListenerTableGroupShareCard), findsOneWidget);
    },
  );

  testWidgets(
    'likes belong to share identity and batched reply count survives engagement reconciliation',
    (tester) async {
      await mount(tester);
      expect(engagement.calls, isEmpty);
      await tester.tap(find.byKey(_likeKey));
      await tester.pumpAndSettle();
      expect(engagement.calls.first, (
        'like',
        'TABLE_GROUP_POST',
        'publication',
      ));
      expect(
        engagement.calls.every(
          (call) => call.$2 == 'TABLE_GROUP_POST' && call.$3 == 'publication',
        ),
        isTrue,
      );
      expect(
        find.descendant(of: find.byKey(_likeKey), matching: find.text('4')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(_commentsKey), matching: find.text('7')),
        findsOneWidget,
      );
      expect(refreshes, 0);
    },
  );

  testWidgets(
    'confirmed engagement is saved once to the feed so an idle tile can recycle',
    (tester) async {
      await mount(tester, lazy: true, persistEngagement: true);
      await tester.tap(find.byKey(_likeKey));
      await tester.pumpAndSettle();
      expect(savedEngagement, [(4, 7, true)]);
      expect(row.value.likeCount, 4);
      expect(row.value.commentCount, 7);
      await tester.drag(find.byType(ListView), const Offset(0, -1800));
      await tester.pumpAndSettle();
      expect(
        find.byType(ListenerTableGroupShareTile, skipOffstage: false),
        findsNothing,
      );
      await tester.drag(find.byType(ListView), const Offset(0, 2200));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byKey(_likeKey), matching: find.text('4')),
        findsOneWidget,
      );
      expect(savedEngagement, hasLength(1));
    },
  );

  testWidgets(
    'pending and confirmed like state survive lazy offscreen recycling',
    (tester) async {
      final pending = Completer<Result<void>>();
      engagement.onLike = () => pending.future;
      await mount(tester, lazy: true);
      await tester.tap(find.byKey(_likeKey));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -1800));
      await tester.pumpAndSettle();
      pending.complete(const Result.success(null));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 2200));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byKey(_likeKey), matching: find.text('4')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_likeKey),
          matching: find.byIcon(Icons.favorite_rounded),
        ),
        findsOneWidget,
      );
      expect(engagement.calls.where((call) => call.$1 == 'like'), hasLength(1));
    },
  );

  testWidgets(
    'comment thread uses publication identity and revokes input on feed invalidation',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(_commentsKey));
      await tester.pumpAndSettle();
      final thread = tester.widget<CommentThreadView>(
        find.byType(CommentThreadView),
      );
      expect(thread.targetType, 'TABLE_GROUP_POST');
      expect(thread.targetId, 'publication');
      await tester.enterText(find.byType(TextField), 'Gönderilmeyen taslak');
      shares.signal.value++;
      await tester.pumpAndSettle();
      expect(find.byType(CommentThreadView), findsNothing);
      expect(find.text('Gönderilmeyen taslak'), findsNothing);
      expect(find.text('Bu paylaşım artık görüntülenemiyor.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'local expiry preserves comments and labels the card while final snapshot loads',
    (tester) async {
      row.value = _share(now, lifetime: const Duration(seconds: 10));
      await mount(tester);
      await tester.tap(find.byKey(_commentsKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sohbet devam ediyor');
      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.byType(CommentThreadView), findsOneWidget);
      expect(find.text('Sohbet devam ediyor'), findsOneWidget);
      expect(find.byType(ListenerTableGroupShareCard), findsOneWidget);
      expect(find.text('Bu masanın süresi doldu'), findsOneWidget);
      expect(find.text('Katılımcı bilgisi güncelleniyor…'), findsOneWidget);
      expect(find.text('2/4 kişi'), findsNothing);
      expect(find.text('Masayı gör'), findsNothing);
      expect(refreshes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'final source snapshot preserves an open comment draft and confirms the count',
    (tester) async {
      final publishedAt = now;
      row.value = _share(publishedAt, lifetime: const Duration(seconds: 10));
      await mount(tester);
      await tester.tap(find.byKey(_commentsKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Masadan kalan bir anı');
      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      row.value = _share(
        publishedAt,
        lifetime: const Duration(seconds: 10),
        status: 'INACTIVE',
        acceptedCount: 3,
      );
      await tester.pumpAndSettle();
      expect(find.byType(CommentThreadView), findsOneWidget);
      expect(find.text('Masadan kalan bir anı'), findsOneWidget);
      expect(find.text('3/4 kişi'), findsOneWidget);
      expect(find.text('Katılımcı bilgisi güncelleniyor…'), findsNothing);
      expect(find.text('Masayı gör'), findsNothing);
      expect(find.text('Bu paylaşım artık görüntülenemiyor.'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Hâlâ yazabiliyorum');
      expect(find.text('Hâlâ yazabiliyorum'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expiry requests the source without a full feed reload while comments are open',
    (tester) async {
      final publishedAt = now;
      row.value = _share(publishedAt, lifetime: const Duration(seconds: 10));
      var sourceRefreshes = 0;
      await mount(
        tester,
        onSourceRefresh: () async {
          sourceRefreshes++;
          row.value = _share(
            publishedAt,
            lifetime: const Duration(seconds: 10),
            status: 'INACTIVE',
            acceptedCount: 3,
          );
        },
      );
      await tester.tap(find.byKey(_commentsKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sohbetimiz devam ediyor');
      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(sourceRefreshes, 1);
      expect(refreshes, 0);
      expect(find.text('Sohbetimiz devam ediyor'), findsOneWidget);
      expect(find.text('3/4 kişi'), findsOneWidget);
      expect(find.text('Bu masanın süresi doldu'), findsOneWidget);
      expect(find.text('Masayı gör'), findsNothing);
    },
  );

  testWidgets(
    'mixed profile expiry refresh keeps the comment draft and permits sending',
    (tester) async {
      final events = _EmptyEvents();
      final thoughts = _EmptyThoughts();
      final visibility = VisibilityDetectorController.instance;
      final previousInterval = visibility.updateInterval;
      visibility.updateInterval = Duration.zero;
      await serviceLocator.reset();
      serviceLocator.registerSingleton<EngagementRepository>(engagement);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await serviceLocator.reset();
        visibility.updateInterval = previousInterval;
        events.signal.dispose();
        thoughts.signal.dispose();
      });
      final publishedAt = DateTime.now();
      shares.visibleShare = _share(
        publishedAt,
        lifetime: const Duration(minutes: 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ListenerProfileTheme(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ListenerProfilePostsSection(
                  listenerProfileId: 'profile',
                  username: 'sharer',
                  ownerUserId: 'sharer',
                  eventsRepository: events,
                  overthinkingRepository: thoughts,
                  tableGroupRepository: shares,
                  sessions: sessions,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(_commentsKey));
      await tester.tap(find.byKey(_commentsKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Birlikte güzel bir akşamdı',
      );
      shares.visibleShare = _share(
        publishedAt,
        lifetime: const Duration(minutes: 1),
        status: 'INACTIVE',
        acceptedCount: 3,
      );
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(shares.profileReads, 1);
      expect(shares.lookups, isNotEmpty);
      expect(find.text('Bu masanın süresi doldu'), findsOneWidget);
      expect(find.text('3/4 kişi'), findsOneWidget);
      expect(find.text('Birlikte güzel bir akşamdı'), findsOneWidget);
      expect(find.byType(CommentThreadView), findsOneWidget);
      await tester.tap(find.byTooltip('Yorumu gönder'));
      await tester.pumpAndSettle();
      expect(engagement.created, [
        ('TABLE_GROUP_POST', 'publication', 'Birlikte güzel bir akşamdı'),
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending like survives expiry and canonical source replacement', (
    tester,
  ) async {
    final publishedAt = now;
    final pending = Completer<Result<void>>();
    engagement.onLike = () => pending.future;
    row.value = _share(publishedAt, lifetime: const Duration(seconds: 10));
    await mount(tester, persistEngagement: true);
    await tester.tap(find.byKey(_likeKey));
    await tester.pump();
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    row.value = _share(
      publishedAt,
      status: 'INACTIVE',
      acceptedCount: 3,
      lifetime: const Duration(seconds: 10),
    );
    await tester.pump();
    pending.complete(const Result.success(null));
    await tester.pumpAndSettle();
    expect(savedEngagement, [(4, 7, true)]);
    expect(row.value.tableGroup.status, 'INACTIVE');
    expect(row.value.tableGroup.acceptedCount, 3);
    expect(find.text('Bu masanın süresi doldu'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(_likeKey), matching: find.text('4')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final commentsOpen in [false, true]) {
    testWidgets(
      'expiry behind another route defers source refresh with comments=$commentsOpen',
      (tester) async {
        row.value = _share(now, lifetime: const Duration(seconds: 10));
        var sourceRefreshes = 0;
        await mount(tester, onSourceRefresh: () async => sourceRefreshes++);
        if (commentsOpen) {
          await tester.tap(find.byKey(_commentsKey));
          await tester.pumpAndSettle();
        }
        unawaited(
          navigator.currentState!.push<void>(
            MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Başka sayfa')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        now = now.add(const Duration(seconds: 10));
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(sourceRefreshes, 0);
        expect(refreshes, 0);
        expect(find.text('Başka sayfa'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (status, label) in [
    ('INACTIVE', 'Bu masanın süresi doldu'),
    ('CANCELLED', 'Bu masa kapatıldı'),
  ]) {
    testWidgets('$status retains engagement and owner deletion', (
      tester,
    ) async {
      row.value = _share(
        now,
        status: status,
        acceptedCount: 3,
        note: 'Güzel bir akşamdı',
      );
      await mount(tester);
      expect(find.text(label), findsOneWidget);
      expect(find.text('Güzel bir akşamdı'), findsOneWidget);
      expect(find.text('3/4 kişi'), findsOneWidget);
      expect(find.text('Masayı gör'), findsNothing);
      await tester.tap(find.byKey(_likeKey));
      await tester.pumpAndSettle();
      expect(engagement.calls.where((call) => call.$1 == 'like'), hasLength(1));
      await tester.tap(find.byKey(_commentsKey));
      await tester.pumpAndSettle();
      expect(find.byType(CommentThreadView), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await openDelete(tester);
      await tester.tap(
        find.byKey(const Key('listener-table-group-remove-confirm')),
      );
      await tester.pumpAndSettle();
      expect(shares.deleted, ['publication']);
      expect(removed, ['publication']);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('draft preserves layout at width $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1000),
              textScaler: const TextScaler.linear(1.6),
            ),
            child: ListenerProfileTheme(
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ListenerTableGroupShareCard.draft(
                    tableGroup: row.value.tableGroup,
                    username: 'uzun_kullanici_adi_icin_tasarim_kontrolu',
                    noteEditor: const TextField(maxLines: 3),
                    actions: const Text('Paylaşım akışı'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Taslak · Henüz paylaşılmadı'), findsOneWidget);
      expect(find.text('Masayı gör'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final status in ['ACTIVE', 'INACTIVE', 'CANCELLED']) {
    testWidgets(
      '$status publication keeps long content and actions usable at large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const note =
            'Bu akşam sevdiğimiz şarkıları ve unutamadığımız konserleri '
            'konuşmak için buluşuyoruz. Sohbetimize katıl!';
        const title =
            'Biraz müzik, biraz sohbet; bu akşam aynı masada buluşalım.';
        const venue = 'Kavaklıdere Müzik Atölyesi ve Kültür Buluşmaları';
        var likes = 0;
        var comments = 0;
        var sourceOpens = 0;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: ListenerProfileTheme(
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ListenerTableGroupShareCard(
                    share: _share(
                      now,
                      status: status,
                      note: note,
                      description: title,
                      venueName: venue,
                    ),
                    username: 'uzun_kullanici_adi_icin_tasarim_kontrolu',
                    now: now,
                    likeCount: 12345,
                    commentCount: 3456,
                    onOpen: () => sourceOpens++,
                    onRemove: () {},
                    onLike: () => likes++,
                    onComments: () => comments++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(note), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.text(venue), findsOneWidget);
        if (status == 'ACTIVE') {
          await tester.ensureVisible(find.text('Masayı gör'));
          await tester.tap(find.text('Masayı gör'));
          expect(sourceOpens, 1);
        } else {
          expect(find.text('Masayı gör'), findsNothing);
          expect(
            find.text(
              status == 'INACTIVE'
                  ? 'Bu masanın süresi doldu'
                  : 'Bu masa kapatıldı',
            ),
            findsOneWidget,
          );
        }
        await tester.ensureVisible(find.byKey(_likeKey));
        await tester.tap(find.byKey(_likeKey));
        await tester.ensureVisible(find.byKey(_commentsKey));
        await tester.tap(find.byKey(_commentsKey));
        await tester.pumpAndSettle();
        expect(likes, 1);
        expect(comments, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

TableGroupProfileShare _share(
  DateTime now, {
  String? note,
  String description = 'Müzikten konuşmak için buluşalım.',
  String? venueName,
  Duration lifetime = const Duration(hours: 1),
  String status = 'ACTIVE',
  int acceptedCount = 2,
}) => TableGroupProfileShare(
  shareId: 'publication',
  note: note,
  publishedAt: now,
  tableGroup: TableGroupProfileShareSource(
    id: 'source-table',
    description: description,
    venueName: venueName,
    cityName: 'Ankara',
    districtName: 'Çankaya',
    meetingAt: now.add(const Duration(minutes: 15)),
    expiresAt: now.add(lifetime),
    status: status,
    maxPersonCount: 4,
    acceptedCount: acceptedCount,
  ),
  likeCount: 3,
  commentCount: 7,
  likedByMe: false,
);

class _Shares extends Fake implements TableGroupProfileShareRepository {
  final signal = ValueNotifier(0);
  final deleted = <String>[];
  AuthSession? expectedSession;
  Future<Result<void>> Function()? onDelete;
  TableGroupProfileShare? visibleShare;
  int profileReads = 0;
  final lookups = <Set<String>>[];

  @override
  ValueNotifier<int> get changes => signal;

  @override
  Future<Result<Page<TableGroupProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) async {
    profileReads++;
    return Result.success(
      Page(items: [if (visibleShare case final share?) share], hasNext: false),
    );
  }

  @override
  Future<Result<List<TableGroupProfileShare>>> lookupProfile({
    required String profileId,
    required AuthSession expectedSession,
    required Set<String> shareIds,
  }) async {
    lookups.add(Set.of(shareIds));
    return Result.success([
      if (visibleShare case final share? when shareIds.contains(share.shareId))
        share,
    ]);
  }

  @override
  Future<Result<void>> deleteShare({
    required String shareId,
    required AuthSession expectedSession,
  }) async {
    deleted.add(shareId);
    this.expectedSession = expectedSession;
    return onDelete?.call() ?? const Result.success(null);
  }
}

class _EmptyEvents extends Fake implements EventAudienceRepository {
  final signal = ValueNotifier(0);
  @override
  ValueNotifier<int> get changes => signal;
  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) async => Result.success(
    EventAudiencePage(
      items: const [],
      page: page,
      size: size,
      totalElements: 0,
      totalPages: 0,
      hasNext: false,
    ),
  );
}

class _EmptyThoughts extends Fake
    implements OverthinkingProfileShareRepository {
  final signal = ValueNotifier(0);
  @override
  ValueNotifier<int> get changes => signal;
  @override
  Future<Result<Page<OverthinkingProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) async => Result.success(Page(items: const [], hasNext: false));
}

class _Engagement extends Fake implements EngagementRepository {
  final calls = <(String, String, String)>[];
  Future<Result<void>> Function()? onLike;
  bool liked = false;
  final created = <(String, String, String)>[];

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async {
    created.add((targetType, targetId, text));
    return Result.success(
      CommentItem(
        id: 'comment-${created.length}',
        user: const CommentUserSummary(
          id: 'sharer',
          username: 'sharer',
          avatarUrl: null,
        ),
        text: text,
        deleted: false,
        parentCommentId: parentCommentId,
        replyCount: 0,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) async {
    calls.add(('count', targetType, targetId));
    return Result.success(liked ? 4 : 3);
  }

  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) async {
    calls.add(('liked', targetType, targetId));
    return Result.success(liked);
  }

  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) async {
    calls.add(('like', targetType, targetId));
    final result =
        await (onLike?.call() ??
            Future.value(const Result<void>.success(null)));
    if (result.isSuccess) liked = true;
    return result;
  }

  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) async {
    calls.add(('unlike', targetType, targetId));
    liked = false;
    return const Result.success(null);
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    calls.add(('comments', targetType, targetId));
    return Result.success(
      CommentPage(items: const [], totalElements: 0, page: page, size: size),
    );
  }
}
