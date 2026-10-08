// Real-device render benchmark. Run with flutter drive --profile; never import
// this entry point from lib/main.dart or ship it as an application feature.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/network/network_config.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/presentation/widgets/analytics_exposure.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/cubit/musician_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/screens/musician_feed_view.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_chrome.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/populated_musician_feed.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // fullyLive schedules actual display frames while gestures/futures run.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'populated musician feed profile performance',
    (tester) async {
      const fixtureBaseUrl = 'https://feed-profile.invalid';
      const configuredBaseUrl = String.fromEnvironment('SOUNDCONNECT_BASE_URL');
      binding.reportData = {
        'preflight': {
          'passed': false,
          'required_mode': 'profile',
          'required_base_url_define':
              '--dart-define=SOUNDCONNECT_BASE_URL=$fixtureBaseUrl',
        },
      };
      if (!kProfileMode) {
        throw StateError(
          'Run this benchmark with --profile. Debug and release '
          'cannot provide the required comparable VM/frame measurements.',
        );
      }
      if (configuredBaseUrl != fixtureBaseUrl) {
        throw StateError(
          'The isolated feed benchmark requires '
          '--dart-define=SOUNDCONNECT_BASE_URL=$fixtureBaseUrl. '
          'Use the reserved fixture endpoint, not a real API endpoint.',
        );
      }
      // Exercise the real profile/release configuration validator before any
      // widgets, caches or fixture sockets are initialized.
      expect(NetworkConfig.baseUrl, fixtureBaseUrl);
      final images = await BenchmarkImages.start();
      final repository = PopulatedFeedRepository(images);
      final cubit = MusicianFeedCubit(
        repository,
        BenchmarkEngagement(),
        collabRepository: BenchmarkCollab(),
        followRepository: BenchmarkFollow(),
        bandFollowRepository: BenchmarkBandFollow(),
        sessions: BenchmarkSessions(),
      );
      // BaseAudioHandler supplies production preview streams without initializing
      // AudioService, changing Android audio focus, or creating notifications.
      serviceLocator.registerSingleton<AudioHandler>(BaseAudioHandler());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await cubit.close();
        await serviceLocator.unregister<AudioHandler>();
        await images.close();
      });

      final view = tester.view;
      final hz = view.display.refreshRate > 0 ? view.display.refreshRate : 60.0;
      final budgetMs = 1000 / hz;
      final evidence = _Evidence();
      binding.reportData = <String, dynamic>{
        'preflight': {'passed': true, 'fixture_base_url': fixtureBaseUrl},
        'scenario': {
          'version': 1,
          'mode': 'profile',
          'production_widgets':
              'MusicianFeedView / MusicianFeedCubit / '
              'MusicianFeedCardRegistry.standard / AppTheme.navy',
          'physical_size':
              '${view.physicalSize.width}x${view.physicalSize.height}',
          'device_pixel_ratio': view.devicePixelRatio,
          'refresh_rate_hz': hz,
          'frame_budget_ms': budgetMs,
          'fixture_item_capacity': PopulatedFeedRepository.totalItems,
          'page_size': cubit.pageSize,
          'repository_latency_ms': 120,
          'event_poster_mode': PopulatedFeedRepository.mixedEventPosters
              ? 'mixed_uploaded_and_default_poster'
              : 'all_uploaded_baseline',
          'cycles': 3,
          'drags_per_cycle': 40,
          'limitations': [
            'Synthetic domain data and controlled repository latency; no backend capacity inference.',
            'Existing bundled 1500x450 poster and logo fixtures; real download/cache/decode/render pipeline.',
            'Test-only HTTPS fixture URLs route to device loopback; no CDN, TLS, mobile network latency.',
            'Idle BaseAudioHandler; no audio/video decoding, playback, or background service measurement.',
            'RSS includes Flutter engine, image cache, integration driver and tracing; not Dart heap alone.',
            'A bounded three-cycle RSS observation cannot establish absence of long-session leaks.',
          ],
        },
        'cycles': <Map<String, dynamic>>[],
      };

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.navy,
          navigatorObservers: [analyticsRouteObserver],
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Backstage · Performans kontrolü'),
            ),
            body: BlocProvider.value(
              value: cubit,
              child: const MusicianFeedView(),
            ),
          ),
        ),
      );
      await cubit.initialize();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      final list = find.byKey(const PageStorageKey('musician-feed-list'));
      expect(list, findsOneWidget);
      final controller = tester.widget<ListView>(list).controller!;
      final stopwatch = Stopwatch()..start();
      for (var attempt = 0; attempt < 20; attempt++) {
        evidence.observe(tester, controller);
        if (images.requests > 0 && evidence.maxDecodedImages > 0) break;
        await tester.pump(const Duration(milliseconds: 200));
      }
      binding.reportData!['coverage'] = evidence.toJson(repository, images);
      expect(
        images.requests,
        greaterThan(0),
        reason: 'Fixture transport must succeed before measuring frames.',
      );
      expect(
        evidence.maxDecodedImages,
        greaterThan(0),
        reason: 'Real decoded image pixels must be present before measuring.',
      );
      expect(evidence.imageErrors, 0);

      // Touch every family and warm the renderer without calling this cold pass
      // evidence of steady-state frame quality. Fixture URLs stay constant across
      // refresh so repeated cycles have comparable cache/data work.
      for (var index = 0; index < 8; index++) {
        await _drag(tester, list, index < 4 ? -1 : 1);
        evidence.observe(tester, controller);
      }
      await _returnToTop(tester, controller);
      await tester.pump(const Duration(seconds: 1));
      binding.reportData!['after_warmup_memory'] = _memory();
      final cycleResults =
          binding.reportData!['cycles'] as List<Map<String, dynamic>>;

      // The timeline is returned even when quality gates fail, through the custom
      // driver. Measure display timings separately to avoid driver-summary guesses.
      await binding.traceAction(
        () async {
          for (var cycle = 0; cycle < 3; cycle++) {
            final timings = <FrameTiming>[];
            void watcher(List<FrameTiming> frames) => timings.addAll(frames);
            // Flush the engine's prior timing batch before starting this interval.
            await tester.pump(const Duration(seconds: 1));
            binding.addTimingsCallback(watcher);
            final cycleWatch = Stopwatch()..start();
            try {
              for (var step = 0; step < 40; step++) {
                await _drag(tester, list, step < 20 ? -1 : 1);
                evidence.observe(tester, controller);
              }
              await _returnToTop(tester, controller);
              final previousRefreshes = repository.loadCursors
                  .where((c) => c == null)
                  .length;
              // Exercise the real RefreshIndicator gesture and Cubit refresh path.
              await tester.timedDrag(
                list,
                const Offset(0, 360),
                const Duration(milliseconds: 650),
              );
              await tester.pump(const Duration(seconds: 1));
              expect(
                repository.loadCursors.where((c) => c == null).length,
                previousRefreshes + 1,
              );
              expect(cubit.state.items.length, cubit.pageSize);
              evidence.observe(tester, controller);
              await tester.pump(const Duration(seconds: 1));
            } finally {
              binding.removeTimingsCallback(watcher);
              cycleWatch.stop();
              cycleResults.add({
                'cycle': cycle + 1,
                'elapsed_ms': cycleWatch.elapsedMilliseconds,
                'frames': _summarize(timings, budgetMs),
                'memory_after_refresh': _memory(),
                'repository_loads_so_far': repository.loadCursors.length,
                'fixture_http_requests_so_far': images.requests,
                'maximum_scroll_offset_so_far': evidence.maximumScrollOffset,
              });
              binding.reportData!['coverage'] = evidence.toJson(
                repository,
                images,
              );
              binding.reportData!['elapsed_ms'] = stopwatch.elapsedMilliseconds;
            }
          }
        },
        streams: ['Dart', 'Embedder', 'GC'],
        reportKey: 'timeline',
      );

      // Save all diagnostics before assertions. Never allow empty/fallback-only
      // cards, idle-only frames, or a failure to page to produce a passing report.
      expect(tester.takeException(), isNull);
      expect(images.blockedRequests, 0);
      expect(images.requests, greaterThan(10));
      expect(evidence.maxDecodedImages, greaterThanOrEqualTo(2));
      expect(evidence.imageErrors, 0);
      expect(evidence.cardFamilies.length, 7);
      if (PopulatedFeedRepository.mixedEventPosters) {
        expect(evidence.sawUploadedEventPoster, isTrue);
        expect(evidence.sawDefaultEventPoster, isTrue);
      }
      expect(evidence.maximumScrollOffset, greaterThan(4000));
      expect(repository.deliveredItemIds.length, greaterThanOrEqualTo(40));
      expect(
        repository.loadCursors.where((cursor) => cursor == null).length,
        4,
      );
      expect(
        repository.loadCursors.where((cursor) => cursor != null).length,
        greaterThanOrEqualTo(3),
      );
      for (final cycle in cycleResults) {
        final frames = cycle['frames'] as Map<String, dynamic>;
        expect(frames['frame_count'], greaterThan(300));
        // Cycle 1 retains first-visit image/shader work and is reported separately.
        if (cycle['cycle'] == 1) continue;
        expect(
          frames['build_p95_ms'],
          lessThanOrEqualTo(budgetMs),
          reason: 'Warmed UI build p95 exceeds the physical display budget.',
        );
        expect(
          frames['raster_p95_ms'],
          lessThanOrEqualTo(budgetMs),
          reason: 'Warmed raster p95 exceeds the physical display budget.',
        );
        expect(frames['build_slow_ratio'], lessThanOrEqualTo(.05));
        expect(frames['raster_slow_ratio'], lessThanOrEqualTo(.05));
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _drag(WidgetTester tester, Finder list, int direction) async {
  final size = tester.getSize(list);
  await tester.timedDrag(
    list,
    Offset(0, direction * size.height * .72),
    const Duration(milliseconds: 450),
  );
  await tester.pump(const Duration(milliseconds: 180));
}

Future<void> _returnToTop(
  WidgetTester tester,
  ScrollController controller,
) async {
  if (controller.offset > 1) {
    await controller.animateTo(
      0,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
    );
  }
  await tester.pump(const Duration(milliseconds: 250));
}

Map<String, dynamic> _memory() {
  final cache = PaintingBinding.instance.imageCache;
  return {
    'process_rss_bytes': ProcessInfo.currentRss,
    'process_max_rss_bytes': ProcessInfo.maxRss,
    'image_cache_bytes': cache.currentSizeBytes,
    'image_cache_limit_bytes': cache.maximumSizeBytes,
    'image_cache_entries': cache.currentSize,
    'live_images': cache.liveImageCount,
    'pending_images': cache.pendingImageCount,
  };
}

Map<String, dynamic> _summarize(List<FrameTiming> frames, double budgetMs) {
  final build =
      frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList()..sort();
  final raster =
      frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()
        ..sort();
  final total = frames.map((f) => f.totalSpan.inMicroseconds / 1000).toList()
    ..sort();
  double percentile(List<double> values, double fraction) => values.isEmpty
      ? 0
      : values[(values.length * fraction).ceil().clamp(1, values.length) - 1];
  int slow(List<double> values) =>
      values.where((value) => value > budgetMs).length;
  return {
    'frame_count': frames.length,
    'build_p50_ms': percentile(build, .50),
    'build_p95_ms': percentile(build, .95),
    'build_p99_ms': percentile(build, .99),
    'build_max_ms': build.isEmpty ? 0 : build.last,
    'raster_p50_ms': percentile(raster, .50),
    'raster_p95_ms': percentile(raster, .95),
    'raster_p99_ms': percentile(raster, .99),
    'raster_max_ms': raster.isEmpty ? 0 : raster.last,
    'total_span_p95_ms': percentile(total, .95),
    'build_slow_count': slow(build),
    'raster_slow_count': slow(raster),
    'build_slow_ratio': frames.isEmpty ? 1 : slow(build) / frames.length,
    'raster_slow_ratio': frames.isEmpty ? 1 : slow(raster) / frames.length,
    'any_stage_slow_count': frames
        .where(
          (f) =>
              f.buildDuration.inMicroseconds / 1000 > budgetMs ||
              f.rasterDuration.inMicroseconds / 1000 > budgetMs,
        )
        .length,
  };
}

class _Evidence {
  final cardFamilies = <String>{};
  bool sawUploadedEventPoster = false;
  bool sawDefaultEventPoster = false;
  int maxDecodedImages = 0;
  int imageErrors = 0;
  double maximumScrollOffset = 0;

  void observe(WidgetTester tester, ScrollController controller) {
    for (final surface in tester.widgetList<MusicianFeedSurface>(
      find.byType(MusicianFeedSurface),
    )) {
      if (surface.item.payload case EventFeedPayload payload) {
        if (payload.event['posterImageUrl'] == null) {
          sawDefaultEventPoster = true;
        } else {
          sawUploadedEventPoster = true;
        }
      }
    }
    cardFamilies.addAll(
      tester
          .widgetList<MusicianFeedSurface>(find.byType(MusicianFeedSurface))
          .map((surface) => surface.item.type.apiValue),
    );
    maxDecodedImages = math.max(
      maxDecodedImages,
      tester
          .widgetList<RawImage>(find.byType(RawImage))
          .where((image) => image.image != null)
          .length,
    );
    imageErrors += find
        .byKey(const ValueKey('app_cached_network_image.error'))
        .evaluate()
        .where(
          (element) =>
              element
                  .findAncestorWidgetOfExactType<AppCachedNetworkImage>()
                  ?.imageUrl
                  ?.trim()
                  .isNotEmpty ==
              true,
        )
        .length;
    maximumScrollOffset = math.max(maximumScrollOffset, controller.offset);
  }

  Map<String, dynamic> toJson(
    PopulatedFeedRepository repository,
    BenchmarkImages images,
  ) => {
    'rendered_card_families': cardFamilies.toList()..sort(),
    'observed_uploaded_event_poster': sawUploadedEventPoster,
    'observed_default_event_poster': sawDefaultEventPoster,
    'max_simultaneously_decoded_images': maxDecodedImages,
    'observed_image_error_widgets': imageErrors,
    'maximum_scroll_offset': maximumScrollOffset,
    'distinct_items_delivered': repository.deliveredItemIds.length,
    'repository_load_count': repository.loadCursors.length,
    'pagination_load_count': repository.loadCursors
        .where((c) => c != null)
        .length,
    'refresh_including_initial_load_count': repository.loadCursors
        .where((c) => c == null)
        .length,
    'local_impressions': repository.impressionCount,
    'image_http_request_count': images.requests,
    'image_bytes_served': images.servedBytes,
    'blocked_external_requests': images.blockedRequests,
  };
}
