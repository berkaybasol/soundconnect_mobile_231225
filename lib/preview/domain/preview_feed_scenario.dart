import '../../modules/musician_feed/domain/musician_feed_models.dart';

const previewViewerUserId = 'a11ce000-0000-4000-8000-000000000001';
const previewViewerProfileId = 'a11ce000-0000-4000-8000-000000000002';
const previewViewerUsername = 'deniz_prova';
const previewMediaBaseUrl = 'https://preview.soundconnect.invalid/fixtures';

class PreviewMediaReference {
  const PreviewMediaReference({
    required this.url,
    required this.kind,
    this.thumbnailUrl,
  });
  final String url;
  final String kind;
  final String? thumbnailUrl;
}

/// Describes a real production card, not a separate mock rendering.
class PreviewFeedScenario {
  const PreviewFeedScenario({
    required this.id,
    required this.label,
    required this.category,
    required this.item,
    this.note,
    this.includeInMixedFeed = true,
  });
  final String id;
  final String label;
  final String category;
  final MusicianFeedItem item;
  final String? note;
  final bool includeInMixedFeed;

  PreviewFeedScenario withItem(MusicianFeedItem value) => PreviewFeedScenario(
    id: id,
    label: label,
    category: category,
    item: value,
    note: note,
    includeInMixedFeed: includeInMixedFeed,
  );
}

/// Stable, UUID-shaped fixture identities. No server accepts these as receipts.
String previewUuid(String seed) {
  var hash = 2166136261;
  for (final unit in seed.codeUnits) {
    hash = ((hash ^ unit) * 16777619) & 0xffffffff;
  }
  return 'a11ce000-0000-4000-8000-${hash.toRadixString(16).padLeft(12, '0')}';
}
