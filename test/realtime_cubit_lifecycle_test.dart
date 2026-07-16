import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_conversation_preview.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_message.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';

void main() {
  test(
    'notification restart is not lost behind an invalidated start',
    () async {
      final realtime = _ControlledNotificationRealtimeClient();
      final repository = _NotificationRepositoryFake();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(_jwt('user-1')),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.closeStreams();
      });

      final firstStart = cubit.ensureStarted();
      await realtime.firstConnectStarted.future;
      await cubit.stop();
      final restarted = cubit.ensureStarted();

      realtime.allowConnect.complete();
      await Future.wait<void>(<Future<void>>[firstStart, restarted]);

      expect(realtime.connectCalls, 2);
      expect(realtime.connected, isTrue);
      expect(cubit.state.initialized, isTrue);
      expect(repository.listCalls, 1);
    },
  );

  test('DM delayed connect cannot revive realtime after logout', () async {
    final realtime = _ControlledDmRealtimeClient();
    final repository = _DmRepositoryFake();
    final cubit = DmBadgeCubit(
      repository,
      _MemoryTokenStore(_jwt('user-1')),
      realtimeClient: realtime,
    );
    addTearDown(() async {
      await cubit.close();
      await realtime.closeStreams();
    });

    final start = cubit.ensureStarted();
    await realtime.firstConnectStarted.future;
    await cubit.stop();
    realtime.allowConnect.complete();
    await start;

    expect(realtime.connected, isFalse);
    expect(realtime.disconnectCalls, greaterThanOrEqualTo(2));
    expect(repository.conversationCalls, 0);
    expect(cubit.state.initialized, isFalse);
  });
}

class _ControlledNotificationRealtimeClient extends NotificationRealtimeClient {
  final notificationController = StreamController<AppNotification>.broadcast();
  final badgeController = StreamController<int>.broadcast();
  final firstConnectStarted = Completer<void>();
  final allowConnect = Completer<void>();
  int connectCalls = 0;
  int disconnectCalls = 0;
  bool connected = false;

  @override
  Stream<AppNotification> get notificationStream =>
      notificationController.stream;

  @override
  Stream<int> get badgeStream => badgeController.stream;

  @override
  void retain() {}

  @override
  Future<void> release() async {}

  @override
  Future<void> connect({required String userId, required String token}) async {
    connectCalls += 1;
    if (!firstConnectStarted.isCompleted) firstConnectStarted.complete();
    await allowConnect.future;
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    connected = false;
  }

  Future<void> closeStreams() async {
    await super.dispose();
    await notificationController.close();
    await badgeController.close();
  }
}

class _ControlledDmRealtimeClient extends DmRealtimeClient {
  final badgeController = StreamController<int>.broadcast();
  final firstConnectStarted = Completer<void>();
  final allowConnect = Completer<void>();
  int connectCalls = 0;
  int disconnectCalls = 0;
  bool connected = false;

  @override
  Stream<int> get badgeStream => badgeController.stream;

  @override
  void retain() {}

  @override
  Future<void> release() async {}

  @override
  Future<void> connect({required String userId, required String token}) async {
    connectCalls += 1;
    if (!firstConnectStarted.isCompleted) firstConnectStarted.complete();
    await allowConnect.future;
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    connected = false;
  }

  Future<void> closeStreams() async {
    await super.dispose();
    await badgeController.close();
  }
}

class _NotificationRepositoryFake implements NotificationRepository {
  int listCalls = 0;

  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    listCalls += 1;
    return const Result<Page<AppNotification>>.success(
      Page<AppNotification>(items: <AppNotification>[], hasNext: false),
    );
  }

  @override
  Future<Result<int>> getUnreadCount() async => const Result.success(0);

  @override
  Future<Result<List<AppNotification>>> getRecentNotifications() async =>
      const Result.success(<AppNotification>[]);

  @override
  Future<Result<int>> clearAllNotifications() async => const Result.success(0);

  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async => const Result.success(null);

  @override
  Future<Result<int>> markAllAsRead() async => const Result.success(0);

  @override
  Future<Result<void>> markAsRead({required String notificationId}) async =>
      const Result.success(null);
}

class _DmRepositoryFake implements DmRepository {
  int conversationCalls = 0;
  int unreadCountCalls = 0;

  @override
  Future<Result<List<DmConversationPreview>>> getMyConversations() async {
    conversationCalls += 1;
    return const Result.success(<DmConversationPreview>[]);
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    unreadCountCalls += 1;
    return const Result.success(0);
  }

  @override
  Future<Result<Page<DmMessage>>> getConversationMessages({
    required String conversationId,
    int page = 0,
    int size = 30,
  }) => throw UnimplementedError();

  @override
  Future<Result<String>> getOrCreateConversation({
    required String otherUserId,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> markMessageAsRead({required String messageId}) =>
      throw UnimplementedError();

  @override
  Future<Result<DmMessage>> sendMessage({
    required String conversationId,
    required String recipientId,
    required String content,
    String messageType = 'text',
  }) => throw UnimplementedError();
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore(this.token);

  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token) async => this.token = token;
}

String _jwt(String subject) {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode(const <String, dynamic>{'alg': 'none'})}.'
      '${encode(<String, dynamic>{'sub': subject})}.signature';
}
