import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_message.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_chat_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';

import 'event_audience_fakes.dart';

const counterOwner = '22222222-2222-4222-8222-222222222222';
const counterOtherOwner = '33333333-3333-4333-8333-333333333333';
const counterMessage = 'counter-message';
const counterConversation = 'counter-conversation';
const counterError = AppError(code: 'offline', message: 'Count unavailable');

AppNotification counterNotification(
  String id, {
  String? messageId,
  String owner = counterOwner,
}) => AppNotification(
  id: id,
  recipientId: owner,
  type: messageId == null ? 'SOCIAL_NEW_FOLLOWER' : 'DM_NEW_MESSAGE',
  title: id,
  message: '',
  read: false,
  createdAt: DateTime.utc(2026, 10, 7),
  payload: messageId == null
      ? const {}
      : {
          'module': 'DM',
          'messageId': messageId,
          'conversationId': counterConversation,
        },
);

class CounterTokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => 'counter-test-token';
}

class CounterRealtime extends NotificationRealtimeClient {
  final notifications = StreamController<AppNotification>.broadcast();
  @override
  Stream<AppNotification> get notificationStream => notifications.stream;
  @override
  bool get isConnected => true;
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    await notifications.close();
    await super.dispose();
  }
}

/// A count snapshot is fixed at server execution; delivery may happen later.
/// It is never derived from the client's currently loaded/changed row count.
class HeldCounterResponse {
  final response = Completer<Result<int>>();
  int? snapshot;
  void deliver() => response.complete(Result.success(snapshot!));
  void fail() => response.complete(const Result.failure(counterError));
  void throwError() => response.completeError(StateError('count transport'));
}

class CounterRepository extends Fake implements NotificationRepository {
  CounterRepository(Iterable<AppNotification> initial) : rows = [...initial];
  final List<AppNotification> rows;
  final counts = <int>[];
  final pages = <int>[];
  final deleteCalls = <String>[];
  final readCalls = <String>[];
  final pendingDeletes = <String, Completer<Result<void>>>{};
  final Queue<HeldCounterResponse> _holds = Queue();
  final Map<int, List<AppNotification>> stalePages = {};
  int activeCounts = 0;
  int maxActiveCounts = 0;
  int get unread => rows.where((item) => !item.read).length;

  HeldCounterResponse holdNextCount() {
    final held = HeldCounterResponse();
    _holds.add(held);
    return held;
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    final snapshot = unread;
    counts.add(snapshot);
    activeCounts++;
    if (activeCounts > maxActiveCounts) maxActiveCounts = activeCounts;
    try {
      if (_holds.isNotEmpty) {
        final held = _holds.removeFirst()..snapshot = snapshot;
        return await held.response.future;
      }
      return Result.success(snapshot);
    } finally {
      activeCounts--;
    }
  }

  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    pages.add(page);
    return Result.success(
      Page(
        items:
            stalePages.remove(page) ??
            rows.skip(page * size).take(size).toList(),
        hasNext: (page + 1) * size < rows.length,
      ),
    );
  }

  void commitRead(String id) {
    final index = rows.indexWhere((item) => item.id == id);
    rows[index] = rows[index].copyWith(read: true);
  }

  void commitMessageRead(String messageId) {
    for (var index = 0; index < rows.length; index++) {
      if (rows[index].type == 'DM_NEW_MESSAGE' &&
          rows[index].payload['messageId'] == messageId) {
        rows[index] = rows[index].copyWith(read: true);
      }
    }
  }

  @override
  Future<Result<void>> markAsRead({required String notificationId}) async {
    readCalls.add(notificationId);
    commitRead(notificationId);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> deleteNotification({required String notificationId}) {
    deleteCalls.add(notificationId);
    return (pendingDeletes[notificationId] = Completer<Result<void>>()).future;
  }

  void completeDelete(String id) {
    rows.removeWhere((item) => item.id == id);
    pendingDeletes.remove(id)!.complete(const Result.success(null));
  }

  void failDelete(String id) {
    pendingDeletes.remove(id)!.complete(const Result.failure(counterError));
  }

  @override
  Future<Result<int>> markAllAsRead() async {
    final changed = unread;
    for (var index = 0; index < rows.length; index++) {
      rows[index] = rows[index].copyWith(read: true);
    }
    return Result.success(changed);
  }
}

class CounterDmRealtime extends DmRealtimeClient {
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({required String userId, required String token}) async {}
  @override
  Future<void> disconnect() async {}
}

class CounterDmRepository extends Fake implements DmRepository {
  CounterDmRepository(this.notifications);
  final CounterRepository notifications;
  final readCalls = <String>[];
  final pendingReads = <String, Completer<Result<void>>>{};
  Completer<Result<Page<DmMessage>>>? heldHistory;
  void Function(String)? onRead;
  final messages = <DmMessage>[
    DmMessage(
      messageId: counterMessage,
      conversationId: counterConversation,
      senderId: 'counter-sender',
      recipientId: counterOwner,
      content: 'Visible counter regression message',
      messageType: 'text',
      sentAt: DateTime.utc(2026, 10, 7),
      readAt: null,
      deletedAt: null,
    ),
  ];

  @override
  Future<Result<String>> getOrCreateConversation({
    required String otherUserId,
  }) async => const Result.success(counterConversation);

  @override
  Future<Result<Page<DmMessage>>> getConversationMessages({
    required String conversationId,
    int page = 0,
    int size = 30,
  }) async => heldHistory != null
      ? heldHistory!.future
      : Result.success(Page(items: [...messages], hasNext: false));

  @override
  Future<Result<void>> markMessageAsRead({required String messageId}) {
    readCalls.add(messageId);
    onRead?.call(messageId);
    notifications.commitMessageRead(messageId);
    return (pendingReads[messageId] = Completer<Result<void>>()).future;
  }

  void deliverRead([String id = counterMessage]) =>
      pendingReads.remove(id)!.complete(const Result.success(null));
}

class CounterFixture {
  CounterFixture({
    List<AppNotification>? rows,
    Duration timeout = const Duration(seconds: 15),
  }) {
    repository = CounterRepository(
      rows ??
          [
            counterNotification('a', messageId: counterMessage),
            counterNotification('b'),
            counterNotification('c'),
          ],
    );
    notifications = NotificationCubit(
      repository,
      CounterTokens(),
      realtimeClient: realtime,
      sessions: sessions,
      countReconciliationTimeout: timeout,
    );
    dmRepository = CounterDmRepository(repository);
    chat = DmChatCubit(
      dmRepository,
      CounterTokens(),
      realtimeClient: dmRealtime,
      sessions: sessions,
      onReadAcknowledged: notifications.markDmMessageAsReadLocally,
    );
  }

  final sessions = AudienceTestSessions(
    audienceSession(user: counterOwner, role: 'ROLE_MUSICIAN'),
  );
  final realtime = CounterRealtime();
  final dmRealtime = CounterDmRealtime();
  late final CounterRepository repository;
  late final NotificationCubit notifications;
  late final CounterDmRepository dmRepository;
  late final DmChatCubit chat;

  AppNotification row(String id) =>
      repository.rows.singleWhere((n) => n.id == id);

  Future<void> start() => notifications.ensureStarted();

  Future<void> loadChat() async {
    chat.requirePresentedHistory();
    chat.setVisible(true);
    await chat.openOrCreateConversation(
      otherUserId: 'counter-sender',
      currentUserId: counterOwner,
    );
    expect(
      dmRepository.readCalls,
      isEmpty,
      reason: 'Loading history cannot stand in for screen presentation.',
    );
  }

  Future<void> confirmExternal(String id) {
    final notification = row(id);
    repository.commitRead(id);
    return notifications.applyConfirmedExternalRead(
      notification,
      sessions.session,
    );
  }

  Future<void> dispose() async {
    if (!chat.isClosed) await chat.close();
    await dmRealtime.dispose();
    if (!notifications.isClosed) await notifications.close();
    await realtime.dispose();
    sessions.dispose();
  }
}

Future<void> flushCounter() => Future<void>.delayed(Duration.zero);
