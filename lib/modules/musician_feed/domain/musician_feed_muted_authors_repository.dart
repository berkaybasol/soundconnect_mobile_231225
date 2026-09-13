import '../../../core/error/result.dart';
import 'musician_feed_muted_authors.dart';

abstract interface class MusicianFeedMutedAuthorsRepository {
  Future<Result<MusicianFeedMutedAuthorsPage>> load({
    int limit = 30,
    String? cursor,
  });

  Future<Result<void>> unmute({
    required String profileType,
    required String profileId,
  });
}
