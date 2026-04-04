import '../../../core/error/result.dart';
import 'entities/musician_search_option.dart';

abstract class MusicianSearchRepository {
  Future<Result<List<MusicianSearchOption>>> search(String query);
}
