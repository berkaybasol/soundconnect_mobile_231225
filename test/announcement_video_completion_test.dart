import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/media_access.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/media_gallery_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/video_reel_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/domain/entities/announcement.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/presentation/screens/announcement_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/presentation/screens/announcement_editor_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/announcement_fixtures.dart';
import 'support/event_audience_fakes.dart';

void main() {
  setUp(() async => GetIt.instance.reset());
  tearDown(() async => GetIt.instance.reset());

  for (final looping in [true, false]) {
    testWidgets('shared reel passes looping=$looping and gates callbacks', (
      tester,
    ) async {
      _mockNativeTransport(tester);
      var starts = 0;
      var completions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: VideoReelScreen(
            title: 'Video',
            playbackUrl: 'https://video.example.test/fixture.mp4',
            thumbnailUrl: null,
            targetType: 'ANNOUNCEMENT',
            targetId: announcementFixtureId,
            initialLikeCount: null,
            initialCommentCount: null,
            showEngagement: false,
            looping: looping,
            onPlaybackStarted: () => starts++,
            onPlaybackCompleted: () => completions++,
          ),
        ),
      );
      await tester.pump();
      final controller = tester
          .widget<BetterPlayer>(find.byType(BetterPlayer))
          .controller;
      expect(controller.betterPlayerConfiguration.looping, looping);
      final emit = controller.betterPlayerConfiguration.eventListener!;
      emit(BetterPlayerEvent(BetterPlayerEventType.finished));
      emit(
        BetterPlayerEvent(
          BetterPlayerEventType.progress,
          parameters: {'progress': const Duration(seconds: 1)},
        ),
      );
      expect(starts, 0, reason: 'A paused position is not playback.');
      expect(completions, 0, reason: 'Completion needs an actual start.');
      final video = controller.videoPlayerController!;
      video.value = video.value.copyWith(isPlaying: true);
      for (var repeat = 0; repeat < 2; repeat++) {
        emit(
          BetterPlayerEvent(
            BetterPlayerEventType.progress,
            parameters: {'progress': const Duration(seconds: 1)},
          ),
        );
        emit(BetterPlayerEvent(BetterPlayerEventType.finished));
      }
      expect(starts, 1);
      expect(completions, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  test('legacy reels retain their default loop behavior', () {
    const reel = VideoReelScreen(
      title: 'Legacy reel',
      playbackUrl: 'https://video.example.test/fixture.mp4',
      thumbnailUrl: null,
      targetType: 'MEDIA_ASSET',
      targetId: announcementFixtureAssetId,
      initialLikeCount: null,
      initialCommentCount: null,
    );
    expect(reel.looping, isTrue);
  });

  for (final admin in [false, true]) {
    testWidgets(
      admin
          ? 'admin announcement preview reaches end and has no analytics hooks'
          : 'announcement detail configures terminal playback with analytics hooks',
      (tester) async {
        _mockNativeTransport(tester);
        final sessions = AudienceTestSessions(
          admin ? announcementAdminSession() : audienceSession(),
        );
        GetIt.instance.registerSingleton<AuthSessionManager>(
          sessions,
          dispose: (value) => value.dispose(),
        );
        GetIt.instance.registerSingleton<MediaGalleryRepository>(_Media());
        GetIt.instance.registerSingleton<ProfileMediaUploadRepository>(
          _Uploads(),
        );
        GetIt.instance.registerSingleton<ApiClient>(_Api());
        final repository = AnnouncementTestRepository()
          ..current = Announcement.fromJson({
            ...announcementFixture(status: admin ? 'DRAFT' : 'PUBLISHED'),
            'media': {
              'assetId': announcementFixtureAssetId,
              'kind': 'VIDEO',
              'status': 'READY',
              'streamingProtocol': 'PROGRESSIVE',
              'width': 1152,
              'height': 720,
              'durationSeconds': 2,
            },
          });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.navy,
            home: admin
                ? AnnouncementEditorScreen(
                    id: announcementFixtureId,
                    repository: repository,
                    sessions: sessions,
                  )
                : AnnouncementDetailScreen(
                    id: announcementFixtureId,
                    repository: repository,
                    sessions: sessions,
                  ),
          ),
        );
        await tester.pumpAndSettle();
        final play = find.byTooltip('Duyuru videosunu oynat');
        await tester.scrollUntilVisible(
          play,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(play), alignment: 0.5);
        await tester.pump();
        expect(play.hitTestable(), findsOneWidget);
        await tester.tap(play.hitTestable());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final reel = tester.widget<VideoReelScreen>(
          find.byType(VideoReelScreen),
        );
        expect(reel.looping, isFalse);
        expect(reel.showEngagement, !admin);
        expect(reel.onPlaybackStarted, admin ? isNull : isNotNull);
        expect(reel.onPlaybackCompleted, admin ? isNull : isNotNull);
        final controller = tester
            .widget<BetterPlayer>(find.byType(BetterPlayer))
            .controller;
        expect(controller.betterPlayerConfiguration.looping, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

// Widget tests inspect the production route/controller wiring. They deliberately
// do not pretend that this method-channel stub decodes any media; the isolated
// physical-device harness provides the separate real native playback evidence.
void _mockNativeTransport(WidgetTester tester) {
  const channel = MethodChannel('better_player_channel');
  const events = MethodChannel('better_player_channel/videoEvents1');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async => call.method == 'create' ? {'textureId': 1} : null,
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    events,
    (_) async => null,
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      events,
      null,
    );
  });
}

class _Media extends Fake implements MediaGalleryRepository {
  @override
  Future<Result<MediaAccess>> getAccess(String assetId) async => Result.success(
    MediaAccess(
      assetId: assetId,
      accessUrl: 'https://video.example.test/fixture.mp4',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      streamingProtocol: 'PROGRESSIVE',
    ),
  );
}

class _Uploads extends Fake implements ProfileMediaUploadRepository {
  @override
  void releaseDraftCleanupLeases(Iterable<String> assetIds) {}
}

class _Api extends Fake implements ApiClient {
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async => throw StateError('No backend transport in this widget fixture.');
}
