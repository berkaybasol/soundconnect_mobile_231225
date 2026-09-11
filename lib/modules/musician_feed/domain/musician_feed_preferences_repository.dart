import '../../../core/error/result.dart';
import 'musician_feed_preferences.dart';

abstract class MusicianFeedPreferencesRepository {
  Future<Result<MusicianFeedPreferences>> get();

  Future<Result<MusicianFeedPreferences>> updateOpportunityCity({
    required String? cityId,
    required int expectedVersion,
  });
}
