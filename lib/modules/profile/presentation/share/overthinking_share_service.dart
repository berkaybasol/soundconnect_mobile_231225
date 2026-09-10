import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import 'overthinking_share_card.dart';
import 'overthinking_share_data.dart';
import 'story_share_exporter.dart';

export 'story_share_exporter.dart' show EventShareTarget;

/// The exact immutable PNG shown in the preview and handed to the target app.
class PreparedOverthinkingShare {
  PreparedOverthinkingShare({required Uint8List bytes, required this.data})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final Uint8List bytes;
  final OverthinkingShareData data;
}

abstract interface class OverthinkingShareService {
  Future<PreparedOverthinkingShare> prepare(
    BuildContext context,
    OverthinkingShareData data,
  );

  Future<void> share(
    BuildContext context,
    PreparedOverthinkingShare prepared,
    EventShareTarget target, {
    bool Function()? isValid,
  });
}

typedef OverthinkingShareMediaFileLoader = StoryShareMediaFileLoader;
typedef OverthinkingShareImageResolver = StoryShareImageResolver;
typedef OverthinkingShareSender = StoryShareSender;

class PlatformOverthinkingShareService implements OverthinkingShareService {
  PlatformOverthinkingShareService({
    ScreenshotController? screenshotController,
    MethodChannel? channel,
    OverthinkingShareMediaFileLoader? mediaFileLoader,
    OverthinkingShareImageResolver? imageResolver,
    Future<Directory> Function()? temporaryDirectory,
    OverthinkingShareSender? shareSender,
    TargetPlatform? platform,
    DateTime Function()? clock,
    String Function()? randomToken,
  }) : _exporter = StoryShareExporter(
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
  static const caption =
      'SoundConnect’i indirmek için:\n[Google Play URL’si buraya eklenecek]';
  final StoryShareExporter _exporter;

  @override
  Future<PreparedOverthinkingShare> prepare(
    BuildContext context,
    OverthinkingShareData data,
  ) async {
    final bytes = await _exporter.prepare(
      context,
      media: [
        StoryShareMedia(
          url: data.hasMusic ? data.albumImageUrl : null,
          profile: AppImageCacheProfile.original,
          maximumBytes: 12 * 1024 * 1024,
          maximumSize: const Size(1080, 1080),
        ),
        StoryShareMedia(
          // Never request an anonymous author's avatar, even from stale data.
          url: data.anonymous ? null : data.authorAvatarUrl,
          profile: AppImageCacheProfile.compact,
          maximumBytes: 2 * 1024 * 1024,
          maximumSize: const Size(192, 192),
        ),
      ],
      buildCard: (images) => OverthinkingShareCard(
        data: data,
        albumImage: images[0],
        authorAvatar: images[1],
      ),
    );
    return PreparedOverthinkingShare(bytes: bytes, data: data);
  }

  @override
  Future<void> share(
    BuildContext context,
    PreparedOverthinkingShare prepared,
    EventShareTarget target, {
    bool Function()? isValid,
  }) => _exporter.share(
    context,
    bytes: prepared.bytes,
    target: target,
    kind: StoryShareKind.overthinking,
    caption: caption,
    subject: 'SoundConnect Overthinking',
    isValid: isValid,
  );
}
