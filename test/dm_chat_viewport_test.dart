import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_message.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_chat_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/dm_chat_route_observer.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/screens/dm_chat_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/user_block/data/user_block_repository.dart';

void main() {
  Future<(_Repository, _Realtime, DmChatCubit)> openChat(
    WidgetTester tester, {
    _Blocks? blocks,
    bool refuseNewConversation = false,
  }) async {
    await serviceLocator.reset();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repository = _Repository()..refuseOpen = refuseNewConversation;
    final realtime = _Realtime();
    final cubit = DmChatCubit(
      repository,
      _Tokens(),
      realtimeClient: realtime,
      blocks: blocks,
    );
    if (blocks != null) {
      serviceLocator.registerSingleton<UserBlockRepository>(blocks);
      addTearDown(blocks.events.close);
    }
    serviceLocator.registerFactory<DmChatCubit>(() => cubit);
    repository.onRead = (id) {
      final message = repository.messages.singleWhere(
        (item) => item.messageId == id,
      );
      repository.visibleAtRead[id] = find
          .text(message.content)
          .hitTestable()
          .evaluate()
          .isNotEmpty;
    };
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await realtime.messages.close();
      await serviceLocator.reset();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [dmChatRouteObserver],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(
            arguments: DmChatScreenArgs(
              otherUserId: 'sender',
              otherUsername: 'Sender',
              currentUserId: 'recipient',
              conversationId: 'conversation',
            ),
          ),
          builder: (_) => DmChatScreen(),
        ),
      ),
    );
    return (repository, realtime, cubit);
  }

  testWidgets('lifting the last block can open a previously refused new chat', (
    tester,
  ) async {
    final blocks = _Blocks()
      ..current = const UserBlockStatus(
        blockedByMe: true,
        interactionBlocked: true,
      );
    final (repository, _, cubit) = await openChat(
      tester,
      blocks: blocks,
      refuseNewConversation: true,
    );
    await tester.pumpAndSettle();
    expect(cubit.state.conversationId, isNull);
    expect(find.byType(TextField), findsNothing);
    repository.refuseOpen = false;
    blocks.change(mine: false, blocked: false);
    await tester.pumpAndSettle();
    expect(cubit.state.conversationId, 'conversation');
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
    'blocking an open chat keeps history and a reciprocal block stays read only',
    (tester) async {
      final blocks = _Blocks();
      final (repository, _, cubit) = await openChat(tester, blocks: blocks);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      blocks.change(mine: true, blocked: true);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text(repository.messages.last.content), findsOneWidget);
      expect(await cubit.send('Yeni mesaj'), isFalse);
      expect(repository.sendCount, 0);
      blocks.change(mine: false, blocked: true);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      blocks.change(mine: false, blocked: false);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    },
  );

  testWidgets(
    'a block on the other phone disables sending on the first refused request',
    (tester) async {
      final blocks = _Blocks();
      final (repository, _, cubit) = await openChat(tester, blocks: blocks);
      await tester.pumpAndSettle();
      blocks.current = const UserBlockStatus(
        blockedByMe: false,
        interactionBlocked: true,
      );
      expect(await cubit.send('Merhaba'), isFalse);
      await tester.pumpAndSettle();
      expect(repository.sendCount, 1);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(repository.messages.last.content), findsOneWidget);
    },
  );

  testWidgets(
    'long notification conversation opens at latest rendered bubble before ACK',
    (tester) async {
      final (repository, _, _) = await openChat(tester);
      await tester.pumpAndSettle();
      final latest = repository.messages.last;
      expect(find.text(latest.content).hitTestable(), findsOneWidget);
      expect(repository.visibleAtRead[latest.messageId], isTrue);
      expect(repository.pages.where((page) => page > 0), isEmpty);
      // Opening the latest page still acknowledges its whole loaded history.
      expect(repository.visibleAtRead, hasLength(30));
    },
  );

  testWidgets(
    'scrolling to older history loads its page without jumping to latest',
    (tester) async {
      final (repository, _, cubit) = await openChat(tester);
      await tester.pumpAndSettle();
      final latest = repository.messages.last;
      for (
        var gesture = 0;
        gesture < 12 && !repository.pages.contains(1);
        gesture++
      ) {
        await tester.drag(find.byType(ListView), const Offset(0, 650));
        await tester.pumpAndSettle();
      }
      expect(repository.pages, contains(1));
      expect(cubit.state.messages, hasLength(60));
      expect(find.text(latest.content).hitTestable(), findsNothing);
      expect(repository.visibleAtRead, hasLength(60));
    },
  );

  testWidgets('warm resume from older history shows newest before its ACK', (
    tester,
  ) async {
    final (repository, _, _) = await openChat(tester);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 700));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final latest = repository.append();
    await tester.pump();
    expect(repository.visibleAtRead[latest.messageId], isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text(latest.content).hitTestable(), findsOneWidget);
    expect(repository.visibleAtRead[latest.messageId], isTrue);
  });

  testWidgets(
    'incoming live message reaches latest edge before ACK while browsing history',
    (tester) async {
      final (repository, realtime, _) = await openChat(tester);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      final latest = repository.append();
      realtime.messages.add(latest);
      await tester.pumpAndSettle();
      expect(find.text(latest.content).hitTestable(), findsOneWidget);
      expect(repository.visibleAtRead[latest.messageId], isTrue);
    },
  );
}

class _Blocks extends Fake implements UserBlockRepository {
  final events = StreamController<UserBlockChange>.broadcast(sync: true);
  var current = const UserBlockStatus(
    blockedByMe: false,
    interactionBlocked: false,
  );
  @override
  Stream<UserBlockChange> get changes => events.stream;
  @override
  Future<Result<UserBlockStatus>> status(String userId) async =>
      Result.success(current);

  void change({required bool mine, required bool blocked}) {
    current = UserBlockStatus(blockedByMe: mine, interactionBlocked: blocked);
    events.add(
      UserBlockChange(actorId: 'recipient', userId: 'sender', status: current),
    );
  }
}

class _Repository extends Fake implements DmRepository {
  bool refuseOpen = false;
  int sendCount = 0;
  @override
  Future<Result<DmMessage>> sendMessage({
    required String conversationId,
    required String recipientId,
    required String content,
    String messageType = 'text',
    String? clientMessageId,
  }) async {
    sendCount++;
    return const Result.failure(
      AppError(code: '1120', message: 'İşlem yapılamıyor.'),
    );
  }

  final messages = List.generate(60, _message);
  final pages = <int>[];
  final visibleAtRead = <String, bool>{};
  void Function(String id)? onRead;
  DmMessage append() {
    final value = _message(messages.length);
    messages.add(value);
    return value;
  }

  static DmMessage _message(int index) => DmMessage(
    messageId: 'message-$index',
    conversationId: 'conversation',
    senderId: 'sender',
    recipientId: 'recipient',
    content: 'Message $index\n${'Variable length content. ' * (index % 7 + 1)}',
    messageType: 'text',
    sentAt: DateTime.utc(2026, 9, 24).add(Duration(minutes: index)),
    readAt: null,
    deletedAt: null,
  );

  @override
  Future<Result<String>> getOrCreateConversation({
    required String otherUserId,
  }) async => refuseOpen
      ? const Result.failure(
          AppError(code: '1120', message: 'İşlem yapılamıyor.'),
        )
      : const Result.success('conversation');

  @override
  Future<Result<Page<DmMessage>>> getConversationMessages({
    required String conversationId,
    int page = 0,
    int size = 30,
  }) async {
    pages.add(page);
    final end = (messages.length - page * size).clamp(0, messages.length);
    final start = (end - size).clamp(0, end);
    return Result.success(
      Page(items: messages.sublist(start, end), hasNext: start > 0),
    );
  }

  @override
  Future<Result<void>> markMessageAsRead({required String messageId}) async {
    onRead?.call(messageId);
    return const Result.success(null);
  }
}

class _Realtime extends Fake implements DmRealtimeClient {
  final messages = StreamController<DmMessage>.broadcast();
  @override
  Stream<DmMessage> get messageStream => messages.stream;
  @override
  void retain() {}
  @override
  Future<void> release() async {}
  @override
  Future<void> connect({required String userId, required String token}) async {}
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => 'fixture-token';
}
