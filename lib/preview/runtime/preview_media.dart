import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'preview_isolation.dart';

const previewMediaHost = 'preview.soundconnect.invalid';

class PreviewMediaLibrary {
  PreviewMediaLibrary(this.images, this.videoBytes, this.audioPath);
  final Map<String, Uint8List> images;
  final Uint8List videoBytes;
  final String audioPath;

  static Future<PreviewMediaLibrary> load() async {
    Future<Uint8List> read(String name) async {
      final bytes = await previewChannel.invokeMethod<Uint8List>(
        'readFixture',
        {'name': name},
      );
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Önizleme medyası eksik: $name');
      }
      return bytes;
    }

    final manifest = jsonDecode(utf8.decode(await read('manifest.json')));
    if (manifest is! List || manifest.length > 100) {
      throw const FormatException('Invalid preview media manifest');
    }
    final images = <String, Uint8List>{};
    for (final name in manifest.cast<String>()) {
      if (!RegExp(r'^[a-z0-9][a-z0-9_-]*\.png$').hasMatch(name)) {
        throw const FormatException('Invalid preview image name');
      }
      images[name] = await read(name);
    }
    final audio = await read('audio.wav');
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/soundconnect-preview-audio.wav');
    await file.writeAsBytes(audio, flush: true);
    return PreviewMediaLibrary(
      Map.unmodifiable(images),
      await read('video.mp4'),
      file.path,
    );
  }

  BetterPlayerDataSource videoSource(BetterPlayerDataSource source) {
    if (previewFixtureName(Uri.parse(source.url)) != 'video.mp4') {
      throw StateError('Bu video önizlemenin içinde bulunmuyor.');
    }
    return BetterPlayerDataSource.memory(
      videoBytes,
      videoExtension: 'mp4',
      placeholder: source.placeholder,
    );
  }

  AudioSource audioSource(String url) {
    if (previewFixtureName(Uri.parse(url)) != 'audio.wav') {
      throw StateError('Bu ses önizlemenin içinde bulunmuyor.');
    }
    return AudioSource.file(audioPath);
  }
}

String previewFixtureName(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.host != previewMediaHost ||
      uri.port != 443 ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      uri.hasQuery ||
      !RegExp(r'^/fixtures/[a-z0-9][a-z0-9_.-]*$').hasMatch(uri.path)) {
    throw StateError('Önizlemede dış bağlantılar kapalı.');
  }
  final name = uri.pathSegments.last;
  if (name.contains('..')) throw StateError('Invalid fixture path');
  return name;
}
