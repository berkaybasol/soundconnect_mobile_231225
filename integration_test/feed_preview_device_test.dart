import 'dart:convert';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/screens/musician_feed_view.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_chrome.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/video_reel_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/presentation/screens/announcement_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/presentation/screens/announcement_directory_screen.dart';
import 'package:soundconnect_23_12_25codx/preview/runtime/preview_bootstrap.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'isolated preview uses real cards, local interactions and native media',
    (tester) async {
      final checks = <String, bool>{};
      final report = <String, dynamic>{'checks': checks, 'passed': false};
      binding.reportData = report;
      addTearDown(
        () => debugPrint(
          'PREVIEW_REPORT ${jsonEncode({...report, 'screenshots': null})}',
        ),
      );
      final runtime = await tester.runAsync(() => launchPreview(qa: true));
      expect(runtime, isNotNull);
      final app = runtime!;
      report['isolation'] = app.isolation.map(
        (key, value) => MapEntry('$key', value),
      );
      report['catalogueCount'] = app.services.store.catalogue.length;
      report['mixedCount'] = app.services.store.mixedFeed.length;
      checks['separate_native_package'] = true;
      checks['minimal_native_plugins'] =
          !(app.isolation['registeredPluginNames'] as List).contains(
            'audio_service',
          );
      Future<void> waitFor(bool Function() condition, String reason) async {
        for (var i = 0; i < 100 && !condition(); i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(condition(), isTrue, reason: reason);
        expect(tester.takeException(), isNull);
      }

      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
      }

      await waitFor(
        () => find.byType(MusicianFeedView).evaluate().isNotEmpty,
        'Populated production feed opens',
      );
      await settle();
      checks['production_feed_loaded'] = find
          .byType(MusicianFeedSurface)
          .evaluate()
          .isNotEmpty;
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot('01-filled-feed');
      await tester.tap(find.text('Kart kataloğu'));
      await settle();
      Future<void> select(String id) async {
        report['currentScenario'] = id;
        expect(app.services.store.scenarioById(id), isNotNull);
        final searchFinder = find.byKey(
          const ValueKey('preview-catalogue-search'),
        );
        // Tap to restore focus: WidgetTester.showKeyboard caches the same
        // EditableText even after this test unfocuses it between selections.
        // Calling enterText alone then sends input to a closed connection.
        await tester.tap(searchFinder);
        await settle();
        await tester.enterText(searchFinder, id);
        await settle();
        FocusManager.instance.primaryFocus?.unfocus();
        await settle();
        final search = tester.widget<TextField>(
          find.byKey(const ValueKey('preview-catalogue-search')),
        );
        if (find.byKey(ValueKey('preview-scenario-$id')).evaluate().isEmpty) {
          report['selectionFailure'] = {
            'requested': id,
            'searchText': search.controller?.text,
            'visibleText': tester
                .widgetList<Text>(find.byType(Text))
                .map((widget) => widget.data)
                .whereType<String>()
                .toList(),
          };
          await binding.takeScreenshot('failure-$id');
        }
        expect(find.byKey(ValueKey('preview-scenario-$id')), findsOneWidget);
      }

      Future<void> tapVisible(Finder target) async {
        await tester.ensureVisible(target);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(target);
        await settle();
      }

      await select('announcement-text');
      final textItem = app.services.store
          .scenarioById('announcement-text')!
          .item;
      await tapVisible(find.text('Beğen'));
      expect(
        app.services.store.itemById(textItem.id)!.engagement!.likedByMe,
        isTrue,
      );
      checks['like_updates_memory'] = true;
      await tapVisible(find.text('Yorum'));
      final composer = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Yorum yaz...',
      );
      await tester.enterText(composer, 'Önizlemedeki yerel yorumum.');
      await tester.pump();
      await tapVisible(find.byTooltip('Yorumu gönder'));
      expect(
        app.services.store
            .commentsFor(textItem.id)
            .any((comment) => comment.text == 'Önizlemedeki yerel yorumum.'),
        isTrue,
      );
      checks['real_comment_sheet_local_write'] = true;
      await binding.takeScreenshot('02-comments');
      Navigator.of(tester.element(composer)).pop();
      await settle();
      await tapVisible(find.byTooltip('Bu duyuruyu akışta bir daha gösterme'));
      expect(app.services.store.isHidden(textItem.id), isTrue);
      checks['hide_local_only'] = true;
      await tapVisible(find.text('Tüm duyurular'));
      expect(find.byType(AnnouncementDirectoryScreen), findsOneWidget);
      await settle();
      expect(
        (await app.services.promotions.announcements()).data?.items.length,
        3,
      );
      checks['real_directory_includes_hidden'] = true;
      await binding.takeScreenshot('03-directory');
      await tester.pageBack();
      await settle();
      await select('announcement-video');
      await tapVisible(find.text('Duyuruyu aç'));
      expect(find.byType(AnnouncementDetailScreen), findsOneWidget);
      await tapVisible(find.byTooltip('Duyuru videosunu oynat'));
      await waitFor(
        () => find.byType(BetterPlayer).evaluate().isNotEmpty,
        'Production VideoReelScreen opens its native player',
      );
      expect(find.byType(VideoReelScreen), findsOneWidget);
      final controller = tester
          .widget<BetterPlayer>(find.byType(BetterPlayer))
          .controller;
      await waitFor(
        () =>
            (controller.videoPlayerController?.value.position.inMilliseconds ??
                0) >
            400,
        'Bundled video actually decodes and advances',
      );
      expect(
        controller.betterPlayerDataSource?.type,
        BetterPlayerDataSourceType.memory,
      );
      checks['production_video_native_playback'] = true;
      report['videoPositionMs'] =
          controller.videoPlayerController!.value.position.inMilliseconds;
      await binding.takeScreenshot('04-video');
      await tester.tap(find.byIcon(Icons.arrow_back).hitTestable().first);
      await settle();
      expect(find.byType(VideoReelScreen), findsNothing);
      expect(find.byType(AnnouncementDetailScreen), findsOneWidget);
      await tester.pageBack();
      await settle();
      expect(find.byType(AnnouncementDetailScreen), findsNothing);
      await select('track-normal');
      var audioPosition = Duration.zero;
      final audioPositions = app.audio.positionStream.listen((value) {
        audioPosition = value;
      });
      await tapVisible(find.byTooltip('Çal').first);
      await waitFor(
        () =>
            app.audio.playbackState.value.playing &&
            audioPosition.inMilliseconds > 200,
        'Bundled audio actually plays through the shared handler',
      );
      checks['production_audio_local_file'] = true;
      report['audioPositionMs'] = audioPosition.inMilliseconds;
      await audioPositions.cancel();
      await app.audio.pause();
      for (final id in [
        'event-poster',
        'event-fallback-solo',
        'event-fallback-band',
        'announcement-image',
        'media-portrait',
        'sponsor-image',
      ]) {
        await select(id);
        await binding.takeScreenshot('05-$id');
      }
      checks['poster_and_default_variants'] = true;
      for (final scenario in app.services.store.catalogue) {
        await select(scenario.id);
        final images = tester
            .widgetList<AppCachedNetworkImage>(
              find.byType(AppCachedNetworkImage),
            )
            .toList();
        for (final image in images) {
          final url = image.imageUrl;
          if (url == null ||
              url.isEmpty ||
              url.endsWith('/missing.png') ||
              url.endsWith('/loading.png')) {
            continue;
          }
          final pixels = find.descendant(
            of: find.byWidget(image),
            matching: find.byWidgetPredicate(
              (widget) => widget is RawImage && widget.image != null,
            ),
          );
          await waitFor(
            () => pixels.evaluate().isNotEmpty,
            '${scenario.id}: bundled image decoded: $url',
          );
        }
      }
      checks['all_catalogue_variants_render'] = true;
      expect(app.http.servedImages, greaterThan(0));
      expect(app.http.rejectedRequests, 0);
      expect(app.services.api.rejectedPaths, isEmpty);
      checks['only_bundled_images_and_allowlisted_repositories'] = true;
      report['servedImages'] = app.http.servedImages;
      await tester.tap(find.byTooltip('Önizlemeyi sıfırla'));
      await settle();
      expect(app.services.store.hiddenItemIds, isEmpty);
      expect(
        app.services.store.itemById(textItem.id)!.engagement!.likedByMe,
        isFalse,
      );
      checks['reset_restores_baseline'] = true;
      await tester.tap(find.text('Dolu akış'));
      await settle();
      report['passed'] = checks.values.every((value) => value);
      expect(report['passed'], isTrue);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
