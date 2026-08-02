import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'core/audio/audio_player_handler.dart';
import 'core/diagnostics/app_bloc_observer.dart';
import 'core/diagnostics/app_diagnostics.dart';
import 'core/diagnostics/app_error_handlers.dart';
import 'core/di/service_locator.dart';
import 'shared/theme/theme_controller.dart';

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    installFlutterErrorHandler();
    Bloc.observer = const AppBlocObserver();

    setupDependencies();
    final themeController = await ThemeController.create();
    serviceLocator.registerSingleton<ThemeController>(themeController);
    final audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'com.berkayb.soundconnect.soundconnect_23_12_25codx.channel.audio',
        androidNotificationChannelName: 'Audio Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    serviceLocator.registerSingleton<AudioHandler>(audioHandler);
    runApp(const SoundConnectApp());
  }, AppDiagnostics.reportUnhandled);
}

