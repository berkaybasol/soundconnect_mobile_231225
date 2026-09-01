import '../../../core/error/result.dart';
import '../../../core/pagination/page.dart';
import '../data/models/table_group_create_request.dart';
import 'entities/table_group.dart';
import 'entities/table_group_message.dart';

abstract class TableGroupRepository {
  Future<Result<TableGroup>> createTableGroup(TableGroupCreateRequest request);
  Future<Result<Page<TableGroup>>> listActiveTableGroups({
    required String? cityId,
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
  Future<Result<void>> approveJoinRequest({
    required String tableGroupId,
    required String participantId,
  });
  Future<Result<void>> rejectJoinRequest({
    required String tableGroupId,
    required String participantId,
  });
  Future<Result<void>> leaveTableGroup({required String tableGroupId});
  Future<Result<void>> kickParticipant({
    required String tableGroupId,
    required String participantId,
  });
  Future<Result<void>> cancelTableGroup({required String tableGroupId});
  Future<Result<Page<TableGroupMessage>>> getChatMessages({
    required String tableGroupId,
    int page = 0,
    int size = 30,
  });
  Future<Result<TableGroupMessage>> sendChatMessage({
    required String tableGroupId,
    required String content,
    String messageType = 'TEXT',
  });
  Future<Result<int>> getUnreadBadge({required String tableGroupId});
}
