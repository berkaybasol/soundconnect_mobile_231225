import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/pagination/page.dart';
import '../domain/entities/table_group.dart';
import '../domain/entities/table_group_message.dart';
import '../domain/table_group_repository.dart';
import 'models/table_group_create_request.dart';
import 'table_group_endpoints.dart';
import 'models/table_group_model.dart';
import 'models/table_group_message_model.dart';

class TableGroupRepositoryImpl implements TableGroupRepository {
  final ApiClient _apiClient;

  TableGroupRepositoryImpl(this._apiClient);

  @override
  Future<Result<TableGroup>> createTableGroup(
    TableGroupCreateRequest request,
  ) async {
    try {
      final response = await _apiClient.post<TableGroup>(
        TableGroupEndpoints.create(),
        body: request.toJson(),
        decoder: (json) =>
            TableGroupModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'table_group_create_unknown',
          message: 'Masa olusturulamadi',
        ),
      );
    }
  }

  @override
  Future<Result<Page<TableGroup>>> listActiveTableGroups({
    required String cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final query = <String, dynamic>{
        'cityId': cityId,
        'districtId': districtId,
        'neighborhoodId': neighborhoodId,
        'page': page,
        'size': size,
      };
      query.removeWhere((key, value) => value == null);

      final response = await _apiClient.get<Page<TableGroup>>(
        TableGroupEndpoints.active,
        query: query,
        decoder: (json) {
          final map = json as Map<String, dynamic>? ?? const {};
          final content = (map['content'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(TableGroupModel.fromJson)
              .toList();
          final currentPage = (map['number'] as num?)?.toInt() ?? page;
          final bool hasNext;
          if (map['last'] is bool) {
            hasNext = !(map['last'] as bool);
          } else {
            hasNext = (map['hasNext'] as bool?) ?? false;
          }
          return Page<TableGroup>(
            items: content,
            hasNext: hasNext,
            nextCursor: hasNext ? (currentPage + 1).toString() : null,
          );
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'table_group_list_unknown',
          message: 'Aktif masalar getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<TableGroup>> getDetail(String tableGroupId) async {
    try {
      final response = await _apiClient.get<TableGroup>(
        TableGroupEndpoints.detail(tableGroupId),
        decoder: (json) =>
            TableGroupModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'table_group_detail_unknown',
          message: 'Masa detayi getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> joinTableGroup({
    required String tableGroupId,
    String? note,
  }) async {
    try {
      await _apiClient.post<Object?>(
        TableGroupEndpoints.join(tableGroupId),
        body: note?.trim().isNotEmpty == true ? {'note': note!.trim()} : {},
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'table_group_join_unknown',
          message: 'Masaya katilim istegi gonderilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> approveJoinRequest({
    required String tableGroupId,
    required String participantId,
  }) async {
    return _postVoid(TableGroupEndpoints.approve(tableGroupId, participantId));
  }

  @override
  Future<Result<void>> rejectJoinRequest({
    required String tableGroupId,
    required String participantId,
  }) async {
    return _postVoid(TableGroupEndpoints.reject(tableGroupId, participantId));
  }

  @override
  Future<Result<void>> leaveTableGroup({required String tableGroupId}) async {
    return _postVoid(TableGroupEndpoints.leave(tableGroupId));
  }

  @override
  Future<Result<void>> kickParticipant({
    required String tableGroupId,
    required String participantId,
  }) async {
    return _postVoid(TableGroupEndpoints.kick(tableGroupId, participantId));
  }

  @override
  Future<Result<void>> cancelTableGroup({required String tableGroupId}) async {
    return _postVoid(TableGroupEndpoints.cancel(tableGroupId));
  }

  @override
  Future<Result<Page<TableGroupMessage>>> getChatMessages({
    required String tableGroupId,
    int page = 0,
    int size = 30,
  }) async {
    try {
      final response = await _apiClient.get<Page<TableGroupMessage>>(
        TableGroupEndpoints.chatMessages(tableGroupId),
        query: <String, dynamic>{'page': page, 'size': size},
        decoder: (json) {
          final map = json as Map<String, dynamic>? ?? const {};
          final content = (map['content'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(TableGroupMessageModel.fromJson)
              .toList();
          final currentPage = (map['number'] as num?)?.toInt() ?? page;
          final bool hasNext;
          if (map['last'] is bool) {
            hasNext = !(map['last'] as bool);
          } else {
            hasNext = (map['hasNext'] as bool?) ?? false;
          }
          return Page<TableGroupMessage>(
            items: content,
            hasNext: hasNext,
            nextCursor: hasNext ? (currentPage + 1).toString() : null,
          );
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'table_group_chat_messages_unknown',
          message: 'Sohbet mesajlari getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<TableGroupMessage>> sendChatMessage({
    required String tableGroupId,
    required String content,
    String messageType = 'TEXT',
  }) async {
    try {
      final response = await _apiClient.post<TableGroupMessage>(
        TableGroupEndpoints.chatMessages(tableGroupId),
        body: <String, dynamic>{'content': content, 'messageType': messageType},
        decoder: (json) =>
            TableGroupMessageModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'table_group_chat_send_unknown',
          message: 'Mesaj gonderilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<int>> getUnreadBadge({required String tableGroupId}) async {
    try {
      final response = await _apiClient.get<int>(
        TableGroupEndpoints.chatUnreadBadge(tableGroupId),
        decoder: (json) => (json as num?)?.toInt() ?? 0,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'table_group_unread_unknown',
          message: 'Unread bilgisi alinamadi',
        ),
      );
    }
  }

  Future<Result<void>> _postVoid(String path) async {
    try {
      await _apiClient.post<Object?>(
        path,
        body: const {},
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'table_group_action_unknown',
          message: 'Islem basarisiz',
        ),
      );
    }
  }
}
