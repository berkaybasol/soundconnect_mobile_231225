import '../../../core/error/result.dart';
import 'entities/table_group_venue_option.dart';

abstract class TableGroupVenueOptionRepository {
  Future<Result<List<TableGroupVenueOption>>> search({
    required String query,
    int limit = 8,
  });
}
