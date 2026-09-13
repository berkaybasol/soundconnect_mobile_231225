import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/cubit/musician_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/screens/musician_feed_view.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/media_gallery_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/media_gallery_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/domain/promotion_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/presentation/screens/announcement_directory_screen.dart';
import 'package:soundconnect_23_12_25codx/preview/data/preview_scenario_store.dart';
import 'package:soundconnect_23_12_25codx/preview/domain/preview_feed_scenario.dart';
import 'package:soundconnect_23_12_25codx/preview/presentation/feed_preview_screen.dart';
import 'package:soundconnect_23_12_25codx/preview/runtime/preview_http.dart';
import 'package:soundconnect_23_12_25codx/preview/runtime/preview_session.dart';
import 'package:soundconnect_23_12_25codx/preview/services/preview_service_bundle.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  late PreviewServiceBundle services;
  late HttpOverrides? previousHttp;
  late HttpClient Function()? previousImageClientProvider;
  late PreviewHttpOverrides fixtureHttp;
  late HttpClient fixtureImageClient;

  setUp(() async {
    await GetIt.instance.reset();
    final sessions = await createPreviewSession();
    services = PreviewServiceBundle(
      store: PreviewScenarioStore(),
      sessions: sessions,
    );
    GetIt.instance
      ..registerSingleton<AuthSessionManager>(sessions)
      ..registerSingleton<ApiClient>(services.api)
      ..registerSingleton<EngagementRepository>(services.engagement)
      ..registerSingleton<PromotionRepository>(services.promotions)
      ..registerSingleton<AudioHandler>(_PreviewTestAudioHandler())
      ..registerSingleton<MediaGalleryRepository>(
        MediaGalleryRepositoryImpl(services.api, sessions: sessions),
      );
    // Use the preview's real bundled artwork and its no-socket image adapter.
    final directory = Directory('android/app/src/preview/assets/preview');
    final names =
        (jsonDecode(File('${directory.path}/manifest.json').readAsStringSync())
                as List)
            .cast<String>();
    previousHttp = HttpOverrides.current;
    fixtureHttp = PreviewHttpOverrides({
      for (final name in names)
        name: File('${directory.path}/$name').readAsBytesSync(),
    });
    HttpOverrides.global = fixtureHttp;
    // Flutter's widget-test zone replaces HttpClient even when a global
    // override exists. Bind the real preview adapter to NetworkImage's test
    // seam so private announcement images decode the bundled fixture bytes.
    previousImageClientProvider = debugNetworkImageHttpClientProvider;
    fixtureImageClient = fixtureHttp.createHttpClient(null);
    debugNetworkImageHttpClientProvider = () => fixtureImageClient;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() async {
    debugNetworkImageHttpClientProvider = previousImageClientProvider;
    fixtureImageClient.close(force: true);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    HttpOverrides.global = previousHttp;
    services.sessions.dispose();
    services.store.dispose();
    await GetIt.instance.reset();
  });

  test(
    'RAM API rejects unknown routes and external URLs without fallback',
    () async {
      for (final path in [
        'https://example.com/api/v1/likes/MEDIA/id',
        '/api/v1/admin/users',
        '/api/v1/likes/MEDIA/id/extra/route',
      ]) {
        await expectLater(
          services.api.get<Object?>(path),
          throwsA(isA<ApiException>()),
        );
      }
      expect(services.api.rejectedPaths, hasLength(3));
      expect(services.sessions.session.userId, previewViewerUserId);
    },
  );

  test(
    'real repositories round-trip local announcement engagement and hidden directory',
    () async {
      final item = services.store.scenarioById('announcement-text')!.item;
      final target = item.engagement!;
      expect(
        (await services.engagement.like(
          targetType: target.targetType,
          targetId: target.targetId,
        )).isSuccess,
        isTrue,
      );
      expect(
        (await services.engagement.getLikeCount(
          targetType: target.targetType,
          targetId: target.targetId,
        )).data,
        target.likeCount + 1,
      );
      final comment = await services.engagement.createComment(
        targetType: target.targetType,
        targetId: target.targetId,
        text: 'Bu yorum yalnızca önizlemede.',
      );
      expect(comment.isSuccess, isTrue);
      expect(comment.data!.user.id, previewViewerUserId);
      final reply = await services.engagement.createComment(
        targetType: target.targetType,
        targetId: target.targetId,
        text: 'Örnek yanıt',
        parentCommentId: comment.data!.id,
      );
      expect(reply.isSuccess, isTrue);
      final replies = await services.engagement.listReplies(comment.data!.id);
      expect(replies.data!.single.id, reply.data!.id);
      expect(
        (await services.engagement.setCommentLike(
          commentId: reply.data!.id,
          liked: true,
        )).data!.likedByMe,
        isTrue,
      );
      await services.engagement.deleteComment(commentId: reply.data!.id);
      expect(services.store.commentById(reply.data!.id)!.deleted, isTrue);
      services.store.hide(item.id);
      final directory = await services.promotions.announcements();
      expect(directory.isSuccess, isTrue);
      expect(directory.data!.items, hasLength(3));
      expect(
        directory.data!.items
            .singleWhere((row) => row.id == target.targetId)
            .feedHidden,
        isTrue,
      );
      services.store.reset();
      expect(services.store.itemById(item.id)!.engagement!.likedByMe, isFalse);
      expect(services.store.isHidden(item.id), isFalse);
    },
  );

  test(
    'production feed Cubit paginates the full fixed preview without duplicates',
    () async {
      final cubit = services.createFeedCubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state.items, hasLength(20));
      for (var page = 0; page < 6 && cubit.state.hasMore; page++) {
        await cubit.loadMore();
      }
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.loadMoreError, isNull);
      expect(cubit.state.items.length, services.store.visibleMixedFeed.length);
      expect(
        cubit.state.items.map((item) => item.id).toSet().length,
        cubit.state.items.length,
      );
      expect(
        cubit.state.items.map((item) => item.type).toSet(),
        containsAll(MusicianFeedItemType.values),
      );
      expect(services.feed.pagesLoaded, greaterThan(1));
    },
  );

  test(
    'real collab repository saves and removes the same local listing',
    () async {
      final item = services.store.scenarioById('collab-regular')!.item;
      final id = (item.payload as CollabFeedPayload).listing['id'] as String;
      expect((await services.collab.saveListing(id)).isSuccess, isTrue);
      expect((await services.collab.getListing(id)).data!.savedByMe, isTrue);
      expect((await services.collab.unsaveListing(id)).isSuccess, isTrue);
      expect((await services.collab.getListing(id)).data!.savedByMe, isFalse);
    },
  );

  test(
    'viewer likes and newest comments remain consistent after reload and delete',
    () async {
      final target = services.store
          .scenarioById('track-zero-count')!
          .item
          .engagement!;
      final repository = services.engagement;
      await repository.like(
        targetType: target.targetType,
        targetId: target.targetId,
      );
      final users = await repository.listLikeUsers(
        targetType: target.targetType,
        targetId: target.targetId,
      );
      expect(users.data!.items.single.id, previewViewerUserId);
      await repository.unlike(
        targetType: target.targetType,
        targetId: target.targetId,
      );
      expect(
        (await repository.listLikeUsers(
          targetType: target.targetType,
          targetId: target.targetId,
        )).data!.items,
        isEmpty,
      );
      final comment = await repository.createComment(
        targetType: target.targetType,
        targetId: target.targetId,
        text: 'Yeni kök yorum',
      );
      final next = await repository.createComment(
        targetType: target.targetType,
        targetId: target.targetId,
        text: 'En yeni yorum',
      );
      final page = await repository.listComments(
        targetType: target.targetType,
        targetId: target.targetId,
      );
      expect(page.data!.items.map((row) => row.id), [
        next.data!.id,
        comment.data!.id,
      ]);
      await repository.deleteComment(commentId: next.data!.id);
      final afterDelete = await repository.listComments(
        targetType: target.targetType,
        targetId: target.targetId,
      );
      expect(afterDelete.data!.totalElements, 1);
      expect(afterDelete.data!.items.single.id, comment.data!.id);
    },
  );

  test(
    'catalogue hide is honored by an already opened feed continuation',
    () async {
      final first = await services.feed.load(limit: 20);
      final hidden = services.store.visibleMixedFeed[25].item;
      services.store.hide(hidden.id);
      final continuation = await services.feed.load(
        limit: 20,
        cursor: first.data!.nextCursor,
      );
      expect(continuation.isSuccess, isTrue);
      expect(
        continuation.data!.items.any((row) => row.id == hidden.id),
        isFalse,
      );
      expect(continuation.data!.hasMore, isTrue);
    },
  );

  test(
    'private announcement media access resolves only known fixture assets',
    () async {
      final item = services.store.scenarioById('announcement-video')!.item;
      final media =
          (item.payload as AnnouncementFeedPayload).announcement.media!;
      final repository = GetIt.instance<MediaGalleryRepository>();
      final access = await repository.getAccess(media.assetId);
      expect(access.isSuccess, isTrue);
      expect(access.data!.accessUrl, '$previewMediaBaseUrl/video.mp4');
      expect(
        access.data!.thumbnailAccessUrl,
        '$previewMediaBaseUrl/announcement-video.png',
      );
      expect(
        (await repository.getAccess(previewUuid('unknown-media'))).isSuccess,
        isFalse,
      );
    },
  );

  testWidgets(
    'actual feed and catalogue support stable-ID search, like and reset',
    (tester) async {
      try {
        await tester.pumpWidget(_previewApp(services));
        await tester.pumpAndSettle();
        expect(find.byType(MusicianFeedView), findsOneWidget);
        await tester.tap(find.text('Kart kataloğu'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('preview-catalogue-search')),
          'track-zero-count',
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('preview-scenario-track-zero-count')),
          findsOneWidget,
        );
        final like = find.text('Beğen');
        await Scrollable.ensureVisible(tester.element(like), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(like.hitTestable());
        await tester.pumpAndSettle();
        expect(
          services.store
              .scenarioById('track-zero-count')!
              .item
              .engagement!
              .likedByMe,
          isTrue,
        );
        expect(find.text('Beğendin'), findsOneWidget);
        await tester.tap(find.byTooltip('Önizlemeyi sıfırla'));
        await tester.pumpAndSettle();
        expect(
          services.store
              .scenarioById('track-zero-count')!
              .item
              .engagement!
              .likeCount,
          0,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        await _finishFixtureWidgetTest(tester, previousImageClientProvider);
      }
    },
  );

  testWidgets('announcement hide stays inspectable in the catalogue', (
    tester,
  ) async {
    try {
      await tester.pumpWidget(_previewApp(services));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kart kataloğu'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('preview-catalogue-search')),
        'announcement-text',
      );
      await tester.pumpAndSettle();
      final hide = find.byTooltip('Bu duyuruyu akışta bir daha gösterme');
      await Scrollable.ensureVisible(tester.element(hide), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(hide.hitTestable());
      await tester.pumpAndSettle();
      expect(services.store.isHidden('announcement-text'), isTrue);
      expect(find.text('Akışta gizli · katalogda görünür'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('preview-scenario-announcement-text')),
        findsOneWidget,
      );
      final directory = find.text('Tüm duyurular');
      await Scrollable.ensureVisible(tester.element(directory), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(directory.hitTestable());
      await _decodeDirectoryImages(tester, fixtureHttp);
      expect(find.byType(AnnouncementDirectoryScreen), findsOneWidget);
      expect(
        (await services.promotions.announcements()).data!.items,
        hasLength(3),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    } finally {
      await _finishFixtureWidgetTest(tester, previousImageClientProvider);
    }
  });

  testWidgets(
    'card directory route refreshes loaded feed engagement on return',
    (tester) async {
      try {
        await tester.pumpWidget(_previewApp(services));
        await tester.pumpAndSettle();
        final cubit = tester
            .element(find.byType(MusicianFeedView))
            .read<MusicianFeedCubit>();
        final item = services.store.scenarioById('announcement-text')!.item;
        final directory = find.text('Tüm duyurular');
        await tester.scrollUntilVisible(
          directory,
          250,
          scrollable: find
              .descendant(
                of: find.byType(MusicianFeedView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await Scrollable.ensureVisible(
          tester.element(directory),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(directory.hitTestable());
        await _decodeDirectoryImages(tester, fixtureHttp);
        expect(find.byType(AnnouncementDirectoryScreen), findsOneWidget);
        await services.engagement.like(
          targetType: item.engagement!.targetType,
          targetId: item.engagement!.targetId,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          cubit.state.items
              .singleWhere((row) => row.id == item.id)
              .engagement!
              .likedByMe,
          isTrue,
        );
        expect(
          cubit.state.items
              .singleWhere((row) => row.id == item.id)
              .engagement!
              .likeCount,
          item.engagement!.likeCount + 1,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        await _finishFixtureWidgetTest(tester, previousImageClientProvider);
      }
    },
  );
}

class _PreviewTestAudioHandler extends BaseAudioHandler {}

Future<void> _finishFixtureWidgetTest(
  WidgetTester tester,
  HttpClient Function()? previousProvider,
) async {
  // Flutter verifies painting globals before package:test's tearDown runs.
  // Dispose media widgets and their capability timers inside the test body,
  // then restore the provider even if an assertion or disposal fails.
  try {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  } finally {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugNetworkImageHttpClientProvider = previousProvider;
  }
}

Future<void> _decodeDirectoryImages(
  WidgetTester tester,
  PreviewHttpOverrides fixtureHttp,
) async {
  // Finish the route transition and the RAM access-url response without
  // waiting for an indeterminate image-loading spinner to stop by itself.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  final directory = find.byType(AnnouncementDirectoryScreen);
  expect(directory, findsOneWidget);
  final privateImages = find.descendant(
    of: directory,
    matching: find.byWidgetPredicate(
      (widget) => widget is AppCachedNetworkImage && !widget.persistentCache,
    ),
  );
  expect(privateImages, findsAtLeastNWidgets(1));
  final providers = find.descendant(
    of: privateImages,
    matching: find.byType(Image),
  );
  expect(providers, findsAtLeastNWidgets(1));
  Object? decodeError;
  for (final element in providers.evaluate().toList()) {
    final provider = (element.widget as Image).image;
    await tester.runAsync(() async {
      await precacheImage(
        provider,
        element,
        onError: (error, _) => decodeError = error,
      ).timeout(const Duration(seconds: 10));
    });
  }
  await tester.pump();
  expect(decodeError, isNull);
  expect(fixtureHttp.servedImages, greaterThan(0));
  expect(fixtureHttp.rejectedRequests, 0);
  final pixels = tester.widgetList<RawImage>(
    find.descendant(of: privateImages, matching: find.byType(RawImage)),
  );
  expect(pixels, isNotEmpty);
  for (final image in pixels) {
    expect(image.image, isNotNull);
    expect(image.image!.width, greaterThan(0));
    expect(image.image!.height, greaterThan(0));
  }
  expect(
    find.descendant(
      of: privateImages,
      matching: find.byKey(const ValueKey('app_cached_network_image.error')),
    ),
    findsNothing,
  );
  expect(tester.takeException(), isNull);
}

Widget _previewApp(PreviewServiceBundle services) => MaterialApp(
  theme: AppTheme.navy,
  home: FeedPreviewScreen(services: services),
  routes: {
    AppRoutes.announcements: (_) => AnnouncementDirectoryScreen(
      repository: services.promotions,
      sessions: services.sessions,
    ),
  },
);
