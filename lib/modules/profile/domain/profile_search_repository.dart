import '../../../core/error/result.dart';
import 'entities/profile_search_result.dart';

abstract class ProfileSearchRepository {
  Future<Result<List<ProfileSearchResult>>> searchProfiles(String query);
}
