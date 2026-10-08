import '../../../core/network/app_media_url.dart';
import 'musician_feed_models.dart';

class MusicianFeedMutedAuthor {
  const MusicianFeedMutedAuthor({
    required this.identity,
    required this.available,
    required this.mutedAt,
    this.displayName,
    this.avatarUrl,
  });

  final MusicianFeedAuthorProfileIdentity identity;
  final bool available;
  final DateTime mutedAt;
  final String? displayName;
  final String? avatarUrl;

  String get visibleName => !available
      ? 'Kullanılamayan hesap'
      : (displayName?.trim().isNotEmpty == true
            ? displayName!.trim()
            : 'Hesap');

  String? get visibleAvatarUrl => available ? avatarUrl : null;

  factory MusicianFeedMutedAuthor.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Muted author must be an object');
    }
    final type = value['profileType'];
    final id = value['profileId'];
    final available = value['available'];
    final date = value['mutedAt'];
    final identity = type is String && id is String
        ? parseMusicianFeedAuthorProfileIdentity(
            profileType: type,
            profileId: id,
          )
        : null;
    final mutedAt = date is String ? DateTime.tryParse(date) : null;
    if (identity == null ||
        available is! bool ||
        mutedAt == null ||
        !mutedAt.isUtc) {
      throw const FormatException(
        'Muted author identity or timestamp is invalid',
      );
    }
    // Unavailable accounts never expose stale private profile projections.
    final name = available ? _optionalText(value['displayName']) : null;
    final avatar = available ? _optionalText(value['avatarUrl']) : null;
    return MusicianFeedMutedAuthor(
      identity: identity,
      available: available,
      mutedAt: mutedAt,
      displayName: name,
      avatarUrl: avatar != null && isSafeMediaReference(avatar) ? avatar : null,
    );
  }
}

class MusicianFeedMutedAuthorsPage {
  const MusicianFeedMutedAuthorsPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<MusicianFeedMutedAuthor> items;
  final String? nextCursor;
  final bool hasMore;

  factory MusicianFeedMutedAuthorsPage.fromJson(Object? value) {
    if (value is! Map || value['items'] is! List || value['hasMore'] is! bool) {
      throw const FormatException('Muted authors page is invalid');
    }
    final cursor = _optionalText(value['nextCursor']);
    final hasMore = value['hasMore'] as bool;
    if ((hasMore && cursor == null) ||
        (cursor != null && cursor.length > 4096)) {
      throw const FormatException('Muted authors cursor is invalid');
    }
    return MusicianFeedMutedAuthorsPage(
      items: List.unmodifiable(
        (value['items'] as List).map(MusicianFeedMutedAuthor.fromJson),
      ),
      nextCursor: cursor,
      hasMore: hasMore,
    );
  }
}

String? _optionalText(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Expected nullable text');
  final text = value.trim();
  return text.isEmpty ? null : text;
}
