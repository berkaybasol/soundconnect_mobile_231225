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

void main() {
  test(
    'badge seeds from total unread messages, not conversation previews',
    () async {
      final repository = _BadgeRepositoryFake(
        unreadResult: Future<Result<int>>.value(const Result.success(6)),
      );
      final realtime = _BadgeRealtimeClientFake();
      final cubit = DmBadgeCubit(
        repository,
        _MemoryTokenStore(_jwt('user-1')),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.closeStreams();
      });

      await cubit.ensureStarted();

      expect(cubit.state.unreadCount, 6);
      expect(cubit.state.initialized, isTrue);
      expect(repository.unreadCountCalls, 1);
      expect(repository.conversationCalls, 0);
    },
  );

  test(
    'newer realtime badge is not overwritten by an in-flight REST seed',
    () async {
      final seedCompleter = Completer<Result<int>>();
      final repository = _BadgeRepositoryFake(
        unreadResult: seedCompleter.future,
      );
      final realtime = _BadgeRealtimeClientFake();
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
      await repository.unreadRequestStarted.future;
      realtime.emitBadge(9);
      await Future<void>.delayed(Duration.zero);
      seedCompleter.complete(const Result.success(2));
      await start;

      expect(cubit.state.unreadCount, 9);
      expect(cubit.state.initialized, isTrue);
    },
  );

  test(
    'failed realtime connection retries without duplicating the subscription',
    () async {
      final repository = _BadgeRepositoryFake(
        unreadResult: Future<Result<int>>.value(const Result.success(4)),
      );
      final realtime = _BadgeRealtimeClientFake(failConnectAttempts: 1);
      final cubit = DmBadgeCubit(
        repository,
        _MemoryTokenStore(_jwt('user-1')),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.closeStreams();
      });

      await cubit.ensureStarted();

      expect(cubit.state.unreadCount, 4);
      expect(realtime.connectCalls, 1);
      expect(realtime.badgeStreamReads, 1);
      expect(repository.unreadCountCalls, 1);

      await cubit.ensureStarted();
      await cubit.ensureStarted();

      expect(realtime.connectCalls, 2);
      expect(realtime.badgeStreamReads, 1);
      expect(repository.unreadCountCalls, 1);

      realtime.emitBadge(7);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.unreadCount, 7);
    },
  );
}

class _BadgeRepositoryFake implements DmRepository {
  _BadgeRepositoryFake({required this.unreadResult});

  final Future<Result<int>> unreadResult;
  final Completer<void> unreadRequestStarted = Completer<void>();
  int unreadCountCalls = 0;
  int conversationCalls = 0;

  @override
  Future<Result<int>> getUnreadCount() {
    unreadCountCalls += 1;
    if (!unreadRequestStarted.isCompleted) unreadRequestStarted.complete();
    return unreadResult;
  }

  @override
  Future<Result<List<DmConversationPreview>>> getMyConversations() async {
    conversationCalls += 1;
    return const Result.success(<DmConversationPreview>[]);
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

class _BadgeRealtimeClientFake extends DmRealtimeClient {
  _BadgeRealtimeClientFake({this.failConnectAttempts = 0});

  final StreamController<int> _badges = StreamController<int>.broadcast();
  int failConnectAttempts;
  int connectCalls = 0;
  int badgeStreamReads = 0;

  @override
  Stream<int> get badgeStream {
    badgeStreamReads += 1;
    return _badges.stream;
  }

  @override
  void retain() {}

  @override
  Future<void> release() async {}

  @override
  Future<void> connect({required String userId, required String token}) async {
    connectCalls += 1;
    if (failConnectAttempts > 0) {
      failConnectAttempts -= 1;
      throw StateError('controlled connection failure');
    }
  }

  @override
  Future<void> disconnect() async {}

  void emitBadge(int count) => _badges.add(count);

  Future<void> closeStreams() async {
    await _badges.close();
    await super.dispose();
  }
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
