import '../../../core/error/result.dart';
import 'entities/profile_venue_models.dart';

abstract class VenueDirectoryRepository {
  Future<Result<List<VenueOption>>> getAllVenues();
}
