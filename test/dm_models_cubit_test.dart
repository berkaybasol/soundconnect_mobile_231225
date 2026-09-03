import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/models/dm_conversation_preview_model.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/models/dm_message_model.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_conversation_preview.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_message.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_chat_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_chat_state.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_conversations_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_conversations_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';

void main() {
  group('DM models', () {
    test('message model parses dates, aliases values, and safe defaults', () {
      final parsed = DmMessageModel.fromJson(<String, dynamic>{
        'messageId': 12,
        'conversationId': 'c-1',
        'senderId': 'user-2',
        'content': 'Hello',
        'sentAt': '2026-07-13T10:00:00Z',
        'readAt': '',
        'deletedAt': 'invalid',
      });
      final defaults = DmMessageModel.fromJson(const <String, dynamic>{});

      expect(parsed.messageId, '12');
      expect(parsed.sentAt, DateTime.utc(2026, 7, 13, 10));
      expect(parsed.readAt, isNull);
      expect(parsed.deletedAt, isNull);
      expect(parsed.messageType, 'text');
      expect(defaults.messageId, isEmpty);
      expect(defaults.content, isEmpty);
    });

    test('preview resolves username aliases and tri-state read values', () {
      final alias = DmConversationPreviewModel.fromJson(<String, dynamic>{
        'otherUserUsername': '  deniz  ',
        'lastMessageRead': 'YES',
        'lastMessageAt': '2026-07-13T10:00:00Z',
        'otherUserVisibilityMode': 'GHOST',
      });
      final numeric = DmConversationPreviewModel.fromJson(<String, dynamic>{
        'username': 'ada',
        'lastMessageRead': -1,
      });
      final unknown = DmConversationPreviewModel.fromJson(<String, dynamic>{
        'lastMessageRead': 'sometimes',
        'otherUserVisibilityMode': 'FUTURE_MODE',
      });

      expect(alias.otherUsername, 'deniz');
      expect(alias.lastMessageRead, isTrue);
      expect(alias.lastMessageAt, DateTime.utc(2026, 7, 13, 10));
      expect(alias.otherUserVisibilityMode, ListenerVisibilityMode.ghost);
      expect(alias.isOtherUserGhost, isTrue);
      expect(numeric.lastMessageRead, isTrue);
      expect(unknown.otherUsername, 'Kullanici');
      expect(unknown.lastMessageRead, isNull);
      expect(unknown.otherUserVisibilityMode, ListenerVisibilityMode.ghost);
    });
  });

  group('DmRepositoryImpl', () {
    test('gets canonical total unread DM message count over GET', () async {
      final apiClient = _DmApiClientFake(
        (method, path, query, body) => <String, dynamic>{'unreadCount': 6},
      );
      final repository = DmRepositoryImpl(apiClient);

      final result = await repository.getUnreadCount();

      expect(result.data, 6);
      expect(apiClient.lastMethod, 'GET');
      expect(apiClient.lastPath, DmEndpoints.unreadCount);
      expect(apiClient.lastQuery, isNull);
      expect(apiClient.lastBody, isNull);
    });

    test(
      'rejects malformed unread count payload instead of clearing badge',
      () async {
        final repository = DmRepositoryImpl(
          _DmApiClientFake(
            (_, __, ___, ____) => <String, dynamic>{'unreadCount': 'six'},
          ),
        );

        final result = await repository.getUnreadCount();

        expect(result.isSuccess, isFalse);
        expect(result.error?.code, 'dm_unread_count_unknown');
      },
    );

    test(
      'creates conversation with encoded user id over canonical POST',
      () async {
        const otherUserId = 'user +7';
        final apiClient = _DmApiClientFake(
          (method, path, query, body) => 'conversation-7',
        );
        final repository = DmRepositoryImpl(apiClient);

        final result = await repository.getOrCreateConversation(
          otherUserId: otherUserId,
        );

        expect(result.data, 'conversation-7');
        expect(apiClient.lastMethod, 'POST');
        expect(
          apiClient.lastPath,
          '${DmEndpoints.conversationBetween}?otherUserId='
          '${Uri.encodeQueryComponent(otherUserId)}',
        );
        expect(apiClient.lastBody, isNull);
      },
    );

    test('uses canonical message page query and send request body', () async {
      final apiClient = _DmApiClientFake((method, path, query, body) {
        if (method == 'GET') {
          return <String, dynamic>{
            'number': 3,
            'last': false,
            'content': <Object?>[
              <String, dynamic>{'messageId': 'm-1', 'conversationId': 'c-1'},
            ],
          };
        }
        return <String, dynamic>{
          'messageId': 'sent-1',
          'conversationId': 'c-1',
          'recipientId': 'u-2',
          'content': 'Hello',
        };
      });
      final repository = DmRepositoryImpl(apiClient);

      final page = await repository.getConversationMessages(
        conversationId: 'c-1',
        page: 3,
        size: 11,
      );

      expect(page.data?.items.single.messageId, 'm-1');
      expect(page.data?.nextCursor, '4');
      expect(apiClient.lastMethod, 'GET');
      expect(apiClient.lastPath, DmEndpoints.conversationMessages('c-1'));
      expect(apiClient.lastQuery, <String, dynamic>{
        'page': 3,
        'size': 11,
        'sort': 'createdAt,desc',
      });

      final sent = await repository.sendMessage(
        conversationId: 'c-1',
        recipientId: 'u-2',
        content: 'Hello',
        messageType: 'text',
      );

      expect(sent.data?.messageId, 'sent-1');
      expect(apiClient.lastMethod, 'POST');
      expect(apiClient.lastPath, DmEndpoints.messageSend);
      expect(apiClient.lastBody, <String, dynamic>{
        'conversationId': 'c-1',
        'recipientId': 'u-2',
        'content': 'Hello',
        'messageType': 'text',
      });
    });

    test('preserves typed errors and maps unexpected send payloads', () async {
      const error = AppError(code: '401', message: 'Unauthorized');
      final typedRepository = DmRepositoryImpl(
        _DmApiClientFake((_, __, ___, ____) => throw ApiException(error)),
      );
      final unknownRepository = DmRepositoryImpl(
        _DmApiClientFake((_, __, ___, ____) => 'invalid-message'),
      );

      final typedResult = await typedRepository.getMyConversations();
      final unknownResult = await unknownRepository.sendMessage(
        conversationId: 'c-1',
        recipientId: 'u-2',
        content: 'Hello',
      );

      expect(typedResult.error, same(error));
      expect(unknownResult.error?.code, 'dm_send_unknown');
    });
  });

  group('DmConversationsCubit', () {
    test(
      'filters empty previews and sorts usable conversations newest first',
      () async {
        final repository = _DmRepositoryFake(
          conversations: Result.success(<DmConversationPreview>[
            _preview('older', at: DateTime.utc(2026, 7, 12)),
            _preview('empty', includeMessage: false),
            _preview('', at: DateTime.utc(2026, 7, 14)),
            _preview('newer', at: DateTime.utc(2026, 7, 13)),
          ]),
        );
        final realtime = DmRealtimeClient();
        final cubit = DmConversationsCubit(
          repository,
          _MemoryTokenStore(),
          realtimeClient: realtime,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.dispose();
        });

        await cubit.load();

        expect(cubit.state.status, DmConversationsStatus.success);
        expect(cubit.state.items.map((item) => item.conversationId), <String>[
          'newer',
          'older',
        ]);
      },
    );
  });

  group('DmChatCubit', () {
    test(
      'sorts initial page, marks incoming messages, and deduplicates pages',
      () async {
        final oldDuplicate = _message(
          'm-1',
          senderId: 'other',
          recipientId: 'me',
          content: 'old',
          sentAt: DateTime.utc(2026, 7, 13, 10),
        );
        final repository = _DmRepositoryFake(
          conversationId: const Result.success('conversation-1'),
          messagePages: <int, Result<Page<DmMessage>>>{
            0: Result.success(
              Page<DmMessage>(
                items: <DmMessage>[
                  _message(
                    'm-2',
                    senderId: 'me',
                    recipientId: 'other',
                    sentAt: DateTime.utc(2026, 7, 13, 11),
                  ),
                  oldDuplicate,
                ],
                hasNext: true,
              ),
            ),
            1: Result.success(
              Page<DmMessage>(
                items: <DmMessage>[
                  _message(
                    'm-1',
                    senderId: 'other',
                    recipientId: 'me',
                    content: 'updated',
                    sentAt: DateTime.utc(2026, 7, 13, 10),
                    readAt: DateTime.utc(2026, 7, 13, 12),
                  ),
                  _message(
                    'm-0',
                    senderId: 'other',
                    recipientId: 'me',
                    sentAt: DateTime.utc(2026, 7, 13, 9),
                  ),
                ],
                hasNext: false,
              ),
            ),
          },
        );
        final realtime = DmRealtimeClient();
        final cubit = DmChatCubit(
          repository,
          _MemoryTokenStore(),
          realtimeClient: realtime,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.dispose();
        });

        await cubit.openOrCreateConversation(
          otherUserId: 'other',
          currentUserId: 'me',
        );
        await cubit.loadMore();

        expect(cubit.state.status, DmChatStatus.success);
        expect(cubit.state.page, 1);
        expect(cubit.state.hasNext, isFalse);
        expect(cubit.state.messages.map((item) => item.messageId), <String>[
          'm-0',
          'm-1',
          'm-2',
        ]);
        expect(
          cubit.state.messages
              .singleWhere((item) => item.messageId == 'm-1')
              .content,
          'updated',
        );
        expect(repository.markedReadIds, containsAll(<String>['m-1']));
        expect(repository.requestedPages, <int>[0, 1]);
      },
    );

    test(
      'trims outgoing content, merges response, and rejects blanks',
      () async {
        final sent = _message(
          'sent-1',
          senderId: 'me',
          recipientId: 'other',
          content: 'Hello',
          sentAt: DateTime.utc(2026, 7, 13, 12),
        );
        final repository = _DmRepositoryFake(
          conversationId: const Result.success('conversation-1'),
          messagePages: <int, Result<Page<DmMessage>>>{
            0: const Result.success(
              Page<DmMessage>(items: <DmMessage>[], hasNext: false),
            ),
          },
          sentMessage: Result.success(sent),
        );
        final realtime = DmRealtimeClient();
        final cubit = DmChatCubit(
          repository,
          _MemoryTokenStore(),
          realtimeClient: realtime,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.dispose();
        });
        await cubit.openOrCreateConversation(
          otherUserId: 'other',
          currentUserId: 'me',
        );

        final blankAccepted = await cubit.send('   ');
        final sentSuccessfully = await cubit.send('  Hello  ');

        expect(blankAccepted, isFalse);
        expect(sentSuccessfully, isTrue);
        expect(repository.sentContents, <String>['Hello']);
        expect(repository.lastMessageType, 'text');
        expect(cubit.state.messages.single, same(sent));
        expect(cubit.state.sending, isFalse);
      },
    );
  });
}

DmConversationPreview _preview(
  String conversationId, {
  DateTime? at,
  bool includeMessage = true,
}) {
  return DmConversationPreview(
    conversationId: conversationId,
    otherUserId: 'other-$conversationId',
    otherUsername: 'Other',
    otherUserProfilePicture: null,
    lastMessageContent: includeMessage ? 'Message' : null,
    lastMessageType: null,
    lastMessageSenderId: null,
    lastMessageAt: at,
    lastMessageRead: false,
  );
}

DmMessage _message(
  String id, {
  required String senderId,
  required String recipientId,
  String content = 'Message',
  DateTime? sentAt,
  DateTime? readAt,
}) {
  return DmMessage(
    messageId: id,
    conversationId: 'conversation-1',
    senderId: senderId,
    recipientId: recipientId,
    content: content,
    messageType: 'text',
    sentAt: sentAt,
    readAt: readAt,
    deletedAt: null,
  );
}

class _DmRepositoryFake implements DmRepository {
  _DmRepositoryFake({
    this.conversations = const Result.success(<DmConversationPreview>[]),
    this.conversationId = const Result.success('conversation-1'),
    this.messagePages = const <int, Result<Page<DmMessage>>>{},
    this.sentMessage,
  });

  final Result<List<DmConversationPreview>> conversations;
  final Result<String> conversationId;
  final Map<int, Result<Page<DmMessage>>> messagePages;
  final Result<DmMessage>? sentMessage;
  final List<int> requestedPages = <int>[];
  final List<String> markedReadIds = <String>[];
  final List<String> sentContents = <String>[];
  String? lastMessageType;

  @override
  Future<Result<List<DmConversationPreview>>> getMyConversations() async =>
      conversations;

  @override
  Future<Result<int>> getUnreadCount() async => const Result.success(0);

  @override
  Future<Result<String>> getOrCreateConversation({
    required String otherUserId,
  }) async => conversationId;

  @override
  Future<Result<Page<DmMessage>>> getConversationMessages({
    required String conversationId,
    int page = 0,
    int size = 30,
  }) async {
    requestedPages.add(page);
    return messagePages[page] ??
        const Result.success(Page<DmMessage>(items: [], hasNext: false));
  }

  @override
  Future<Result<void>> markMessageAsRead({required String messageId}) async {
    markedReadIds.add(messageId);
    return const Result.success(null);
  }

  @override
  Future<Result<DmMessage>> sendMessage({
    required String conversationId,
    required String recipientId,
    required String content,
    String messageType = 'text',
  }) async {
    sentContents.add(content);
    lastMessageType = messageType;
    return sentMessage ??
        Result.success(
          _message(
            'generated',
            senderId: 'me',
            recipientId: recipientId,
            content: content,
          ),
        );
  }
}

class _MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> readToken() async => value;

  @override
  Future<void> writeToken(String token) async => value = token;
}

class _DmApiClientFake extends ApiClient {
  _DmApiClientFake(this.handler);

  final FutureOr<Object?> Function(
    String method,
    String path,
    Map<String, dynamic>? query,
    Object? body,
  )
  handler;
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQuery;
  Object? lastBody;

  Future<T> _execute<T>(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    T Function(Object? json)? decoder,
  }) async {
    lastMethod = method;
    lastPath = path;
    lastQuery = query;
    lastBody = body;
    final payload = await handler(method, path, query, body);
    return decoder == null ? payload as T : decoder(payload);
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) => _execute('GET', path, query: query, decoder: decoder);

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute('POST', path, body: body, decoder: decoder);

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute('PUT', path, body: body, decoder: decoder);

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute('DELETE', path, body: body, decoder: decoder);

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute('PATCH', path, body: body, decoder: decoder);
}
