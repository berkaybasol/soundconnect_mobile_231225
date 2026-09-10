import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import 'event_share_card.dart';
import 'event_share_data.dart';
import 'event_share_message.dart';
import 'story_share_exporter.dart';

export 'story_share_exporter.dart' show EventShareTarget;

/// The exact immutable PNG shown in the preview and handed to the target app.
class PreparedEventShare {
  PreparedEventShare({required Uint8List bytes, required this.data})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final Uint8List bytes;
  final EventShareData data;
}

abstract interface class EventShareService {
  Future<PreparedEventShare> prepare(BuildContext context, EventShareData data);

  Future<void> share(
    BuildContext context,
    PreparedEventShare prepared,
    EventShareTarget target, {
    bool Function()? isValid,
  });
}

typedef EventShareMediaFileLoader = StoryShareMediaFileLoader;
typedef EventShareImageResolver = StoryShareImageResolver;
typedef EventShareSender = StoryShareSender;

class PlatformEventShareService implements EventShareService {
  PlatformEventShareService({
    ScreenshotController? screenshotController,
    MethodChannel? channel,
    EventShareMediaFileLoader? mediaFileLoader,
    EventShareImageResolver? imageResolver,
    Future<Directory> Function()? temporaryDirectory,
    EventShareSender? shareSender,
    TargetPlatform? platform,
    DateTime Function()? clock,
    String Function()? randomToken,
  }) : _platform = platform ?? defaultTargetPlatform,
       _exporter = StoryShareExporter(
         screenshotController: screenshotController,
         channel: channel,
         mediaFileLoader: mediaFileLoader,
         imageResolver: imageResolver,
         temporaryDirectory: temporaryDirectory,
         shareSender: shareSender,
         platform: platform,
         clock: clock,
         randomToken: randomToken,
       );

  static const canvasSize = StoryShareExporter.canvasSize;
  static const pixelRatio = StoryShareExporter.pixelRatio;
  final TargetPlatform _platform;
  final StoryShareExporter _exporter;

  @override
  Future<PreparedEventShare> prepare(
    BuildContext context,
    EventShareData data,
  ) async {
    final bytes = await _exporter.prepare(
      context,
      media: [
        StoryShareMedia(
          url: data.posterUrl,
          profile: AppImageCacheProfile.original,
          maximumBytes: 12 * 1024 * 1024,
          maximumSize: const Size(1080, 1440),
        ),
        StoryShareMedia(
          url: data.venueAvatarUrl,
          profile: AppImageCacheProfile.compact,
          maximumBytes: 2 * 1024 * 1024,
          maximumSize: const Size(192, 192),
        ),
      ],
      buildCard: (images) => EventShareCard(
        data: data,
        posterImage: images[0],
        venueAvatar: images[1],
      ),
    );
    return PreparedEventShare(bytes: bytes, data: data);
  }

  @override
  Future<void> share(
    BuildContext context,
    PreparedEventShare prepared,
    EventShareTarget target, {
    bool Function()? isValid,
  }) => _exporter.share(
    context,
    bytes: prepared.bytes,
    target: target,
    kind: StoryShareKind.event,
    caption: EventShareMessage.forPlatform(_platform),
    subject: 'SoundConnect etkinliği',
    isValid: isValid,
  );
}
