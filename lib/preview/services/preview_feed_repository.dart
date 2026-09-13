import '../../core/error/app_error.dart';
import '../../core/error/result.dart';
import '../../modules/musician_feed/domain/musician_feed_models.dart';
import '../../modules/musician_feed/domain/musician_feed_repository.dart';
import '../data/preview_scenario_store.dart';

class PreviewFeedRepository implements MusicianFeedRepository {
  PreviewFeedRepository(this.store);
  final PreviewScenarioStore store;
  List<String> _snapshot = [];
  int _generation = 0;
  DateTime _generatedAt = DateTime.now().toUtc();
  final Map<MusicianFeedTelemetryEventType, int> localEvents = {};
  int pagesLoaded = 0;

  @override
  Future<Result<MusicianFeedPage>> load({
    required int limit,
    String? cursor,
  }) async {
    if (limit < 1 || limit > 30) return _invalid();
    var offset = 0;
    if (cursor == null) {
      _generation++;
      _generatedAt = DateTime.now().toUtc();
      _snapshot = store.visibleMixedFeed
          .map((scenario) => scenario.item.id)
          .toList();
    } else {
      final parts = cursor.split(':');
      if (parts.length != 2 || int.tryParse(parts[0]) != _generation) {
        return _invalid();
      }
      offset = int.tryParse(parts[1]) ?? -1;
      if (offset < 0 || offset > _snapshot.length) return _invalid();
    }
    final end = (offset + limit).clamp(0, _snapshot.length);
    final rows = <MusicianFeedItem>[];
    // Catalogue actions can suppress items after this page sequence began.
    // Keep the cursor stable while honoring the current local hide/mute state.
    final visibleIds = store.visibleMixedFeed.map((row) => row.item.id).toSet();
    for (var index = offset; index < end; index++) {
      if (!visibleIds.contains(_snapshot[index])) continue;
      final source = store.itemById(_snapshot[index]);
      if (source == null) continue;
      rows.add(
        MusicianFeedItem(
          id: source.id,
          type: source.type,
          payloadVersion: source.payloadVersion,
          occurredAt: source.occurredAt,
          position: index,
          impressionToken: 'preview-delivery-$_generation-$index',
          reason: source.reason,
          author: source.author,
          target: source.target,
          engagement: source.engagement,
          promotion: source.promotion,
          feedbackCapabilities: source.feedbackCapabilities,
          payload: source.payload,
        ),
      );
    }
    pagesLoaded++;
    return Result.success(
      MusicianFeedPage(
        schemaVersion: musicianFeedSchemaVersion,
        algorithmVersion: 'preview-fixed-order-v1',
        feedSessionId: 'preview-session-$_generation',
        generatedAt: _generatedAt,
        items: rows,
        nextCursor: end < _snapshot.length ? '$_generation:$end' : null,
        hasMore: end < _snapshot.length,
      ),
    );
  }

  Result<MusicianFeedPage> _invalid() => const Result.failure(
    AppError(
      code: musicianFeedCursorInvalidCode,
      message: 'Önizleme yenilendi. Akışı yeniden yükle.',
    ),
  );

  @override
  Future<Result<void>> sendFeedback({
    required String itemId,
    required String impressionToken,
    required MusicianFeedFeedbackAction action,
    String? reason,
  }) async {
    switch (action) {
      case MusicianFeedFeedbackAction.hide:
        store.hide(itemId);
      case MusicianFeedFeedbackAction.showLess:
        store.showLess(itemId);
      case MusicianFeedFeedbackAction.report:
        break;
    }
    return const Result.success(null);
  }

  @override
  Future<Result<void>> recordEvent({
    required String clientEventId,
    required String impressionToken,
    required MusicianFeedTelemetryEventType eventType,
    DateTime? occurredAt,
  }) async {
    localEvents.update(eventType, (value) => value + 1, ifAbsent: () => 1);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> muteAuthor({
    required String profileType,
    required String profileId,
  }) async {
    store.mute(profileType, profileId);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> unmuteAuthor({
    required String profileType,
    required String profileId,
  }) async {
    store.unmute(profileType, profileId);
    return const Result.success(null);
  }
}
