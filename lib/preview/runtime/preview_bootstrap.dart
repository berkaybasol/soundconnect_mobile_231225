import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../app/router/app_routes.dart';
import '../../core/audio/audio_player_handler.dart';
import '../../core/auth/auth_session_manager.dart';
import '../../core/di/service_locator.dart';
import '../../core/network/api_client.dart';
import '../../modules/engagement/domain/engagement_repository.dart';
import '../../modules/engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../modules/profile/data/media_gallery_repository_impl.dart';
import '../../modules/profile/domain/media_gallery_repository.dart';
import '../../modules/promotion/domain/promotion_repository.dart';
import '../../modules/promotion/presentation/screens/announcement_directory_screen.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/app_theme_controller.dart';
import '../data/preview_scenario_store.dart';
import '../presentation/feed_preview_screen.dart';
import '../services/preview_service_bundle.dart';
import 'preview_http.dart';
import 'preview_isolation.dart';
import 'preview_media.dart';
import 'preview_session.dart';

class PreviewRuntime {
  PreviewRuntime({
    required this.isolation,
    required this.services,
    required this.media,
    required this.http,
    required this.audio,
  });
  final Map<Object?, Object?> isolation;
  final PreviewServiceBundle services;
  final PreviewMediaLibrary media;
  final PreviewHttpOverrides http;
  final AudioPlayerHandler audio;
}

/// A separate entrypoint and Android package. Never calls main.dart,
/// setupDependencies, AudioService.init, deep links or realtime bootstraps.
Future<PreviewRuntime> launchPreview({bool qa = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final isolation = await verifyPreviewIsolation(qa: qa);
  await AppThemeController.instance.initialize();
  if (serviceLocator.isRegistered<ApiClient>() ||
      serviceLocator.isRegistered<AuthSessionManager>()) {
    throw StateError(
      'Önizleme yalnızca kendi boş uygulama alanında açılabilir.',
    );
  }
  final media = await PreviewMediaLibrary.load();
  final http = PreviewHttpOverrides(media.images);
  HttpOverrides.global = http;
  final sessions = await createPreviewSession();
  final services = PreviewServiceBundle(
    store: PreviewScenarioStore(),
    sessions: sessions,
  );
  final audio = AudioPlayerHandler(audioSourceFactory: media.audioSource);
  serviceLocator
    ..registerSingleton<AuthSessionManager>(sessions)
    ..registerSingleton<ApiClient>(services.api)
    ..registerSingleton<EngagementRepository>(services.engagement)
    ..registerSingleton<PromotionRepository>(services.promotions)
    ..registerSingleton<MediaGalleryRepository>(
      MediaGalleryRepositoryImpl(services.api, sessions: sessions),
    )
    ..registerSingleton<AudioHandler>(audio)
    ..registerFactory<CommentThreadCubit>(services.createCommentsCubit)
    ..registerFactory<InteractionStatsCubit>(services.createStatsCubit);
  final runtime = PreviewRuntime(
    isolation: isolation,
    services: services,
    media: media,
    http: http,
    audio: audio,
  );
  runApp(_PreviewApp(runtime: runtime));
  return runtime;
}

class _PreviewApp extends StatefulWidget {
  const _PreviewApp({required this.runtime});
  final PreviewRuntime runtime;
  @override
  State<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<_PreviewApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.runtime.audio.pause().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.runtime.audio.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppThemeController.instance,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SoundConnect Önizleme',
      theme: AppTheme.current,
      themeMode: AppThemeController.instance.variant == AppThemeVariant.light
          ? ThemeMode.light
          : ThemeMode.dark,
      themeAnimationDuration: Duration.zero,
      routes: {
        AppRoutes.announcements: (_) => AnnouncementDirectoryScreen(
          repository: widget.runtime.services.promotions,
          sessions: widget.runtime.services.sessions,
          videoDataSourceFactory: widget.runtime.media.videoSource,
        ),
      },
      onUnknownRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Önizleme')),
          body: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Bu ekran önizleme kapsamı dışında. '
              'Geri dönüp akış kartlarını incelemeye devam edebilirsin.',
            ),
          ),
        ),
      ),
      home: FeedPreviewScreen(
        services: widget.runtime.services,
        videoDataSourceFactory: widget.runtime.media.videoSource,
        onReset: () => unawaited(widget.runtime.audio.stop()),
      ),
    ),
  );
}
