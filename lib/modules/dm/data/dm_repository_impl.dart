import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/pagination/page.dart';
import '../domain/dm_repository.dart';
import '../domain/entities/dm_conversation_preview.dart';
import '../domain/entities/dm_message.dart';
import 'dm_endpoints.dart';
import 'models/dm_conversation_preview_model.dart';
import 'models/dm_message_model.dart';

class DmRepositoryImpl implements DmRepository {
  final ApiClient _apiClient;

  DmRepositoryImpl(this._apiClient);

  @override
  Future<Result<List<DmConversationPreview>>> getMyConversations() async {
    try {
      final items = await _apiClient.get<List<DmConversationPreview>>(
        DmEndpoints.conversationsMy,
        decoder: (json) => _decodeConversationList(json),
      );
      return Result.success(items);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'dm_conversations_unknown',
          message: 'DM konusmalari getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    try {
      final count = await _apiClient.get<int>(
        DmEndpoints.unreadCount,
        decoder: (json) {
          if (json is! Map) {
            throw const FormatException('Expected unread count object.');
          }
          final rawCount = json['unreadCount'];
          if (rawCount is! num) {
            throw const FormatException('Expected numeric unreadCount.');
          }
          return rawCount.toInt().clamp(0, 999999);
        },
      );
      return Result.success(count);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'dm_unread_count_unknown',
          message: 'Okunmamis mesaj sayisi alinamadi',
        ),
      );
    }
  }

  @override
  Future<Result<String>> getOrCreateConversation({
    required String otherUserId,
  }) async {
    try {
      final encodedOtherUserId = Uri.encodeQueryComponent(otherUserId);
      final conversationId = await _apiClient.post<String>(
        '${DmEndpoints.conversationBetween}?otherUserId=$encodedOtherUserId',
        body: null,
        decoder: (json) => json?.toString() ?? '',
      );
      if (conversationId.trim().isEmpty) {
        return Result.failure(
          const AppError(
            code: 'dm_conversation_empty',
            message: 'Konusma olusturulamadi',
          ),
        );
      }
      return Result.success(conversationId);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'dm_conversation_unknown',
          message: 'Konusma olusturulamadi',
        ),
      );
    }
  }

  @override
  Future<Result<Page<DmMessage>>> getConversationMessages({
    required String conversationId,
    int page = 0,
    int size = 30,
  }) async {
    try {
      final items = await _apiClient.get<Page<DmMessage>>(
        DmEndpoints.conversationMessages(conversationId),
        query: {'page': page, 'size': size, 'sort': 'createdAt,desc'},
        decoder: (json) => _decodeMessagePage(json, page),
      );
      return Result.success(items);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'dm_messages_unknown',
          message: 'Mesajlar getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<DmMessage>> sendMessage({
    required String conversationId,
    required String recipientId,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      final item = await _apiClient.post<DmMessage>(
        DmEndpoints.messageSend,
        body: <String, dynamic>{
          'conversationId': conversationId,
          'recipientId': recipientId,
          'content': content,
          'messageType': messageType,
        },
        decoder: (json) =>
            DmMessageModel.fromJson((json as Map).cast<String, dynamic>()),
      );
      return Result.success(item);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(code: 'dm_send_unknown', message: 'Mesaj gonderilemedi'),
      );
    }
  }

  @override
  Future<Result<void>> markMessageAsRead({required String messageId}) async {
    try {
      await _apiClient.patch<Object?>(
        DmEndpoints.messageMarkRead(messageId),
        body: null,
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'dm_mark_read_unknown',
          message: 'Mesaj okundu isareti guncellenemedi',
        ),
      );
    }
  }

  List<DmConversationPreview> _decodeConversationList(Object? json) {
    if (json is! List) return const [];
    return json
        .whereType<Map>()
        .map(
          (item) =>
              DmConversationPreviewModel.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  Page<DmMessage> _decodeMessagePage(Object? json, int fallbackPage) {
    final map = json as Map<String, dynamic>? ?? const {};
    final content = (map['content'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => DmMessageModel.fromJson(item.cast<String, dynamic>()))
        .toList();
    final currentPage = (map['number'] as num?)?.toInt() ?? fallbackPage;
    final bool hasNext = map['last'] is bool
        ? !(map['last'] as bool)
        : (map['hasNext'] as bool?) ?? false;
    return Page<DmMessage>(
      items: content,
      hasNext: hasNext,
      nextCursor: hasNext ? (currentPage + 1).toString() : null,
    );
  }
}
