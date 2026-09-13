import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const previewPackageName =
    'com.berkayb.soundconnect.soundconnect_23_12_25codx.preview';
const previewChannel = MethodChannel('soundconnect/preview/isolation');
const previewNativePlugins = <String>{
  'jni',
  'jni_flutter',
  'audio_session',
  'just_audio',
  'better_player_plus',
  'sqflite_android',
  'wakelock_plus',
  'video_player_android',
};

/// Must pass before stores, repositories or media are initialized.
void validatePreviewIsolation(
  Map<Object?, Object?> status, {
  required bool compiledForPreview,
  required bool releaseMode,
  required bool qa,
}) {
  final plugins = status['registeredPluginNames'];
  final expectedPlugins = {...previewNativePlugins, if (qa) 'integration_test'};
  if (!compiledForPreview ||
      releaseMode ||
      status['packageName'] != previewPackageName ||
      status['previewQa'] != qa ||
      status['internetPermissionGranted'] != qa ||
      plugins is! List ||
      plugins.length != expectedPlugins.length ||
      !plugins.toSet().containsAll(expectedPlugins)) {
    throw StateError('Önizlemenin uygulama ayrımı doğrulanamadı.');
  }
}

Future<Map<Object?, Object?>> verifyPreviewIsolation({bool qa = false}) async {
  final status = await previewChannel.invokeMapMethod<Object?, Object?>(
    'status',
  );
  if (status == null) throw StateError('Önizleme kimliği okunamadı.');
  validatePreviewIsolation(
    status,
    compiledForPreview: const bool.fromEnvironment('SOUNDCONNECT_PREVIEW'),
    releaseMode: kReleaseMode,
    qa: qa,
  );
  return status;
}
