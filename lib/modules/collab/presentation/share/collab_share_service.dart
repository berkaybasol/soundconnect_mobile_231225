import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/deep_link/app_deep_link.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_listing.dart';
import 'collab_share_card.dart';

enum CollabShareTarget { instagramStory, whatsapp, other }

abstract interface class CollabShareService {
  Future<void> share(
    BuildContext context,
    CollabListing listing,
    CollabShareTarget target,
  );
}

class PlatformCollabShareService implements CollabShareService {
  PlatformCollabShareService({
    ScreenshotController? screenshotController,
    MethodChannel? channel,
    CollabShareMessageBuilder? messageBuilder,
  }) : _screenshotController = screenshotController ?? ScreenshotController(),
       _channel = channel ?? const MethodChannel(_channelName),
       _messageBuilder = messageBuilder ?? const CollabShareMessageBuilder();

  static const _channelName = 'com.soundconnect/collab_share';
  final ScreenshotController _screenshotController;
  final MethodChannel _channel;
  final CollabShareMessageBuilder _messageBuilder;

  @override
  Future<void> share(
    BuildContext context,
    CollabListing listing,
    CollabShareTarget target,
  ) async {
    final avatarBytes = await _loadAvatar(listing.publisher.avatarUrl);
    if (!context.mounted) return;
    ImageProvider? avatarProvider;
    if (avatarBytes != null) {
      final candidate = MemoryImage(avatarBytes);
      var decodeFailed = false;
      await precacheImage(
        candidate,
        context,
        onError: (_, _) => decodeFailed = true,
      );
      if (!context.mounted) return;
      if (!decodeFailed) avatarProvider = candidate;
    }
    final bytes = await _screenshotController.captureFromWidget(
      CollabShareCard(listing: listing, publisherAvatar: avatarProvider),
      context: context,
      pixelRatio: 3,
      delay: const Duration(milliseconds: 80),
      targetSize: const Size(360, 640),
    );
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}collab_share',
    );
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}collab_${listing.id}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    final caption = _messageBuilder.build(listing);

    if (target != CollabShareTarget.other && Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('share', <String, Object>{
          'target': target.name,
          'path': file.path,
          'caption': caption,
        });
        return;
      } on PlatformException catch (error) {
        if (error.code != 'app_not_installed') rethrow;
      } on MissingPluginException {
        // Desktop/tests and unsupported platforms use the system share sheet.
      }
    }

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: 'image/png')],
        text: caption,
        subject: listing.title,
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      ),
    );
  }

  Future<Uint8List?> _loadAvatar(String? url) async {
    final normalized = url?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    try {
      final file = await AppImageCacheManager.compact
          .getSingleFile(normalized)
          .timeout(const Duration(seconds: 8));
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}

class CollabShareMessageBuilder {
  const CollabShareMessageBuilder({
    this.listingBaseUrl = const String.fromEnvironment(
      'SOUNDCONNECT_LISTING_SHARE_BASE_URL',
      defaultValue: SoundConnectLinks.listingBaseUrl,
    ),
  });

  final String listingBaseUrl;

  String build(CollabListing listing) {
    final specialty = listing.specialtyLabel ?? listing.wantedType.label;
    final url = listingUrl(listing.id);
    return <String>[
      '🎵 SoundConnect’te yeni bir iş birliği ilanı',
      '📍 ${listing.city.name} · Aranan: $specialty',
      '',
      'İlan detayını SoundConnect’te görüntüle.',
      if (url != null) url,
    ].join('\n');
  }

  String? listingUrl(String listingId) {
    final normalized = listingBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final baseUri = Uri.tryParse(normalized);
    if (normalized.isEmpty ||
        baseUri == null ||
        baseUri.scheme != 'https' ||
        baseUri.host.isEmpty) {
      return null;
    }
    return '$normalized/${Uri.encodeComponent(listingId)}';
  }
}
