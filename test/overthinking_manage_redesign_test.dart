import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_incoming_unread_status.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_reveal_request.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_manage_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_feed_screen.dart';

import 'support/event_audience_fakes.dart';

const _preview = bool.fromEnvironment('OVERTHINKING_PREVIEW');
const _previewKey = ValueKey('overthinking-manage-preview-boundary');

void main() {
  late _ManageRepositoryFake repository;
  late DmBadgeCubit badgeCubit;

  setUp(() async {
    await serviceLocator.reset();
    repository = _ManageRepositoryFake();
    badgeCubit = DmBadgeCubit(_NoopDmRepository(), _EmptyTokenStore());
    serviceLocator
      ..registerSingleton<OverthinkingRepository>(repository)
      ..registerSingleton<DmBadgeCubit>(badgeCubit);
  });

  tearDown(() async {
    await badgeCubit.close();
    await serviceLocator.reset();
  });

  Future<void> open(
    WidgetTester tester, {
    int tab = 0,
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (_preview) await _loadPreviewFonts(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: _preview ? 'Roboto' : null),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: OverthinkingManageScreen(initialTabIndex: tab),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final entry in ['direct', 'tap', 'swipe']) {
    testWidgets('$entry incoming tab marks seen without deciding the request', (
      tester,
    ) async {
      await open(tester, tab: entry == 'direct' ? 1 : 0);
      if (entry != 'direct') {
        expect(repository.seenCalls, 0);
        if (entry == 'tap') {
          await tester.tap(find.text('Gelen istekler'));
        } else {
          await tester.drag(find.byType(TabBarView), const Offset(-390, 0));
        }
        await tester.pumpAndSettle();
      }
      expect(repository.seenCalls, 1);
      expect(repository.approveCalls, 0);
      expect(find.text('Kabul et'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('old incoming tab callbacks cannot mark the new account seen', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(audienceSession(user: 'first'));
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    addTearDown(sessions.dispose);
    await open(tester);
    final oldTab = tester.widget<TabBar>(find.byType(TabBar));
    sessions.replace(audienceSession(user: 'second'));
    // A tab callback or swipe completion can arrive before the old frame leaves.
    oldTab.onTap!(1);
    oldTab.controller!.index = 1;
    await tester.pumpAndSettle();
    expect(repository.seenCalls, 0);
    expect(find.textContaining('Oturum değişti.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed first load offers retry instead of an empty state', (
    tester,
  ) async {
    repository.failPosts = true;
    await open(tester);
    expect(find.text('Şu an yükleyemedik.'), findsOneWidget);
    expect(find.text('İlk satır seni bekliyor.'), findsNothing);
    repository.failPosts = false;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(repository.postPages, [0, 0]);
    expect(find.text('Geceye bir not'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'request actions remain reachable on narrow screen with large text',
    (tester) async {
      await open(tester, tab: 1, width: 320, scale: 1.6);
      await tester.scrollUntilVisible(
        find.text('Kabul et'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Kabul et'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'next page remains reachable and repeated boundary item is deduplicated',
    (tester) async {
      repository.morePosts = true;
      await open(tester);
      await _capture(tester, 'manage-390x844');
      await tester.ensureVisible(find.text('Daha fazla göster'));
      await tester.tap(find.text('Daha fazla göster'));
      await tester.pumpAndSettle();
      expect(repository.postPages, [0, 1]);
      expect(find.byKey(const ValueKey('manage-post-post-1')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('İkinci düşünce'),
        220,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('İkinci düşünce'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'request decision ignores a second tap and stale refresh response',
    (tester) async {
      await open(tester, tab: 1);
      await _capture(tester, 'manage-incoming-390x844');
      repository.incomingRefresh =
          Completer<Result<Page<OverthinkingRevealRequest>>>();
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator).first,
      );
      final refreshFuture = refresh.onRefresh();
      await tester.pump();
      repository.approval = Completer<Result<OverthinkingRevealRequest>>();
      final approve = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Kabul et'),
      );
      approve.onPressed!();
      approve.onPressed!();
      await tester.pump();
      expect(repository.approveCalls, 1);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Reddet'),
            )
            .onPressed,
        isNull,
      );
      repository.approval!.complete(Result.success(_request('APPROVED')));
      await tester.pump();
      repository.incomingRefresh!.complete(
        Result.success(Page(items: [_request('PENDING')], hasNext: false)),
      );
      await refreshFuture;
      await tester.pumpAndSettle();
      expect(find.text('Kabul edildi'), findsOneWidget);
      expect(find.text('Kabul et'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long writing opens in a bounded scrollable preview', (
    tester,
  ) async {
    repository.detail = _post.copyWith(
      content: List.filled(
        160,
        'Bazen bir şarkının içinde kendimi buluyorum.',
      ).join('\n'),
    );
    await open(tester);
    await tester.tap(find.text('Geceye bir not'));
    await tester.pumpAndSettle();
    await _capture(tester, 'manage-preview-390x844');
    expect(
      find.byKey(const ValueKey('manage-post-preview-scroll')),
      findsOneWidget,
    );
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('manage-post-preview-scroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed detail does not show an outdated preview', (
    tester,
  ) async {
    repository.failDetail = true;
    await open(tester);
    await tester.tap(find.text('Geceye bir not'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('manage-post-preview-scroll')),
      findsNothing,
    );
    expect(find.text('Yazı artık bulunamıyor.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('my posts use the feed card with delete and no editing', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(OverthinkingPostCard), findsOneWidget);
    expect(find.byTooltip('Yazıyı düzenle'), findsNothing);
    expect(find.textContaining('Anonim olarak paylaştın'), findsOneWidget);
    expect(find.textContaining('Kimliği sana açık'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byTooltip('Yazıyı sil'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Beğen'));
    expect(find.text('8 beğeni'), findsOneWidget);
    expect(find.text('3 yorum'), findsOneWidget);
    expect(find.text('Bir Derdim Var'), findsOneWidget);
    expect(repository.updateCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending like blocks overlapping post actions and keeps the shared card current',
    (tester) async {
      final engagement = _ManageEngagement();
      serviceLocator.registerSingleton<EngagementRepository>(engagement);
      repository.morePosts = true;
      await open(tester);
      final otherCard = tester.widget<OverthinkingPostCard>(
        find.byKey(const ValueKey('manage-post-post-1')),
      );
      await tester.ensureVisible(find.text('Daha fazla göster'));
      await tester.tap(find.text('Daha fazla göster'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('İkinci düşünce'),
        220,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final second = find.byKey(const ValueKey('manage-post-post-2'));
      final card = tester.widget<OverthinkingPostCard>(second);
      card.onLike();
      card.onLike();
      card.onDelete!();
      otherCard.onDelete!();
      await tester.pump();
      expect(engagement.likeCalls, 1);
      expect(repository.deleteCalls, 0);
      expect(find.text('Bu yazıyı sil?'), findsNothing);
      expect(tester.widget<OverthinkingPostCard>(second).busy, isTrue);
      engagement.pending.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(tester.widget<OverthinkingPostCard>(second).busy, isFalse);
      expect(
        tester.widget<OverthinkingPostCard>(second).post.likedByMe,
        isTrue,
      );
      expect(tester.widget<OverthinkingPostCard>(second).post.likeCount, 9);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('delete requires confirmation and cannot send twice', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byTooltip('Yazıyı sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 0);
    expect(find.byType(OverthinkingPostCard), findsOneWidget);
    await tester.tap(find.byTooltip('Yazıyı sil'));
    await tester.pumpAndSettle();
    repository.deletion = Completer<Result<void>>();
    await tester.tap(find.widgetWithText(FilledButton, 'Yazıyı sil'));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 1);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('overthinking-delete-post-1')),
          )
          .onPressed,
      isNull,
    );
    repository.deletion!.complete(const Result.success(null));
    await tester.pumpAndSettle();
    expect(find.byType(OverthinkingPostCard), findsNothing);
    expect(find.text('Yazın silindi.'), findsOneWidget);
    expect(repository.updateCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed delete keeps the card and allows another attempt', (
    tester,
  ) async {
    repository.deletion = Completer<Result<void>>();
    await open(tester);
    await tester.tap(find.byTooltip('Yazıyı sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Yazıyı sil'));
    await tester.pumpAndSettle();
    repository.deletion!.complete(
      const Result.failure(
        AppError(code: 'offline', message: 'Silme başarısız.'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OverthinkingPostCard), findsOneWidget);
    expect(find.text('Silme başarısız.'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('overthinking-delete-post-1')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}

const _post = OverthinkingPost(
  id: 'post-1',
  authorId: 'author-1',
  authorUsername: 'kalem',
  authorAvatarUrl: null,
  anonymous: true,
  canViewAuthor: true,
  visibilityType: 'ANONYMOUS',
  title: 'Geceye bir not',
  content: 'Bir şarkı, söyleyemediklerimi biliyor.',
  spotifyTrackUrl: 'https://open.spotify.com/track/demo',
  spotifyArtistId: null,
  spotifyTrackName: 'Bir Derdim Var',
  spotifyArtistName: 'mor ve ötesi',
  spotifyAlbumImageUrl: null,
  musicianTrackId: null,
  bandTrackId: null,
  artistId: null,
  artistType: null,
  likeCount: 8,
  commentCount: 3,
  likedByMe: false,
);

OverthinkingRevealRequest _request(String status) => OverthinkingRevealRequest(
  id: 'request-1',
  postId: 'post-1',
  postTitle: 'Geceye bir not',
  requesterId: 'listener-1',
  requesterUsername: 'dinleyen',
  authorId: 'author-1',
  status: status,
  createdAt: null,
);

class _ManageRepositoryFake implements OverthinkingRepository {
  int seenCalls = 0;

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>>
  getIncomingUnreadStatus() async => Result.success(
    OverthinkingIncomingUnreadStatus(hasUnread: seenCalls == 0, revision: 3),
  );

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>> markIncomingRequestsSeen({
    required int revision,
  }) async {
    seenCalls++;
    return getIncomingUnreadStatus();
  }

  bool failPosts = false;
  bool morePosts = false;
  bool failDetail = false;
  int approveCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  bool deleted = false;
  Completer<Result<void>>? deletion;
  final List<int> postPages = [];
  OverthinkingPost detail = _post;
  Completer<Result<OverthinkingRevealRequest>>? approval;
  Completer<Result<Page<OverthinkingRevealRequest>>>? incomingRefresh;

  @override
  Future<Result<Page<OverthinkingPost>>> getMyPosts({
    int page = 0,
    int size = 20,
  }) async {
    postPages.add(page);
    if (failPosts) {
      return const Result.failure(
        AppError(code: 'NETWORK', message: 'Bağlantı kurulamadı.'),
      );
    }
    return Result.success(
      Page(
        items: deleted
            ? []
            : page == 0
            ? [_post]
            : [_post, _post.copyWith(id: 'post-2', title: 'İkinci düşünce')],
        hasNext: morePosts && page == 0,
      ),
    );
  }

  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getIncomingRevealRequests({
    int page = 0,
    int size = 20,
  }) async =>
      incomingRefresh?.future ??
      Result.success(Page(items: [_request('PENDING')], hasNext: false));

  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getSentRevealRequests({
    int page = 0,
    int size = 20,
  }) async => const Result.success(Page(items: [], hasNext: false));

  @override
  Future<Result<OverthinkingRevealRequest>> approveRevealRequest({
    required String requestId,
  }) async {
    approveCalls++;
    return approval?.future ?? Result.success(_request('APPROVED'));
  }

  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) async =>
      failDetail
      ? const Result.failure(
          AppError(code: 'NOT_FOUND', message: 'Yazı artık bulunamıyor.'),
        )
      : Result.success(detail);

  @override
  Future<Result<void>> deletePost({required String postId}) async {
    deleteCalls++;
    final result =
        await (deletion?.future ??
            Future.value(const Result<void>.success(null)));
    if (result.isSuccess) deleted = true;
    return result;
  }

  @override
  Future<Result<OverthinkingPost>> updatePost({
    required String postId,
    required String title,
    required String content,
    required String visibilityType,
    String? spotifyTrackUrl,
    String? spotifyArtistId,
    String? spotifyTrackName,
    String? spotifyArtistName,
    String? spotifyAlbumImageUrl,
    String? musicianTrackId,
    String? bandTrackId,
  }) async {
    updateCalls++;
    return Result.success(_post.copyWith(title: title, content: content));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(invocation.memberName.toString());
}

class _ManageEngagement extends Fake implements EngagementRepository {
  final pending = Completer<Result<void>>();
  int likeCalls = 0;
  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) {
    likeCalls++;
    return pending.future;
  }
}

class _EmptyTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> readToken() async => null;
  @override
  Future<void> writeToken(String token) async {}
}

class _NoopDmRepository implements DmRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(invocation.memberName.toString());
}

Future<void> _loadPreviewFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final fonts =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    final loader = FontLoader('Roboto');
    for (final name in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
      'roboto-black.ttf',
    ]) {
      loader.addFont(
        File('$fonts/$name').readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
    await (FontLoader('Ahem')..addFont(
          File(
            '$fonts/roboto-regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
          'packages/${FontAwesomeIcons.spotify.fontPackage}/${FontAwesomeIcons.spotify.fontFamily}',
        )..addFont(
          rootBundle.load(
            'packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf',
          ),
        ))
        .load();
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_preview) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('test/goldens/overthinking/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
