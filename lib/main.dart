import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'app/app.dart';
import 'core/audio/audio_player_handler.dart';
import 'core/di/service_locator.dart';
import 'shared/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
}
