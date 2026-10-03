// Regression checks for gaps established by the notification audit.
// Run from SoundConnect-Frontend with flutter test --no-pub <this file>.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_message.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_chat_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_chat_state.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/dm_chat_route_observer.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/screens/dm_chat_screen.dart';

void main() {
  test(
    'late REST refresh preserves incoming realtime bubble and read ACK',
    () async {
      final repository = _Repository()..readSucceeds = true;
      final realtime = _Realtime();
      final cubit = DmChatCubit(
        repository,
        _Tokens(),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.finish();
      });
      cubit.setVisible(true);
      await cubit.openOrCreateConversation(
        otherUserId: 'sender',
        currentUserId: 'recipient',
      );
      final old = cubit.state.messages.single;
      repository.pendingPage = Completer<Result<Page<DmMessage>>>();
      final refresh = cubit.refresh();
      await Future<void>.delayed(Duration.zero);
      realtime._messages.add(
        DmMessage(
          messageId: 'during-refresh',
          conversationId: 'conversation',
          senderId: 'sender',
          recipientId: 'recipient',
          content: 'New',
          messageType: 'text',
          sentAt: DateTime.now(),
          readAt: null,
          deletedAt: null,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        cubit.state.messages
            .singleWhere((item) => item.messageId == 'during-refresh')
            .readAt,
        isNotNull,
      );
      repository.pendingPage!.complete(
        Result.success(Page(items: [old], hasNext: false)),
      );
      await refresh;
      expect(cubit.state.messages, hasLength(2));
      expect(
        cubit.state.messages
            .singleWhere((item) => item.messageId == 'during-refresh')
            .readAt,
        isNotNull,
      );
    },
  );
  testWidgets(
    'route and lifecycle visibility gate actual chat read acknowledgements',
    (tester) async {
      await serviceLocator.reset();
      final repository = _Repository()..readSucceeds = true;
      final realtime = _Realtime();
      final cubit = DmChatCubit(
        repository,
        _Tokens(),
        realtimeClient: realtime,
      );
      serviceLocator.registerFactory<DmChatCubit>(() => cubit);
      final navigator = GlobalKey<NavigatorState>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [dmChatRouteObserver],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(
              arguments: DmChatScreenArgs(
                otherUserId: 'sender',
                otherUsername: 'Sender',
                currentUserId: 'recipient',
              ),
            ),
            builder: (_) => DmChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.readAttempts, 1);
      final message = cubit.state.messages.single;
      DmMessage next(String id) => DmMessage(
        messageId: id,
        conversationId: message.conversationId,
        senderId: message.senderId,
        recipientId: message.recipientId,
        content: 'New',
        messageType: 'text',
        sentAt: DateTime.now(),
        readAt: null,
        deletedAt: null,
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      );
      await tester.pumpAndSettle();
      realtime._messages.add(next('behind-route'));
      await tester.pump();
      expect(repository.readAttempts, 1);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(repository.readAttempts, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      realtime._messages.add(next('background'));
      await tester.pump();
      expect(repository.readAttempts, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repository.readAttempts, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await realtime.finish();
      await serviceLocator.reset();
    },
  );
  test('resume repairs badge after messages arrived while offline', () async {
    final repository = _Repository();
    final realtime = _Realtime();
    final cubit = DmBadgeCubit(repository, _Tokens(), realtimeClient: realtime);
    await cubit.ensureStarted();
    expect(repository.unreadReads, 1);
    expect(cubit.state.unreadCount, 0);

    await realtime.disconnect();
    repository.unread = 5; // Five messages arrived while transport was offline.
    await cubit.reconcileAfterResume();

    expect(realtime.isConnected, isTrue);
    expect(realtime.connects, 2);
    expect(repository.unreadReads, 2);
    expect(cubit.state.unreadCount, 5);
    await cubit.close();
    await realtime.finish();
  });

  test(
    'failed read acknowledgement is surfaced and never projected as read',
    () async {
      final repository = _Repository();
      final realtime = _Realtime();
      final cubit = DmChatCubit(
        repository,
        _Tokens(),
        realtimeClient: realtime,
      );
      cubit.setVisible(true);
      await cubit.openOrCreateConversation(
        otherUserId: 'sender',
        currentUserId: 'recipient',
      );
      expect(repository.readAttempts, 1);
      expect(cubit.state.status, DmChatStatus.success);
      expect(cubit.state.error?.code, 'offline');
      expect(cubit.state.messages.single.readAt, isNull);
      await cubit.close();
      await realtime.finish();
    },
  );

  test(
    'hidden chat receives messages without marking them read; visible resume retries ACK',
    () async {
      final repository = _Repository();
      final realtime = _Realtime();
      final acknowledged = <String>[];
      final cubit = DmChatCubit(
        repository,
        _Tokens(),
        realtimeClient: realtime,
        onReadAcknowledged: acknowledged.add,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.finish();
      });
      await cubit.openOrCreateConversation(
        otherUserId: 'sender',
        currentUserId: 'recipient',
      );
      expect(repository.readAttempts, 0);
      realtime._messages.add(cubit.state.messages.single);
      await Future<void>.delayed(Duration.zero);
      expect(repository.readAttempts, 0);
      repository.readSucceeds = true;
      cubit.setVisible(true);
      await Future<void>.delayed(Duration.zero);
      expect(repository.readAttempts, 1);
      expect(acknowledged, ['message']);
      expect(cubit.state.messages.single.readAt, isNotNull);
      cubit.setVisible(false);
      realtime._messages.add(cubit.state.messages.single);
      await Future<void>.delayed(Duration.zero);
      expect(repository.readAttempts, 1);
    },
  );
}

class _Repository implements DmRepository {
  int unread = 0;
  int unreadReads = 0;
  int readAttempts = 0;
  bool readSucceeds = false;
  Completer<Result<Page<DmMessage>>>? pendingPage;

  @override
  Future<Result<int>> getUnreadCount() async {
    unreadReads++;
    return Result.success(unread);
  }

  @override
  Future<Result<String>> getOrCreateConversation({
    required String otherUserId,
  }) async => const Result.success('conversation');

  @override
  Future<Result<Page<DmMessage>>> getConversationMessages({
    required String conversationId,
    int page = 0,
    int size = 30,
  }) async => pendingPage != null
      ? await pendingPage!.future
      : Result.success(
          Page(
            items: [
              DmMessage(
                messageId: 'message',
                conversationId: 'conversation',
                senderId: 'sender',
                recipientId: 'recipient',
                content: 'hello',
                messageType: 'text',
                sentAt: DateTime.utc(2026, 9, 22),
                readAt: null,
                deletedAt: null,
              ),
            ],
            hasNext: false,
            nextCursor: null,
          ),
        );

  @override
  Future<Result<void>> markMessageAsRead({required String messageId}) async {
    readAttempts++;
    if (readSucceeds) return const Result.success(null);
    return const Result.failure(
      AppError(code: 'offline', message: 'read acknowledgement failed'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Realtime extends DmRealtimeClient {
  final _badges = StreamController<int>.broadcast();
  final _messages = StreamController<DmMessage>.broadcast();
  bool connected = false;
  int connects = 0;
  @override
  bool get isConnected => connected;
  @override
  Stream<int> get badgeStream => _badges.stream;
  @override
  Stream<DmMessage> get messageStream => _messages.stream;
  @override
  void retain() {}
  @override
  Future<void> release() async {}
  @override
  Future<void> connect({required String userId, required String token}) async {
    connects++;
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  Future<void> finish() async {
    await _badges.close();
    await _messages.close();
    await super.dispose();
  }
}

class _Tokens implements TokenStore {
  @override
  Future<String?> readToken() async {
    String encode(Map<String, dynamic> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    return '${encode({'alg': 'none'})}.${encode({'sub': 'recipient'})}.signature';
  }

  @override
  Future<void> clear() async {}
  @override
  Future<void> writeToken(String token) async {}
}
