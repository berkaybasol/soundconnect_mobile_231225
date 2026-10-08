import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart'
    as pagination;
import 'package:soundconnect_23_12_25codx/core/realtime/stomp_realtime_transport.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_create_request.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_message_model.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_chat_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_game.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_message.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_participant.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_lifecycle.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_game_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/table_group_profile_draft.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_colors.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import '../../../support/event_audience_fakes.dart';

part 'table_group_detail_lifecycle_test_register_table_group_detail_lifecycle1.dart';
part 'table_group_detail_lifecycle_test_register_table_group_detail_lifecycle2.dart';
part 'table_group_detail_lifecycle_test_register_table_group_detail_lifecycle3.dart';

void main() {
  _registerTableGroupDetailLifecycle1();
  _registerTableGroupDetailLifecycle2();
  _registerTableGroupDetailLifecycle3();
}

TableGroupMessage _expiringGameMessage({
  required DateTime now,
  required DateTime deadline,
}) {
  return TableGroupMessageModel.fromWireJson(<String, dynamic>{
    'messageId': 'game-message-1',
    'tableGroupId': 'g-1',
    'senderId': 'owner',
    'content': 'Hesap Kimde oyunu',
    'messageType': 'GAME',
    'sentAt': now.toIso8601String(),
    'deletedAt': null,
    'game': <String, dynamic>{
      'schemaVersion': 1,
      'gameId': 'game-1',
      'tableGroupId': 'g-1',
      'revision': 1,
      'topic': 'WHO_PAYS',
      'mode': 'DICE',
      'status': 'IN_PROGRESS',
      'phase': 'DICE',
      'createdBy': 'owner',
      'createdByUsername': 'Owner',
      'round': 1,
      'joinDeadlineAt': null,
      'actionDeadlineAt': deadline.toIso8601String(),
      'serverTime': now.toIso8601String(),
      'players': <Object?>[
        <String, dynamic>{
          'userId': 'owner',
          'username': 'Owner',
          'status': 'ACTIVE',
          'joinedAt': now.toIso8601String(),
          'hasActed': false,
        },
      ],
      'revealedActions': <Object?>[],
      'selectedUserId': null,
      'selectedUsername': null,
      'outcome': null,
      'resultMessage': null,
      'cancellationReason': null,
    },
  });
}

TableGroupMessage _lobbyGameMessage({
  required String gameId,
  required DateTime sentAt,
}) {
  return TableGroupMessageModel.fromWireJson(<String, dynamic>{
    'messageId': 'message-$gameId',
    'tableGroupId': 'g-1',
    'senderId': 'owner',
    'content': 'Hesap Kimde oyunu',
    'messageType': 'GAME',
    'sentAt': sentAt.toIso8601String(),
    'deletedAt': null,
    'game': <String, dynamic>{
      'schemaVersion': 1,
      'gameId': gameId,
      'tableGroupId': 'g-1',
      'revision': 1,
      'topic': 'WHO_PAYS',
      'mode': 'DICE',
      'status': 'LOBBY',
      'phase': 'LOBBY',
      'createdBy': 'owner',
      'createdByUsername': 'Owner',
      'round': 0,
      'joinDeadlineAt': sentAt
          .add(const Duration(minutes: 3))
          .toIso8601String(),
      'actionDeadlineAt': null,
      'serverTime': sentAt.toIso8601String(),
      'players': <Object?>[
        <String, dynamic>{
          'userId': 'owner',
          'username': 'Owner',
          'status': 'ACTIVE',
          'joinedAt': sentAt.toIso8601String(),
          'hasActed': false,
        },
      ],
      'revealedActions': <Object?>[],
      'selectedUserId': null,
      'selectedUsername': null,
      'outcome': null,
      'resultMessage': null,
      'cancellationReason': null,
    },
  });
}

TableGroup _group({
  required String status,
  required DateTime? expiresAt,
  DateTime? meetingAt,
  String? description,
  String? venueName = 'Test Mekani',
  bool includeGuest = false,
  bool includePending = false,
  String pendingUsername = 'Pending User',
  int extraPendingCount = 0,
  int maxPersonCount = 4,
}) {
  return TableGroup(
    id: 'g-1',
    ownerId: 'owner',
    ownerUsername: 'Owner',
    ownerProfileImageUrl: null,
    venueId: null,
    venueName: venueName,
    description: description,
    maxPersonCount: maxPersonCount,
    genderPrefs: const <String>[],
    ageMin: 18,
    ageMax: 99,
    meetingAt: meetingAt,
    expiresAt: expiresAt,
    status: status,
    participants: <TableGroupParticipant>[
      const TableGroupParticipant(
        userId: 'owner',
        joinedAt: null,
        status: TableGroupParticipantStatus.accepted,
        joinNote: null,
        username: 'Owner',
        profilePictureUrl: null,
      ),
      if (includeGuest)
        const TableGroupParticipant(
          userId: 'guest',
          joinedAt: null,
          status: TableGroupParticipantStatus.accepted,
          joinNote: null,
          username: 'Guest',
          profilePictureUrl: null,
        ),
      if (includePending)
        TableGroupParticipant(
          userId: 'pending-user',
          joinedAt: null,
          status: TableGroupParticipantStatus.pending,
          joinNote: '21:00 gibi oradayim',
          username: pendingUsername,
          profilePictureUrl: null,
        ),
      for (var index = 0; index < extraPendingCount; index += 1)
        TableGroupParticipant(
          userId: 'pending-extra-$index',
          joinedAt: null,
          status: TableGroupParticipantStatus.pending,
          joinNote: 'Ek katilim notu $index',
          username: 'Pending Extra $index',
          profilePictureUrl: null,
        ),
    ],
    city: const TableGroupLocation(id: 'city-1', name: 'Istanbul'),
    district: const TableGroupLocation(id: 'district-1', name: 'Kadikoy'),
    neighborhood: null,
  );
}

class _DetailRepository implements TableGroupRepository {
  _DetailRepository({
    required this.group,
    this.messages = const <TableGroupMessage>[],
    this.sendFailuresRemaining = 0,
  });

  final TableGroup group;
  final List<TableGroupMessage> messages;
  int sendFailuresRemaining;
  final List<String> sentChatContents = <String>[];
  final List<String?> sentClientMessageIds = <String?>[];
  int chatCalls = 0;
  int kickCalls = 0;
  int joinCalls = 0;
  int approveCalls = 0;
  int rejectCalls = 0;
  String? lastKickedParticipantId;
  Completer<Result<pagination.Page<TableGroupMessage>>>? nextChatResponse;

  @override
  Future<Result<TableGroup>> getDetail(String tableGroupId) async =>
      Result.success(group);

  @override
  Future<Result<pagination.Page<TableGroupMessage>>> getChatMessages({
    required String tableGroupId,
    int page = 0,
    int size = 30,
  }) async {
    chatCalls += 1;
    final blocked = nextChatResponse;
    if (blocked != null) {
      nextChatResponse = null;
      return blocked.future;
    }
    return Result.success(
      pagination.Page<TableGroupMessage>(items: messages, hasNext: false),
    );
  }

  @override
  Future<Result<void>> approveJoinRequest({
    required String tableGroupId,
    required String participantId,
  }) async {
    approveCalls += 1;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> cancelTableGroup({required String tableGroupId}) async =>
      const Result.success(null);

  @override
  Future<Result<TableGroup>> createTableGroup(
    TableGroupCreateRequest request,
  ) async => Result.success(group);

  @override
  Future<Result<int>> getUnreadBadge({required String tableGroupId}) async =>
      const Result.success(0);

  @override
  Future<Result<void>> joinTableGroup({
    required String tableGroupId,
    String? note,
  }) async {
    joinCalls += 1;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> kickParticipant({
    required String tableGroupId,
    required String participantId,
  }) async {
    kickCalls += 1;
    lastKickedParticipantId = participantId;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> leaveTableGroup({required String tableGroupId}) async =>
      const Result.success(null);

  @override
  Future<Result<pagination.Page<TableGroup>>> listActiveTableGroups({
    required String? cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(
    pagination.Page<TableGroup>(items: <TableGroup>[], hasNext: false),
  );

  @override
  Future<Result<pagination.Page<TableGroup>>> listMyActiveTableGroups({
    int page = 0,
    int size = 50,
  }) async => const Result.success(
    pagination.Page<TableGroup>(items: <TableGroup>[], hasNext: false),
  );

  @override
  Future<Result<void>> rejectJoinRequest({
    required String tableGroupId,
    required String participantId,
  }) async {
    rejectCalls += 1;
    return const Result.success(null);
  }

  @override
  Future<Result<TableGroupMessage>> sendChatMessage({
    required String tableGroupId,
    required String content,
    required String clientMessageId,
  }) async {
    sentChatContents.add(content);
    sentClientMessageIds.add(clientMessageId);
    if (sendFailuresRemaining > 0) {
      sendFailuresRemaining -= 1;
      return const Result.failure(
        AppError(code: 'network', message: 'Response was lost'),
      );
    }
    return Result.success(
      TableGroupMessage(
        messageId: 'm-1',
        tableGroupId: tableGroupId,
        senderId: 'owner',
        clientMessageId: clientMessageId,
        content: content,
        messageType: 'TEXT',
        sentAt: DateTime.now().toUtc(),
        deletedAt: null,
      ),
    );
  }
}

class _ExpiryGameRepository extends _NoActiveGameRepository {
  _ExpiryGameRepository(this.activeMessage);

  final TableGroupMessage activeMessage;
  int activeCalls = 0;
  int detailCalls = 0;

  @override
  Future<Result<TableGroupMessage?>> getActiveGame({
    required String tableGroupId,
  }) async {
    activeCalls += 1;
    return Result<TableGroupMessage?>.success(activeMessage);
  }

  @override
  Future<Result<TableGroupMessage>> getGame({
    required String tableGroupId,
    required String gameId,
  }) async {
    detailCalls += 1;
    return const Result<TableGroupMessage>.failure(
      AppError(code: 'network', message: 'Temporary failure'),
    );
  }
}

class _NoActiveGameRepository implements TableGroupGameRepository {
  const _NoActiveGameRepository();

  static const _unavailable = Result<TableGroupMessage>.failure(
    AppError(code: 'test', message: 'Unavailable in this test'),
  );

  @override
  Future<Result<TableGroupMessage?>> getActiveGame({
    required String tableGroupId,
  }) async => const Result<TableGroupMessage?>.success(null);

  @override
  Future<Result<TableGroupMessage>> getGame({
    required String tableGroupId,
    required String gameId,
  }) async => _unavailable;

  @override
  Future<Result<TableGroupMessage>> createGame({
    required String tableGroupId,
    required String requestId,
    required TableGroupGameMode mode,
  }) async => _unavailable;

  @override
  Future<Result<TableGroupMessage>> joinGame({
    required String tableGroupId,
    required String gameId,
  }) async => _unavailable;

  @override
  Future<Result<TableGroupMessage>> leaveGame({
    required String tableGroupId,
    required String gameId,
  }) async => _unavailable;

  @override
  Future<Result<TableGroupMessage>> startGame({
    required String tableGroupId,
    required String gameId,
  }) async => _unavailable;

  @override
  Future<Result<TableGroupMessage>> cancelGame({
    required String tableGroupId,
    required String gameId,
  }) async => _unavailable;

  @override
  Future<Result<TableGroupMessage>> submitAction({
    required String tableGroupId,
    required String gameId,
    required String requestId,
    required TableGroupGameAction action,
    String? targetUserId,
  }) async => _unavailable;
}

class _FailingActiveGameRepository extends _NoActiveGameRepository {
  const _FailingActiveGameRepository();

  @override
  Future<Result<TableGroupMessage?>> getActiveGame({
    required String tableGroupId,
  }) async => const Result<TableGroupMessage?>.failure(
    AppError(code: 'network', message: 'Temporary active-game failure'),
  );
}

class _OwnerTokenStore implements TokenStore {
  const _OwnerTokenStore();

  @override
  Future<void> clear() async {}

  @override
  Future<String?> readToken() async => 'e30.eyJzdWIiOiJvd25lciJ9.signature';

  @override
  Future<void> writeToken(String token) async {}
}

class _DetailDmRepository extends Fake implements DmRepository {
  @override
  Future<Result<int>> getUnreadCount() async => const Result.success(0);
}

class _DetailNoopDmRealtimeClient extends DmRealtimeClient {
  @override
  Stream<int> get badgeStream => const Stream<int>.empty();

  @override
  Future<void> connect({required String userId, required String token}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void retain() {}

  @override
  Future<void> release() async {}
}

class _UserTokenStore implements TokenStore {
  const _UserTokenStore(this.userId);

  final String userId;

  @override
  Future<void> clear() async {}

  @override
  Future<String?> readToken() async {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode(<String, String>{'sub': userId})))
        .replaceAll('=', '');
    return 'e30.$payload.signature';
  }

  @override
  Future<void> writeToken(String token) async {}
}

class _ImmediateTransportHarness {
  int created = 0;
  _ImmediateTransport? latest;

  RealtimeTransport create(RealtimeTransportConfig config) {
    created += 1;
    final transport = _ImmediateTransport(config);
    latest = transport;
    return transport;
  }
}

class _TrackingTableGroupChatRealtimeClient
    extends TableGroupChatRealtimeClient {
  _TrackingTableGroupChatRealtimeClient({required super.transportFactory});

  int disconnectCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> disconnect() {
    disconnectCalls += 1;
    return super.disconnect();
  }

  @override
  Future<void> dispose() {
    disposeCalls += 1;
    return super.dispose();
  }
}

class _ImmediateTransport implements RealtimeTransport {
  _ImmediateTransport(this.config);

  final RealtimeTransportConfig config;
  final Map<String, RealtimeMessageCallback> subscriptions =
      <String, RealtimeMessageCallback>{};
  bool deactivated = false;

  @override
  void activate() => config.onConnect();

  @override
  void deactivate() {
    deactivated = true;
  }

  @override
  void send({required String destination, required String body}) {}

  void deliver(String destination, String body) {
    final callback = subscriptions[destination];
    if (callback == null) throw StateError('Missing $destination subscription');
    callback(body);
  }

  @override
  void subscribe({
    required String destination,
    required RealtimeMessageCallback callback,
  }) {
    subscriptions[destination] = callback;
  }
}
