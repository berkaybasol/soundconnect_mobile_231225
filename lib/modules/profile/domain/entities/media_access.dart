import '../../../../core/network/app_media_url.dart';

/// A short-lived, in-memory capability. Never persist this with content DTOs.
class MediaAccess {
  const MediaAccess({
    required this.assetId,
    required this.accessUrl,
    required this.expiresAt,
    this.thumbnailAccessUrl,
    this.thumbnailExpiresAt,
    this.streamingProtocol,
  });
  final String assetId;
  final String accessUrl;
  final DateTime expiresAt;
  final String? thumbnailAccessUrl;
  final DateTime? thumbnailExpiresAt;
  final String? streamingProtocol;

  factory MediaAccess.fromJson(
    Object? value, {
    required String assetId,
    required DateTime now,
  }) {
    if (value is! Map<String, dynamic> || value['assetId'] != assetId) {
      throw const FormatException('Media access identity mismatch');
    }
    final url = resolveAppMediaUrl(value['accessUrl'] as String?);
    final expires = DateTime.tryParse(value['expiresAt'] as String? ?? '');
    final thumbnail = value['thumbnailAccessUrl'] as String?;
    final thumbnailUrl = resolveAppMediaUrl(thumbnail);
    final thumbnailExpires = DateTime.tryParse(
      value['thumbnailExpiresAt'] as String? ?? '',
    );
    if (url == null ||
        expires == null ||
        !expires.isUtc ||
        !expires.isAfter(now) ||
        (thumbnail != null &&
            (thumbnailUrl == null ||
                thumbnailExpires == null ||
                !thumbnailExpires.isUtc ||
                !thumbnailExpires.isAfter(now)))) {
      throw const FormatException('Invalid or expired media access');
    }
    return MediaAccess(
      assetId: assetId,
      accessUrl: url,
      expiresAt: expires,
      thumbnailAccessUrl: thumbnailUrl,
      thumbnailExpiresAt: thumbnailExpires,
      streamingProtocol: value['streamingProtocol'] as String?,
    );
  }
}
