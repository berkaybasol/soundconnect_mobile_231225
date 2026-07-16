import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

typedef AppImageStateBuilder = Widget Function(BuildContext context);
typedef AppImageCacheManagerResolver =
    BaseCacheManager Function(AppImageCacheProfile profile);

/// Keeps compact UI imagery and full-detail media in independently bounded
/// disk caches. This prevents a handful of multi-megabyte originals from
/// evicting frequently reused avatars and thumbnails.
enum AppImageCacheProfile { compact, original }

/// Shared network-image pipeline with persistent disk caching.
///
/// Callers should still prefer a server-generated thumbnail URL for compact
/// surfaces. [cacheWidth] and [cacheHeight] keep decoded bitmaps close to their
/// rendered size and prevent oversized source images from exhausting memory.
class AppCachedNetworkImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;
  final int? cacheHeight;
  final AppImageStateBuilder? placeholderBuilder;
  final AppImageStateBuilder? errorBuilder;
  final AppImageCacheProfile cacheProfile;
  final BaseCacheManager? cacheManager;
  final AppImageCacheManagerResolver? cacheManagerResolver;

  const AppCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholderBuilder,
    this.errorBuilder,
    this.cacheProfile = AppImageCacheProfile.compact,
    this.cacheManager,
    this.cacheManagerResolver,
  });

  @override
  State<AppCachedNetworkImage> createState() => _AppCachedNetworkImageState();
}

class _AppCachedNetworkImageState extends State<AppCachedNetworkImage> {
  Stream<FileResponse>? _fileStream;

  String? get _normalizedUrl {
    final value = widget.imageUrl?.trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return value;
  }

  BaseCacheManager get _cacheManager =>
      widget.cacheManager ??
      (widget.cacheManagerResolver ?? AppImageCacheManager.forProfile)(
        widget.cacheProfile,
      );

  @override
  void initState() {
    super.initState();
    _refreshStream();
  }

  @override
  void didUpdateWidget(covariant AppCachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheProfile != widget.cacheProfile ||
        oldWidget.cacheManager != widget.cacheManager ||
        oldWidget.cacheManagerResolver != widget.cacheManagerResolver) {
      _refreshStream();
    }
  }

  void _refreshStream() {
    final url = _normalizedUrl;
    _fileStream = url == null
        ? null
        : _cacheManager.getFileStream(url, withProgress: true);
  }

  Widget _placeholder(BuildContext context, {double? progress}) {
    final custom = widget.placeholderBuilder;
    return SizedBox(
      key: const ValueKey('app_cached_network_image.placeholder'),
      width: widget.width,
      height: widget.height,
      child: custom != null
          ? custom(context)
          : ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _error(BuildContext context) {
    final custom = widget.errorBuilder;
    return SizedBox(
      key: const ValueKey('app_cached_network_image.error'),
      width: widget.width,
      height: widget.height,
      child: custom != null
          ? custom(context)
          : ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
    );
  }

  Widget _fileImage(BuildContext context, FileInfo response) {
    return Image.file(
      response.file,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _error(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _fileStream;
    if (stream == null) return _error(context);

    return StreamBuilder<FileResponse>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(context);
        final response = snapshot.data;
        if (response is FileInfo) {
          return _fileImage(context, response);
        }
        final progress = response is DownloadProgress
            ? response.progress
            : null;
        return _placeholder(context, progress: progress);
      },
    );
  }
}

class AppImageCacheManager {
  AppImageCacheManager._();

  static final BaseCacheManager compact = CacheManager(
    Config(
      'soundconnectCompactImageCacheV1',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 800,
    ),
  );

  static final BaseCacheManager original = CacheManager(
    Config(
      'soundconnectOriginalImageCacheV1',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
    ),
  );

  static BaseCacheManager forProfile(AppImageCacheProfile profile) {
    return switch (profile) {
      AppImageCacheProfile.compact => compact,
      AppImageCacheProfile.original => original,
    };
  }
}
