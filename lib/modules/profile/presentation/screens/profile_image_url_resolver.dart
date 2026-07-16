import '../../domain/entities/media_asset.dart';

String? resolveFirstRemoteImageUrl(Iterable<String?> candidates) {
  for (final candidate in candidates) {
    final value = candidate?.trim();
    if (value == null || value.isEmpty) continue;
    final uri = Uri.tryParse(value);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return value;
    }
  }
  return null;
}

/// Compact surfaces must prefer a generated thumbnail to avoid downloading
/// the original multi-megapixel upload.
String? resolveMediaPreviewImageUrl(MediaAsset item) =>
    resolveFirstRemoteImageUrl([
      item.thumbnailUrl,
      item.playbackUrl,
      item.sourceUrl,
    ]);

/// Detail views prefer the original, with processed and thumbnail fallbacks.
String? resolveMediaDetailImageUrl(MediaAsset item) =>
    resolveFirstRemoteImageUrl([
      item.sourceUrl,
      item.playbackUrl,
      item.thumbnailUrl,
    ]);
