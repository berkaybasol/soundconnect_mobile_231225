import '../../../core/error/result.dart';
import '../../../core/pagination/page.dart';
import '../data/models/table_group_create_request.dart';
import 'entities/table_group.dart';

abstract class TableGroupRepository {
  Future<Result<TableGroup>> createTableGroup(TableGroupCreateRequest request);
  Future<Result<Page<TableGroup>>> listActiveTableGroups({
    required String cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  });
  Future<Result<TableGroup>> getDetail(String tableGroupId);
  Future<Result<void>> joinTableGroup({
    required String tableGroupId,
    String? note,
  });
}
