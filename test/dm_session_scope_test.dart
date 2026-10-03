import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/app.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_conversation_preview.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_message.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_chat_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_conversations_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';

AuthSession _session(
  String user, {
  String role = 'MUSICIAN',
  String status = 'ACTIVE',
  bool choice = false,
}) => AuthSession.authenticated(
  token: 'token-$user',
  userId: user,
  username: user,
  accountStatus: status,
  roles: ['ROLE_$role'],
  permissions: [],
  expiresAt: DateTime(2099),
  isAdmin: role == 'ADMIN' || role == 'OWNER',
  requiresListenerProfileChoice: choice,
);

void main() {
  for (final role in [
    'MUSICIAN',
    'VENUE',
    'STUDIO',
    'LISTENER',
    'ORGANIZER',
    'PRODUCER',
    'ADMIN',
    'OWNER',
  ]) {
    test('$role active DM and settings routes are shared', () {
      for (final route in [
        AppRoutes.dmConversations,
        AppRoutes.dmChat,
        AppRoutes.settings,
        AppRoutes.notifications,
      ]) {
        expect(
          AppRouteGuard.redirectFor(route, _session('a', role: role)),
          isNull,
        );
      }
    });
  }

  test('pending business and incomplete listener cannot enter DM or push', () {
    for (final session in [
      _session('a', role: 'VENUE', status: 'PENDING_VENUE_REQUEST'),
      _session('a', role: 'STUDIO', status: 'PENDING_STUDIO_REQUEST'),
      _session('a', role: 'STUDIO', status: 'REJECTED_STUDIO_REQUEST'),
      _session('a', role: 'LISTENER', choice: true),
    ]) {
      expect(AppRouteGuard.redirectFor(AppRoutes.dmChat, session), isNotNull);
      expect(shouldStartAuthenticatedSessionServices(session), isFalse);
    }
  });

  test(
    'account replacement discards the previous authenticated route stack',
    () {
      expect(
        resolveSessionChangeNavigationRoute(
          wasAuthenticated: true,
          wasListenerChoiceRequired: false,
          previousUserId: 'a',
          previousToken: 'token-a',
          current: _session('b'),
        ),
        AppRoutes.home,
      );
    },
  );

  test(
    'login before the queued logout frame still resets the old account stack',
    () {
      expect(
        resolveSessionChangeNavigationRoute(
          wasAuthenticated: false,
          wasListenerChoiceRequired: false,
          current: _session('b'),
          accountResetPending: true,
        ),
        AppRoutes.home,
      );
      expect(
        resolveSessionChangeNavigationRoute(
          wasAuthenticated: false,
          wasListenerChoiceRequired: false,
          current: _session('b'),
        ),
        isNull,
      );
    },
  );

  test(
    'ambiguous send retry keeps its key; ACK and edited messages use new keys',
    () async {
      final repository = _Repository()..failSend = true;
      final realtime = _Realtime();
      final cubit = DmChatCubit(
        repository,
        _Tokens(),
        realtimeClient: realtime,
      );
      await cubit.openOrCreateConversation(otherUserId: 'other');
      expect(await cubit.send('Hello'), isFalse);
      final first = repository.sendKeys.last;
      expect(first, matches(RegExp(r'^[0-9a-f-]{36}$')));
      repository.failSend = false;
      expect(await cubit.send('Hello'), isTrue);
      expect(repository.sendKeys.last, first);
      expect(await cubit.send('Hello'), isTrue);
      expect(repository.sendKeys.last, isNot(first));
      repository.failSend = true;
      await cubit.send('Original');
      final original = repository.sendKeys.last;
      await cubit.send('Edited');
      expect(repository.sendKeys.last, isNot(original));
      await cubit.close();
      await realtime.messages.close();
    },
  );

  test(
    'DM request retains old dispatch identity and discards its late response',
    () async {
      final sessions = _Sessions();
      final api = _Api()..pending = Completer<Object?>();
      final repository = DmRepositoryImpl(api, sessions: sessions);
      final request = repository.getMyConversations();
      expect(api.context?.expectedSessionKey, 'a');
      expect(api.context?.expectedToken, 'token-a');
      sessions.change(_session('b'));
      api.pending!.complete([]);
      expect((await request).error?.code, 'dm_session_changed');
      sessions.dispose();
    },
  );

  test('DM read mutation never dispatches after local logout', () async {
    final sessions = _Sessions()..change(const AuthSession.guest());
    final api = _Api();
    final result = await DmRepositoryImpl(
      api,
      sessions: sessions,
    ).markMessageAsRead(messageId: 'message');
    expect(result.isSuccess, isFalse);
    expect(api.calls, 0);
    sessions.dispose();
  });

  test(
    'account replacement clears old badge and cannot lose the new seed behind an old request',
    () async {
      final sessions = _Sessions();
      final tokens = _Tokens();
      final repository = _Repository()..unread = Completer<Result<int>>();
      final realtime = _Realtime();
      final cubit = DmBadgeCubit(
        repository,
        tokens,
        sessions: sessions,
        realtimeClient: realtime,
      );
      final oldStart = cubit.ensureStarted();
      await Future<void>.delayed(Duration.zero);
      tokens.user = 'b';
      sessions.change(_session('b'));
      repository.unread!.complete(const Result.success(9));
      await oldStart;
      await cubit.ensureStarted();
      expect(cubit.state.unreadCount, 2);
      expect(realtime.connectedUser, 'b');
      await cubit.close();
      await realtime.messages.close();
      await realtime.badges.close();
      await realtime.connections.close();
      sessions.dispose();
    },
  );

  test(
    'open chat clears immediately on account replacement and ignores old history',
    () async {
      final sessions = _Sessions();
      final repository = _Repository()
        ..page = Completer<Result<Page<DmMessage>>>();
      final realtime = _Realtime();
      final cubit = DmChatCubit(
        repository,
        _Tokens(),
        sessions: sessions,
        realtimeClient: realtime,
      );
      final opening = cubit.openOrCreateConversation(
        otherUserId: 'other',
        currentUserId: 'a',
      );
      await Future<void>.delayed(Duration.zero);
      sessions.change(_session('b'));
      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.conversationId, isNull);
      repository.page!.complete(
        Result.success(Page(items: [_message], hasNext: false)),
      );
      await opening;
      expect(cubit.state.messages, isEmpty);
      expect(await cubit.send('Must not use a new account'), isFalse);
      await cubit.close();
      await realtime.messages.close();
      sessions.dispose();
    },
  );

  test('message limit uses server UTF-16 boundary before dispatch', () async {
    final repository = _Repository();
    final realtime = _Realtime();
    final cubit = DmChatCubit(repository, _Tokens(), realtimeClient: realtime);
    await cubit.openOrCreateConversation(
      otherUserId: 'other',
      currentUserId: 'a',
    );
    expect(await cubit.send('😀' * 5001), isFalse);
    expect(cubit.state.error?.code, 'dm_message_too_long');
    expect(repository.sends, 0);
    await cubit.close();
    await realtime.messages.close();
  });

  test(
    'realtime preview reloads authoritative ghost and deleted identity',
    () async {
      final repository = _Repository();
      final realtime = _Realtime();
      final cubit = DmConversationsCubit(
        repository,
        _Tokens(),
        realtimeClient: realtime,
      );
      await cubit.load();
      repository.ghost = true;
      repository.deleted = true;
      realtime.messages.add(_message);
      await Future<void>.delayed(Duration.zero);
      await cubit.load();
      expect(
        cubit.state.items.single.otherUserVisibilityMode,
        ListenerVisibilityMode.ghost,
      );
      expect(cubit.state.items.single.otherUserDeleted, isTrue);
      expect(cubit.state.items.single.otherUsername, 'Anonymous');
      await cubit.close();
      await realtime.messages.close();
    },
  );

  test(
    'conversation history finishing after route disposal is ignored',
    () async {
      final repository = _Repository()
        ..conversations = Completer<Result<List<DmConversationPreview>>>();
      final realtime = _Realtime();
      final cubit = DmConversationsCubit(
        repository,
        _Tokens(),
        realtimeClient: realtime,
      );
      final loading = cubit.load();
      await cubit.close();
      repository.conversations!.complete(const Result.success([]));
      await loading;
      await realtime.messages.close();
    },
  );
}

class _Sessions extends AuthSessionManager {
  _Sessions() : super(tokenStore: _Tokens(), sessionStore: _SessionStore());
  AuthSession value = _session('a');
  @override
  AuthSession get session => value;
  void change(AuthSession next) {
    value = next;
    notifyListeners();
  }
}

class _SessionStore extends Fake implements AuthSessionStore {}

class _Tokens extends Fake implements TokenStore {
  String user = 'a';
  @override
  Future<String?> readToken() async =>
      'x.${base64Url.encode(utf8.encode(jsonEncode({'sub': user})))}.x';
}

class _Api extends Fake implements ApiClient {
  ApiRequestContext? context;
  Completer<Object?>? pending;
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
    context = requestContext;
    final payload = await pending?.future;
    return decoder == null ? payload as T : decoder(payload);
  }
}

class _Realtime extends Fake implements DmRealtimeClient {
  final messages = StreamController<DmMessage>.broadcast();
  final badges = StreamController<int>.broadcast();
  final connections = StreamController<bool>.broadcast();
  String? connectedUser;
  @override
  Stream<int> get badgeStream => badges.stream;
  @override
  Stream<bool> get connectionStream => connections.stream;
  @override
  bool get isConnected => connectedUser != null;
  @override
  Future<void> disconnect() async {
    connectedUser = null;
  }

  @override
  Stream<DmMessage> get messageStream => messages.stream;
  @override
  void retain() {}
  @override
  Future<void> release() async {}
  @override
  Future<void> connect({required String userId, required String token}) async {
    connectedUser = userId;
  }
}

const _message = DmMessage(
  messageId: 'm',
  conversationId: 'c',
  senderId: 'other',
  recipientId: 'a',
  content: 'test',
  messageType: 'text',
  sentAt: null,
  readAt: null,
  deletedAt: null,
);

class _Repository extends Fake implements DmRepository {
  Completer<Result<int>>? unread;
  int unreadReads = 0;
  @override
  Future<Result<int>> getUnreadCount() async {
    if (++unreadReads == 1 && unread != null) return unread!.future;
    return const Result.success(2);
  }

  Completer<Result<Page<DmMessage>>>? page;
  Completer<Result<List<DmConversationPreview>>>? conversations;
  bool ghost = false, deleted = false;
  int sends = 0;
  bool failSend = false;
  final sendKeys = <String?>[];
  @override
  Future<Result<String>> getOrCreateConversation({
    required String otherUserId,
  }) async => const Result.success('c');
  @override
  Future<Result<Page<DmMessage>>> getConversationMessages({
    required String conversationId,
    int page = 0,
    int size = 30,
  }) async =>
      this.page?.future ??
      const Result.success(Page(items: [], hasNext: false));
  @override
  Future<Result<List<DmConversationPreview>>> getMyConversations() async =>
      conversations?.future ??
      Result.success([
        DmConversationPreview(
          conversationId: 'c',
          otherUserId: 'other',
          otherUsername: ghost ? 'Anonymous' : 'Original',
          otherUserProfilePicture: null,
          lastMessageContent: 'test',
          lastMessageType: 'text',
          lastMessageSenderId: 'other',
          lastMessageAt: null,
          lastMessageRead: false,
          otherUserVisibilityMode: ghost
              ? ListenerVisibilityMode.ghost
              : ListenerVisibilityMode.standard,
          otherUserDeleted: deleted,
        ),
      ]);

  @override
  Future<Result<Page<DmConversationPreview>>> getMyConversationsPage({
    String? cursor,
    int size = 30,
  }) async {
    final result = await getMyConversations();
    return result.isSuccess
        ? Result.success(Page(items: result.data ?? [], hasNext: false))
        : Result.failure(result.error);
  }

  @override
  Future<Result<DmMessage>> sendMessage({
    required String conversationId,
    required String recipientId,
    required String content,
    String messageType = 'text',
    String? clientMessageId,
  }) async {
    sends++;
    sendKeys.add(clientMessageId);
    if (failSend) {
      return const Result.failure(AppError(code: 'timeout', message: 'Retry'));
    }
    return const Result.success(_message);
  }
}
