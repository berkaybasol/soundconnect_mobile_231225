import 'package:flutter/foundation.dart';

/// External image captions are intentionally separate from preview semantics.
abstract final class EventShareMessage {
  // TODO(release): Replace the placeholders with the published store URLs.
  // Never synthesize a store URL from a package ID before the app is published.
  static String forPlatform(TargetPlatform platform) {
    final destination = switch (platform) {
      TargetPlatform.android => '[Google Play URL’si buraya eklenecek]',
      TargetPlatform.iOS => '[App Store URL’si buraya eklenecek]',
      _ => '[Uygulama indirme URL’si buraya eklenecek]',
    };
    return 'Etkinlik detayları için:\n$destination';
  }
}
