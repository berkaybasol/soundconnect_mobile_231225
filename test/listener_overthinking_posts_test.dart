import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_profile_link.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_owner_content.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_public_profile_content.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_overthinking_posts.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_overthinking_share_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/ghost_profile_badge.dart';

import 'support/event_audience_fakes.dart';

const _preview = bool.fromEnvironment('OVERTHINKING_PREVIEW');
const _captureKey = Key('listener-overthinking-preview');
const _overlayCaptureKey = Key('listener-overthinking-overlay-preview');

void main() {
  late _Shares repository;
  late AudienceTestSessions sessions;
  setUp(() {
    repository = _Shares();
    sessions = AudienceTestSessions(audienceSession(user: 'sharer'));
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
  });
  tearDown(() async {
    repository.signal.dispose();
    await serviceLocator.reset();
  });

  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    bool owner = false,
    bool visible = true,
    Future<void> Function(String)? onOpen,
    ValueNotifier<bool>? visibility,
    ValueNotifier<int>? refresh,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (_preview) await _loadFonts(tester);
    Widget section(bool value) => ListenerOverthinkingPostsSection(
      listenerProfileId: 'listener-profile',
      username: 'deniz',
      ownerUserId: owner ? 'sharer' : null,
      profileContentVisible: value,
      repository: repository,
      sessions: sessions,
      onOpenSource: onOpen,
      refreshSignal: refresh,
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: _overlayCaptureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _preview ? ThemeData(fontFamily: 'Roboto') : null,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ListenerProfileTheme(
            child: RepaintBoundary(
              key: _captureKey,
              child: Scaffold(
                body: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Paylaşımlar',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (visibility == null)
                        section(visible)
                      else
                        ValueListenableBuilder<bool>(
                          valueListenable: visibility,
                          builder: (_, value, _) => section(value),
                        ),
                    ],
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

  for (final size in [(390.0, 1.0), (320.0, 1.6)]) {
    testWidgets(
      'real quote preserves sharer and anonymous-source separation at ${size.$1}/${size.$2}',
      (tester) async {
        repository.items = [_share()];
        await mount(tester, width: size.$1, scale: size.$2, owner: true);
        await tester.pumpAndSettle();
        expect(find.text('@deniz'), findsOneWidget);
        expect(find.text('Anonim yazar'), findsOneWidget);
        expect(find.textContaining('private-author'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is AppCachedNetworkImage &&
                widget.imageUrl?.contains('private-avatar') == true,
          ),
          findsNothing,
        );
        expect(
          find.text('Bu satır bana dün geceyi hatırlattı.'),
          findsOneWidget,
        );
        expect(find.text('Bir şarkının içinde'), findsOneWidget);
        expect(find.text('Gece Yolculuğu'), findsOneWidget);
        expect(find.byType(GhostProfileBadge), findsNothing);
        final quote = find.byKey(
          const Key('listener-overthinking-source-quote'),
        );
        expect(
          find.descendant(of: quote, matching: find.text('Devamını gör…')),
          findsOneWidget,
        );
        expect(find.text('Yazıyı aç'), findsNothing);
        expect(tester.takeException(), isNull);
        if (_preview) {
          await _capture(
            tester,
            size.$1 == 390
                ? 'listener-profile-share'
                : 'listener-profile-share-small',
          );
          await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Paylaşımı sil'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('listener-share-delete-dialog')),
            findsOneWidget,
          );
          expect(repository.deleted, isEmpty);
          expect(tester.takeException(), isNull);
          await _capture(
            tester,
            size.$1 == 390
                ? 'share-delete-dialog390'
                : 'share-delete-dialog320',
            key: _overlayCaptureKey,
          );
          await tester.tap(find.text('Vazgeç'));
          await tester.pumpAndSettle();
          expect(repository.deleted, isEmpty);
        }
      },
    );
  }

  testWidgets(
    'large source counters remain readable at 320 and enlarged text',
    (tester) async {
      repository.items = [_share(likes: 2147483647, comments: 999999999)];
      await mount(tester, width: 320, scale: 1.6);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Devamını gör…'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Beğen' &&
              widget.properties.value == '2147483647 beğeni',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Yorumlar' &&
              widget.properties.value == '999999999 yorum',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'visible ghost source has its own identity and badge; public visitor cannot remove',
    (tester) async {
      repository.items = [_share(visible: true, ghost: true, note: null)];
      await mount(tester);
      await tester.pumpAndSettle();
      expect(find.text('@deniz'), findsOneWidget);
      expect(find.text('@contextual-ghost'), findsOneWidget);
      expect(find.byType(GhostProfileBadge), findsOneWidget);
      expect(find.byTooltip('Paylaşım seçenekleri'), findsNothing);
      expect(find.text('Bu satır bana dün geceyi hatırlattı.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'first-page failure retries; pagination deduplicates shared IDs',
    (tester) async {
      repository.failure = true;
      await mount(tester);
      await tester.pumpAndSettle();
      expect(find.text('Paylaşımlar yüklenemedi.'), findsOneWidget);
      repository.failure = false;
      repository.items = [_share()];
      repository.next = [_share(), _share(id: 'second', title: 'İkinci yazı')];
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('listener-overthinking-more')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('listener-overthinking-more')));
      await tester.pumpAndSettle();
      expect(repository.pages, [0, 0, 1]);
      expect(find.byType(ListenerOverthinkingShareCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'repository changes and profile refresh replace the list; empty section collapses',
    (tester) async {
      final refresh = ValueNotifier(0);
      addTearDown(refresh.dispose);
      await mount(tester, refresh: refresh);
      await tester.pumpAndSettle();
      expect(find.text('Henüz burada paylaşılan bir yazı yok.'), findsNothing);
      repository.items = [_share()];
      repository.signal.value++;
      await tester.pumpAndSettle();
      expect(find.byType(ListenerOverthinkingShareCard), findsOneWidget);
      repository.items = [];
      refresh.value++;
      await tester.pumpAndSettle();
      expect(find.byType(ListenerOverthinkingShareCard), findsNothing);
      expect(repository.pages, [0, 0, 0]);
    },
  );

  for (final code in ['401', '403', '404']) {
    testWidgets('pagination access failure $code removes cached quotes', (
      tester,
    ) async {
      repository.items = [_share()];
      repository.next = [_share(id: 'next')];
      await mount(tester);
      await tester.pumpAndSettle();
      repository.failure = true;
      repository.failureCode = code;
      await tester.scrollUntilVisible(
        find.byKey(const Key('listener-overthinking-more')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('listener-overthinking-more')));
      await tester.pumpAndSettle();
      expect(find.byType(ListenerOverthinkingShareCard), findsNothing);
    });
  }

  for (final owner in [true, false]) {
    testWidgets(
      'production ${owner ? 'owner' : 'public'} listener content renders real shares',
      (tester) async {
        repository.items = [_share()];
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (_preview) await _loadFonts(tester);
        final section = ListenerOverthinkingPostsSection(
          listenerProfileId: 'listener-profile',
          username: 'deniz',
          ownerUserId: owner ? 'sharer' : null,
          repository: repository,
          sessions: sessions,
        );
        final content = owner
            ? ListenerProfileOwnerContent(
                profile: const ListenerProfile(
                  id: 'listener-profile',
                  userId: 'sharer',
                  username: 'deniz',
                  bio: 'Biraz müzik, biraz düşünce.',
                  profilePictureUrl: null,
                  followerCount: 42,
                  followingCount: 18,
                ),
                onEditProfile: () {},
                onEditAvatar: () {},
                onEditPlaylists: () {},
                onPlaylistTap: (_) {},
                onPreviewAction: (_) {},
                overthinkingPosts: section,
              )
            : ListenerPublicProfileContent(
                profile: const ListenerPublicProfile(
                  id: 'listener-profile',
                  userId: 'sharer',
                  username: 'deniz',
                  visibilityMode: ListenerVisibilityMode.standard,
                  bio: 'Biraz müzik, biraz düşünce.',
                  profilePictureMediaId: null,
                  profilePictureUrl: null,
                  followerCount: 42,
                  followingCount: 18,
                  restricted: false,
                  canFollow: true,
                  canMessage: true,
                ),
                isFollowing: false,
                followBusy: false,
                onRefresh: () async {},
                onPlaylistTap: (_) {},
                overthinkingPosts: section,
              );
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _preview ? ThemeData(fontFamily: 'Roboto') : null,
            home: ListenerProfileTheme(
              child: RepaintBoundary(
                key: _captureKey,
                child: Scaffold(body: SafeArea(child: content)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(ListenerOverthinkingPostsSection),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(ListenerOverthinkingShareCard), findsOneWidget);
        expect(find.text('Bir şarkının içinde'), findsOneWidget);
        expect(find.textContaining('ilk on saniyesi'), findsNothing);
        expect(tester.takeException(), isNull);
        if (_preview) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -230),
          );
          await tester.pumpAndSettle();
          await _capture(
            tester,
            owner ? 'listener-owner-real-share' : 'listener-public-real-share',
          );
        }
      },
    );
  }

  testWidgets(
    'owner session changes drop pending rows; guest and restricted profiles do not fetch',
    (tester) async {
      final pending = Completer<Result<Page<OverthinkingProfileShare>>>();
      repository.pending = pending;
      await mount(tester, owner: true);
      expect(repository.pages, [0]);
      sessions.replace(audienceSession(user: 'other'));
      await tester.pump();
      pending.complete(Result.success(Page(items: [_share()], hasNext: false)));
      await tester.pumpAndSettle();
      expect(find.byType(ListenerOverthinkingShareCard), findsNothing);
      expect(repository.pages, [0]);
      sessions.replace(const AuthSession.guest());
      await tester.pumpAndSettle();
      expect(repository.pages, [0]);
    },
  );

  testWidgets(
    'ghost visibility transition clears quotes and closes pending removal confirmation',
    (tester) async {
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      repository.items = [_share()];
      await mount(tester, owner: true, visibility: visible);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paylaşımı sil'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('listener-overthinking-remove-confirm')),
        findsOneWidget,
      );
      visible.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(ListenerOverthinkingShareCard), findsNothing);
      expect(
        find.byKey(const Key('listener-overthinking-remove-confirm')),
        findsNothing,
      );
      expect(repository.deleted, isEmpty);
    },
  );

  testWidgets(
    'removal addresses the exact share and cannot erase a later repost of the source',
    (tester) async {
      repository.items = [_share(id: 'old-share')];
      await mount(tester, owner: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
      await tester.pumpAndSettle();
      expect(find.text('Paylaşımı sil'), findsOneWidget);
      expect(
        find.byKey(const Key('listener-overthinking-remove-confirm')),
        findsNothing,
      );
      expect(repository.deleted, isEmpty);
      await tester.tap(find.text('Paylaşımı sil'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('listener-overthinking-remove-confirm')),
        findsOneWidget,
      );
      expect(repository.deleted, isEmpty);
      repository.onDelete = () async {
        repository.items = [
          _share(id: 'new-share', note: 'Yeni paylaşım notu'),
        ];
        return const Result.failure(
          AppError(code: '9415', message: 'Eski paylaşım bulunamadı.'),
        );
      };
      await tester.tap(
        find.byKey(const Key('listener-overthinking-remove-confirm')),
      );
      await tester.pumpAndSettle();
      expect(repository.deleted, ['old-share']);
      expect(find.text('Yeni paylaşım notu'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('listener-overthinking-share-new-share')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inline excerpt link is keyboard accessible and exposes link semantics',
    (tester) async {
      repository.items = [_share()];
      final opened = <String>[];
      await mount(tester, onOpen: (id) async => opened.add(id));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Devamını gör…'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.ancestor(
          of: find.text('Devamını gör…'),
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.link == true,
          ),
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(opened, ['source-post']);
    },
  );

  testWidgets(
    'draft reuses the quote without a fabricated publication or author identity',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ListenerProfileTheme(
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ListenerOverthinkingShareCard.draft(
                  post: _share(visible: true, ghost: true).post,
                  username: 'deniz',
                  noteEditor: const TextField(
                    decoration: InputDecoration(hintText: 'Bir not ekle'),
                  ),
                  actions: TextButton(
                    onPressed: () {},
                    child: const Text('Paylaş'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('@deniz'), findsOneWidget);
      expect(find.text('Taslak · Henüz paylaşılmadı'), findsOneWidget);
      expect(find.textContaining('Bir overthinking paylaştı'), findsNothing);
      expect(find.text('Anonim yazar'), findsOneWidget);
      expect(find.text('@contextual-ghost'), findsNothing);
      expect(find.byType(GhostProfileBadge), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Paylaş'), findsOneWidget);
      expect(find.text('Devamını gör…'), findsNothing);
      expect(find.text('24'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'visible draft source author cannot navigate around the draft leave guard',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenerOverthinkingShareCard.draft(
                post: _share(
                  visible: true,
                ).post.copyWith(anonymous: false, visibilityType: 'PUBLIC'),
                username: 'deniz',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('@contextual-ghost'), findsOneWidget);
      final author = tester.widget<OverthinkingProfileLink>(
        find.byType(OverthinkingProfileLink),
      );
      expect(author.enabled, isFalse);
      expect(find.byType(TextButton), findsNothing);
      await tester.tap(find.text('@contextual-ghost'));
      await tester.pumpAndSettle();
      expect(find.byType(ListenerOverthinkingShareCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inline excerpt link opens original post ID and refreshes source counters on return',
    (tester) async {
      repository.items = [_share(id: 'share-different-from-source')];
      final opened = <String>[];
      await mount(
        tester,
        onOpen: (postId) async {
          opened.add(postId);
          repository.items = [
            _share(id: 'share-different-from-source', title: 'Güncel kaynak'),
          ];
        },
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Devamını gör…'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Devamını gör…'));
      await tester.pumpAndSettle();
      expect(opened, ['source-post']);
      expect(repository.pages, [0, 0]);
      expect(find.text('Güncel kaynak'), findsOneWidget);
    },
  );
}

OverthinkingProfileShare _share({
  String id = 'share',
  String title = 'Bir şarkının içinde',
  String? note = 'Bu satır bana dün geceyi hatırlattı.',
  bool visible = false,
  bool ghost = false,
  int likes = 24,
  int comments = 6,
}) => OverthinkingProfileShare(
  shareId: id,
  note: note,
  publishedAt: DateTime.utc(2026, 9, 10, 18),
  likeCount: likes,
  commentCount: comments,
  post: OverthinkingPostModel.fromJson({
    'id': 'source-post',
    'title': title,
    'content':
        'Bazı şarkılar bir yere götürmez. Olduğun yerde biraz daha kalmana, düşüncelerinin sesini duymana izin verir.',
    'authorId': visible ? 'ghost-author' : 'private-author',
    'authorUsername': visible ? 'contextual-ghost' : 'private-author',
    'authorAvatarUrl': visible
        ? null
        : 'https://example.test/private-avatar.jpg',
    'authorVisibilityMode': ghost
        ? ListenerVisibilityMode.ghost.name.toUpperCase()
        : 'STANDARD',
    'canViewAuthor': visible,
    'anonymous': true,
    'visibilityType': 'ANONYMOUS',
    'spotifyTrackName': 'Gece Yolculuğu',
    'spotifyArtistName': 'Kıyı',
    'spotifyTrackUrl': 'https://open.spotify.com/track/track',
    'likeCount': likes,
    'commentCount': comments,
  }),
);

class _Shares extends Fake implements OverthinkingProfileShareRepository {
  final signal = ValueNotifier(0);
  @override
  ValueListenable<int> get changes => signal;
  List<OverthinkingProfileShare> items = [];
  List<OverthinkingProfileShare> next = [];
  final pages = <int>[];
  final deleted = <String>[];
  bool failure = false;
  String failureCode = 'NETWORK';
  Completer<Result<Page<OverthinkingProfileShare>>>? pending;
  Future<Result<void>> Function()? onDelete;
  @override
  Future<Result<Page<OverthinkingProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) async {
    pages.add(page);
    if (pending != null) return pending!.future;
    if (failure) {
      return Result.failure(
        AppError(code: failureCode, message: 'Paylaşımlar yüklenemedi.'),
      );
    }
    return Result.success(
      Page(
        items: page == 0 ? items : next,
        hasNext: page == 0 && next.isNotEmpty,
      ),
    );
  }

  @override
  Future<Result<void>> deleteShare({
    required String shareId,
    required AuthSession expectedSession,
  }) async {
    deleted.add(shareId);
    return onDelete?.call() ?? const Result.success(null);
  }
}

Future<void> _loadFonts(WidgetTester tester) async => tester.runAsync(() async {
  final directory =
      '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final weight in ['regular', 'medium', 'bold', 'black']) {
    roboto.addFont(
      File(
        '$directory/roboto-$weight.ttf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  }
  await roboto.load();
  final loader = FontLoader('Ahem')
    ..addFont(
      File(
        '$directory/roboto-regular.ttf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  await loader.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
});

Future<void> _capture(
  WidgetTester tester,
  String name, {
  Key key = _captureKey,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('test/goldens/overthinking/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
