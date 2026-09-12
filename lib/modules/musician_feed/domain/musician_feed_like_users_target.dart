import 'musician_feed_models.dart';

typedef MusicianFeedLikeUsersTarget = ({String targetType, String targetId});

/// Profile shares have their own likes. Never fall back to a payload's source
/// id (or the reason actor) when selecting the engagement list to open.
MusicianFeedLikeUsersTarget? musicianFeedLikeUsersTarget(
  MusicianFeedItem item,
) {
  final engagement = item.engagement;
  if (engagement == null) return null;
  const supportedTypes = {
    'MEDIA',
    'EVENT',
    'EVENT_POST',
    'TABLE_GROUP_POST',
    'OVERTHINKING_PROFILE_SHARE',
    'OVERTHINKING',
    'COMMENT',
  };
  final id = engagement.targetId;
  if (!supportedTypes.contains(engagement.targetType) ||
      id.isEmpty ||
      id != id.trim() ||
      id.length > 128 ||
      RegExp(r'[/\\\u0000-\u001F\u007F]').hasMatch(id)) {
    return null;
  }
  return (targetType: engagement.targetType, targetId: id);
}
