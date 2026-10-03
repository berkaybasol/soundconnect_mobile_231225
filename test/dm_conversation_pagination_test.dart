import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_conversation_preview.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_conversations_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_conversations_state.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/widgets/dm_conversation_pagination.dart';

const _failure = AppError(code: 'offline', message: 'Offline');
DmConversationPreview _preview(String id, {String name = 'User'}) =>
    DmConversationPreview(
      conversationId: id,
      otherUserId: 'peer-$id',
      otherUsername: name,
      otherUserProfilePicture: null,
      lastMessageContent: 'Test',
      lastMessageType: 'text',
      lastMessageSenderId: 'peer-$id',
      lastMessageAt: DateTime.utc(2026),
      lastMessageRead: false,
    );
Result<Page<DmConversationPreview>> _page(
  List<DmConversationPreview> items, [
  String? next,
]) =>
    Result.success(Page(items: items, hasNext: next != null, nextCursor: next));

void main() {
  test(
    'cursor pages expose older chats, deduplicate overlaps and keep deterministic ties',
    () async {
      final repository = _Repository(
        (cursor) async => cursor == null
            ? _page([_preview('c2'), _preview('c1')], 'older')
            : _page([_preview('c1', name: 'Updated'), _preview('c0')]),
      );
      final cubit = DmConversationsCubit(repository, _Tokens());
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.hasNext, isTrue);
      await cubit.loadMore();
      expect(repository.cursors, [null, 'older']);
      expect(cubit.state.items.map((item) => item.conversationId), [
        'c2',
        'c1',
        'c0',
      ]);
      expect(cubit.state.items[1].otherUsername, 'Updated');
      expect(cubit.state.hasNext, isFalse);
      await cubit.loadMore();
      expect(repository.cursors, hasLength(2));
    },
  );

  test(
    'failed continuation preserves visible rows and retries the same cursor',
    () async {
      var attempts = 0;
      final repository = _Repository((cursor) async {
        if (cursor == null) return _page([_preview('new')], 'older');
        if (++attempts == 1) return const Result.failure(_failure);
        return _page([_preview('old')]);
      });
      final cubit = DmConversationsCubit(repository, _Tokens());
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.loadMore();
      expect(cubit.state.items.single.conversationId, 'new');
      expect(cubit.state.loadMoreError, _failure);
      expect(cubit.state.hasNext, isTrue);
      await cubit.loadMore();
      expect(repository.cursors, [null, 'older', 'older']);
      expect(cubit.state.items, hasLength(2));
      expect(cubit.state.loadMoreError, isNull);
    },
  );

  test(
    'refresh supersedes an old continuation and resets its authoritative cursor',
    () async {
      final older = Completer<Result<Page<DmConversationPreview>>>();
      var refreshes = 0;
      final repository = _Repository((cursor) async {
        if (cursor != null) return older.future;
        return ++refreshes == 1
            ? _page([_preview('before')], 'old-cursor')
            : _page([_preview('after')], 'fresh-cursor');
      });
      final cubit = DmConversationsCubit(repository, _Tokens());
      addTearDown(cubit.close);
      await cubit.load();
      final inFlight = cubit.loadMore();
      await cubit.loadMore();
      expect(repository.cursors, [null, 'old-cursor']);
      await cubit.load();
      older.complete(_page([_preview('stale-account-data')]));
      await inFlight;
      expect(cubit.state.items.single.conversationId, 'after');
      expect(cubit.state.nextCursor, 'fresh-cursor');
      expect(cubit.state.loadingMore, isFalse);
    },
  );

  test(
    'logout immediately clears paged rows and rejects a late continuation',
    () async {
      final sessions = _Sessions();
      final older = Completer<Result<Page<DmConversationPreview>>>();
      final repository = _Repository(
        (cursor) async =>
            cursor == null ? _page([_preview('mine')], 'older') : older.future,
      );
      final cubit = DmConversationsCubit(
        repository,
        _Tokens(),
        sessions: sessions,
      );
      addTearDown(() async {
        await cubit.close();
        sessions.dispose();
      });
      await cubit.load();
      final pending = cubit.loadMore();
      sessions.becomeGuest();
      expect(cubit.state.items, isEmpty);
      older.complete(_page([_preview('old-private-row')]));
      await pending;
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.hasNext, isFalse);
      await cubit.loadMore();
      expect(repository.cursors, hasLength(2));
    },
  );

  test(
    'socket recovery refreshes missed conversations once despite repeated connected signals',
    () async {
      var calls = 0;
      final repository = _Repository(
        (_) async => _page([
          _preview(++calls == 1 ? 'before-offline' : 'missed-while-offline'),
        ]),
      );
      final realtime = _Realtime();
      final cubit = DmConversationsCubit(
        repository,
        _Tokens(),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.dispose();
      });
      await cubit.load();
      realtime.connections.add(false);
      realtime.connections.add(true);
      realtime.connections.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(repository.cursors, hasLength(2));
      expect(cubit.state.items.single.conversationId, 'missed-while-offline');
    },
  );

  test(
    'failed refresh preserves loaded conversations instead of hiding them',
    () async {
      var calls = 0;
      final repository = _Repository(
        (_) async => ++calls == 1
            ? _page([_preview('existing')], 'older')
            : const Result.failure(_failure),
      );
      final cubit = DmConversationsCubit(repository, _Tokens());
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.load();
      expect(cubit.state.items.single.conversationId, 'existing');
      expect(cubit.state.status, DmConversationsStatus.failure);
      expect(cubit.state.hasNext, isTrue);
    },
  );

  test(
    'bounded page and direct preview retain captured authentication',
    () async {
      final sessions = _Sessions();
      addTearDown(sessions.dispose);
      final api = _Api()
        ..payload = {
          'content': [_jsonPreview],
          'hasNext': true,
          'nextCursor': 'opaque-next',
        };
      final repository = DmRepositoryImpl(api, sessions: sessions);
      final page = await repository.getMyConversationsPage(
        cursor: 'opaque-old',
        size: 17,
      );
      expect(page.data?.nextCursor, 'opaque-next');
      expect(api.path, '/api/v1/user/dm/conversations/my/page');
      expect(api.query, {'size': 17, 'cursor': 'opaque-old'});
      expect(api.context?.expectedSessionKey, 'me');
      expect(api.context?.expectedToken, 'session-token');
      api.payload = _jsonPreview;
      final preview = await repository.getConversationPreview(
        conversationId: 'conversation',
      );
      expect(preview.data?.conversationId, 'conversation');
      expect(api.path, '/api/v1/user/dm/conversations/conversation/preview');
      expect(api.calls, 2);
    },
  );

  test(
    'invalid continuation and mismatched push preview fail without truncating silently',
    () async {
      final api = _Api()
        ..payload = {'content': [], 'hasNext': true, 'nextCursor': 'same'};
      final repository = DmRepositoryImpl(api);
      final page = await repository.getMyConversationsPage(cursor: 'same');
      expect(page.isSuccess, isFalse);
      api.payload = _jsonPreview;
      final preview = await repository.getConversationPreview(
        conversationId: 'different',
      );
      expect(preview.isSuccess, isFalse);
    },
  );

  testWidgets(
    'older chats remain reachable and continuation error has a working retry',
    (tester) async {
      var loads = 0, refreshes = 0;
      var state = const DmConversationsState.idle().copyWith(
        status: DmConversationsStatus.success,
        hasNext: true,
        nextCursor: 'older',
      );
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DmConversationPagination(
              state: state,
              onLoadMore: () {
                loads++;
              },
              onRefresh: () {
                refreshes++;
              },
            ),
          ),
        ),
      );
      await show();
      await tester.tap(find.text('Daha eski konuşmalar'));
      expect(loads, 1);
      state = state.copyWith(loadingMore: true);
      await show();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      state = state.copyWith(loadingMore: false, loadMoreError: _failure);
      await show();
      expect(find.text('Eski konuşmalar yüklenemedi.'), findsOneWidget);
      await tester.tap(find.text('Tekrar dene'));
      expect(loads, 2);
      state = state.copyWith(
        status: DmConversationsStatus.failure,
        error: _failure,
      );
      await show();
      await tester.tap(find.text('Tekrar dene'));
      expect(refreshes, 1);
      state = state.copyWith(
        status: DmConversationsStatus.success,
        hasNext: false,
        loadMoreError: null,
      );
      await show();
      expect(find.byType(TextButton), findsNothing);
    },
  );
}

const _jsonPreview = {
  'conversationId': 'conversation',
  'otherUserId': 'peer',
  'otherUsername': 'User',
};

class _Repository extends Fake implements DmRepository {
  _Repository(this.fetch);
  final Future<Result<Page<DmConversationPreview>>> Function(String?) fetch;
  final cursors = <String?>[];
  @override
  Future<Result<Page<DmConversationPreview>>> getMyConversationsPage({
    String? cursor,
    int size = 30,
  }) {
    cursors.add(cursor);
    return fetch(cursor);
  }
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => null;
}

class _Realtime extends DmRealtimeClient {
  final connections = StreamController<bool>.broadcast();
  @override
  Stream<bool> get connectionStream => connections.stream;
  @override
  Future<void> dispose() async {
    await connections.close();
    await super.dispose();
  }
}

class _Store extends Fake implements AuthSessionStore {}

class _Sessions extends AuthSessionManager {
  _Sessions() : super(tokenStore: _Tokens(), sessionStore: _Store());
  AuthSession value = AuthSession.authenticated(
    token: 'session-token',
    userId: 'me',
    username: 'me',
    accountStatus: 'ACTIVE',
    roles: ['ROLE_MUSICIAN'],
    permissions: [],
    expiresAt: DateTime(2099),
    isAdmin: false,
  );
  @override
  AuthSession get session => value;
  void becomeGuest() {
    value = const AuthSession.guest();
    notifyListeners();
  }
}

class _Api extends Fake implements ApiClient {
  Object? payload;
  String? path;
  Map<String, dynamic>? query;
  ApiRequestContext? context;
  int calls = 0;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls++;
    this.path = path;
    this.query = query;
    context = requestContext;
    return decoder!(payload);
  }
}
