import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data' show BytesBuilder;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../shared/images/app_cached_network_image.dart';

enum EventShareTarget { instagramStory, whatsapp, other }

enum StoryShareKind { event, overthinking }

/// Optional remote media is bounded and decoded before offscreen capture.
class StoryShareMedia {
  const StoryShareMedia({
    required this.url,
    required this.profile,
    required this.maximumBytes,
    required this.maximumSize,
  });

  final String? url;
  final AppImageCacheProfile profile;
  final int maximumBytes;
  final Size maximumSize;
}

typedef StoryShareMediaFileLoader =
    Future<File> Function(String url, AppImageCacheProfile profile);
typedef StoryShareImageResolver =
    Future<bool> Function(ImageProvider provider, BuildContext context);
typedef StoryShareSender = Future<ShareResult> Function(ShareParams params);

class StoryShareExporter {
  StoryShareExporter({
    ScreenshotController? screenshotController,
    MethodChannel? channel,
    StoryShareMediaFileLoader? mediaFileLoader,
    StoryShareImageResolver? imageResolver,
    Future<Directory> Function()? temporaryDirectory,
    StoryShareSender? shareSender,
    TargetPlatform? platform,
    DateTime Function()? clock,
    String Function()? randomToken,
  }) : _screenshotController = screenshotController ?? ScreenshotController(),
       _channel =
           channel ?? const MethodChannel('com.soundconnect/collab_share'),
       _mediaFileLoader = mediaFileLoader ?? _cachedMediaFile,
       _imageResolver = imageResolver ?? _resolveImage,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _shareSender = shareSender ?? SharePlus.instance.share,
       _platform = platform ?? defaultTargetPlatform,
       _clock = clock ?? DateTime.now,
       _randomToken = randomToken ?? _secureToken;

  static const canvasSize = Size(360, 640);
  static const pixelRatio = 3.0;
  static const _mediaTimeout = Duration(seconds: 8);
  static const _decodeTimeout = Duration(seconds: 5);
  static const _maximumPngBytes = 20 * 1024 * 1024;

  static final _safeToken = RegExp(r'^[a-f0-9]{32}$');

  final ScreenshotController _screenshotController;
  final MethodChannel _channel;
  final StoryShareMediaFileLoader _mediaFileLoader;
  final StoryShareImageResolver _imageResolver;
  final Future<Directory> Function() _temporaryDirectory;
  final StoryShareSender _shareSender;
  final TargetPlatform _platform;
  final DateTime Function() _clock;
  final String Function() _randomToken;

  Future<Uint8List> prepare(
    BuildContext context, {
    required List<StoryShareMedia> media,
    required Widget Function(List<ImageProvider?> images) buildCard,
  }) async {
    if (!context.mounted || !_isCurrent(context)) {
      throw StateError('Share preview was closed.');
    }
    final loaded = await Future.wait([
      for (final item in media)
        _loadMedia(
          item.url,
          profile: item.profile,
          maximumBytes: item.maximumBytes,
          maximumSize: item.maximumSize,
        ),
    ]);
    if (!context.mounted || !_isCurrent(context)) {
      throw StateError('Share preview was closed.');
    }

    // Resolve the horizontal header and the event's local poster fallback.
    // Providers must match the widgets before offscreen capture starts.
    for (final asset in const [
      AssetImage('assets/Logoyanyana.png'),
      AssetImage('assets/logo.png'),
    ]) {
      if (!context.mounted || !_isCurrent(context)) {
        throw StateError('Share preview was closed.');
      }
      final brandReady = await _imageResolver(
        asset,
        context,
      ).timeout(_decodeTimeout);
      if (!context.mounted || !_isCurrent(context)) {
        throw StateError('Share preview was closed.');
      }
      if (!brandReady) {
        throw StateError('SoundConnect share artwork could not be loaded.');
      }
    }
    final images = <ImageProvider?>[];
    for (final image in loaded) {
      if (!context.mounted || !_isCurrent(context)) {
        throw StateError('Share preview was closed.');
      }
      images.add(
        image != null && await _resolveOptionalImage(image, context)
            ? image
            : null,
      );
      if (!context.mounted || !_isCurrent(context)) {
        throw StateError('Share preview was closed.');
      }
    }
    if (!context.mounted || !_isCurrent(context)) {
      throw StateError('Share preview was closed.');
    }
    final bytes = await _screenshotController
        .captureFromWidget(
          buildCard(List<ImageProvider?>.unmodifiable(images)),
          context: context,
          targetSize: canvasSize,
          pixelRatio: pixelRatio,
          delay: const Duration(milliseconds: 80),
        )
        .timeout(const Duration(seconds: 12));
    if (!context.mounted || !_isCurrent(context)) {
      throw StateError('Share preview was closed.');
    }
    _validatePng(bytes);
    return bytes;
  }

  Future<void> share(
    BuildContext context, {
    required Uint8List bytes,
    required EventShareTarget target,
    required StoryShareKind kind,
    required String caption,
    required String subject,
    bool Function()? isValid,
  }) async {
    bool current() => _isCurrent(context) && (isValid?.call() ?? true);
    if (!current()) return;
    _validatePng(bytes);
    final directory = await _shareDirectory(kind);
    if (!context.mounted || !current()) return;
    await _removeExpiredFiles(directory, kind);
    if (!context.mounted || !current()) return;

    final token = _randomToken();
    if (!_safeToken.hasMatch(token)) throw StateError('Invalid share token.');
    final name = '${kind.name}_${_clock().millisecondsSinceEpoch}_$token.png';
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    // No content IDs, usernames or other user-controlled strings enter the path.
    // Exclusive creation also refuses an existing file or symbolic link.
    await file.create(exclusive: true);
    if (!context.mounted || !current()) return;
    await file.writeAsBytes(bytes, flush: true);
    if (!context.mounted || !current()) return;

    if (_platform == TargetPlatform.android &&
        target != EventShareTarget.other) {
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
        // Older clients and unsupported environments use the system picker.
      }
    }
    // A route may have been dismissed while the target-app lookup completed.
    if (!context.mounted || !current()) return;
    final origin = _shareOrigin(context);
    if (origin == null) return;
    await _shareSender(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: caption,
        subject: subject,
        sharePositionOrigin: origin,
      ),
    );
    // Receiving apps may read the file after the share future resolves. Keep
    // it for at least 24 hours; only a later share performs scoped cleanup.
  }

  Future<MemoryImage?> _loadMedia(
    String? rawUrl, {
    required AppImageCacheProfile profile,
    required int maximumBytes,
    required Size maximumSize,
  }) async {
    final url = rawUrl?.trim();
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null ||
        !const ['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    try {
      final file = await _mediaFileLoader(url!, profile).timeout(_mediaTimeout);
      final length = await file.length().timeout(_decodeTimeout);
      if (length <= 0 || length > maximumBytes) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk
          in file.openRead(0, maximumBytes + 1).timeout(_decodeTimeout)) {
        builder.add(chunk);
      }
      if (builder.length > maximumBytes) return null;
      final png = await _downsample(
        builder.takeBytes(),
        maximumSize,
      ).timeout(_decodeTimeout);
      return png == null ? null : MemoryImage(png);
    } catch (_) {
      // Missing, slow or invalid remote artwork always falls back to the local
      // artwork and initials; it never blocks sharing the content itself.
      return null;
    }
  }

  Future<bool> _resolveOptionalImage(
    ImageProvider provider,
    BuildContext context,
  ) async {
    try {
      return await _imageResolver(provider, context).timeout(_decodeTimeout);
    } catch (_) {
      return false;
    }
  }

  static Future<Uint8List?> _downsample(
    Uint8List bytes,
    Size maximumSize,
  ) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width <= 0 ||
          descriptor.height <= 0 ||
          descriptor.width > 32768 ||
          descriptor.height > 32768 ||
          descriptor.width * descriptor.height > 80000000) {
        return null;
      }
      final scale = math.min(
        1.0,
        math.min(
          maximumSize.width / descriptor.width,
          maximumSize.height / descriptor.height,
        ),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  static Future<bool> _resolveImage(
    ImageProvider provider,
    BuildContext context,
  ) async {
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final completer = Completer<bool>();
    final listener = ImageStreamListener(
      (image, _) {
        if (!completer.isCompleted) completer.complete(true);
        image.dispose();
      },
      onError: (Object _, StackTrace? _) {
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    stream.addListener(listener);
    try {
      return await completer.future.timeout(
        _decodeTimeout,
        onTimeout: () => false,
      );
    } finally {
      stream.removeListener(listener);
    }
  }

  Future<Directory> _shareDirectory(StoryShareKind kind) async {
    final temporary = await _temporaryDirectory();
    final parent = await temporary.resolveSymbolicLinks();
    final common = await _ownedDirectory(parent, 'collab_share');
    if (kind == StoryShareKind.event) return common;
    // Android's FileProvider grants only this cache tree. Separate subfolders
    // and owned filename patterns prevent cross-feature cleanup.
    return _ownedDirectory(common.path, 'overthinking_shares');
  }

  Future<Directory> _ownedDirectory(String parent, String name) async {
    final directory = Directory('$parent${Platform.pathSeparator}$name');
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Invalid share cache directory.',
        directory.path,
      );
    }
    await directory.create();
    final canonical = await directory.resolveSymbolicLinks();
    final expected = directory.absolute.path;
    if (Platform.isWindows
        ? canonical.toLowerCase() != expected.toLowerCase()
        : canonical != expected) {
      throw FileSystemException(
        'Share cache escaped its directory.',
        directory.path,
      );
    }
    return directory;
  }

  Future<void> _removeExpiredFiles(
    Directory directory,
    StoryShareKind kind,
  ) async {
    final ownedFileName = RegExp(
      '^${kind.name}_\\d+_[a-f0-9]{32}\\.png'
      r'$',
    );
    final cutoff = _clock().subtract(const Duration(hours: 24));
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!ownedFileName.hasMatch(name)) continue;
        try {
          final stat = await entity.stat();
          if (stat.type == FileSystemEntityType.file &&
              stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } on FileSystemException {
          // A concurrent share/OS cache eviction is harmless.
        }
      }
    } on FileSystemException {
      // Cleanup is best effort and must not prevent a new share.
    }
  }

  static bool _isCurrent(BuildContext context) =>
      context.mounted && ModalRoute.of(context)?.isCurrent != false;

  static Rect? _shareOrigin(BuildContext context) {
    final object = context.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return null;
    }
    final size = object.size;
    final offset = object.localToGlobal(Offset.zero);
    if (size.isEmpty ||
        !size.width.isFinite ||
        !size.height.isFinite ||
        !offset.dx.isFinite ||
        !offset.dy.isFinite) {
      return null;
    }
    final bounds = offset & size;
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    final visible = bounds.intersect(screen);
    return visible.isEmpty ? null : visible;
  }

  static void _validatePng(Uint8List bytes) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < signature.length || bytes.length > _maximumPngBytes) {
      throw StateError('Invalid story share image.');
    }
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) {
        throw StateError('Invalid story share image.');
      }
    }
  }

  static Future<File> _cachedMediaFile(
    String url,
    AppImageCacheProfile profile,
  ) => AppImageCacheManager.forProfile(profile).getSingleFile(url);

  static String _secureToken() {
    final random = math.Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
