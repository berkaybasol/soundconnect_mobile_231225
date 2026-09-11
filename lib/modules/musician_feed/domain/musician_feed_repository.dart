import '../../../core/error/result.dart';
import 'musician_feed_models.dart';

/// Stable domain signal used when the feed endpoint is intentionally absent
/// during a staged rollout. It must not be reused for transient or auth
/// failures, which retain the normal error experience.
const musicianFeedFeatureUnavailableCode = 'musician_feed_feature_unavailable';

/// Stable client-side classification for a cursor rejected after a deploy,
/// schema transition, or ranking-version change.
const musicianFeedCursorInvalidCode = 'musician_feed_cursor_invalid';

abstract class MusicianFeedRepository {
  Future<Result<MusicianFeedPage>> load({required int limit, String? cursor});

  Future<Result<void>> sendFeedback({
    required String itemId,
    required String impressionToken,
    required MusicianFeedFeedbackAction action,
    String? reason,
  });

  Future<Result<void>> recordEvent({
    required String clientEventId,
    required String impressionToken,
    required MusicianFeedTelemetryEventType eventType,
    DateTime? occurredAt,
  });

  Future<Result<void>> muteAuthor({
    required String profileType,
    required String profileId,
  });

  Future<Result<void>> unmuteAuthor({
    required String profileType,
    required String profileId,
  });
}
