import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/core/realtime/realtime_client_error.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/table_notification_target.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_direct_open.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/table_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_participant.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_message.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_game_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_chat_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_list_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/cubit/table_group_list_cubit.dart';
import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

part 'table_notification_target_test_register_table_notification_target1.dart';
part 'table_notification_target_test_register_table_notification_target2.dart';
part 'table_notification_target_test_cases.dart';

const recipient = '10000000-0000-0000-0000-000000000001';

const applicant = '20000000-0000-0000-0000-000000000001';

const tableId = '30000000-0000-0000-0000-000000000001';

const cycleId = '40000000-0000-0000-0000-000000000001';

const notificationId = '50000000-0000-0000-0000-000000000001';

const siblingId = '50000000-0000-0000-0000-000000000002';

const fail = AppError(code: 'unavailable', message: 'Temporary failure');

AppNotification item(
  String id, {
  String type = 'TABLE_JOIN_REQUEST_REJECTED',
}) => AppNotification(
  id: id,
  recipientId: recipient,
  type: type,
  title: 'Masa bildirimi',
  message: '',
  read: false,
  createdAt: DateTime.utc(2026, 9, 30),
  payload: const {'tableGroupId': 'untrusted'},
);

Map<String, dynamic> targetJson({
  String type = 'TABLE_JOIN_REQUEST_REJECTED',
  String kind = 'RESULT',
  String id = notificationId,
  String? reason,
}) => {
  'notificationId': id,
  'recipientId': recipient,
  'type': type,
  'tableGroupId': tableId,
  'kind': kind,
  'event': TableNotificationTarget.actions[type],
  'occurredAt': '2026-09-30T10:00:00Z',
  'description': 'Güncel görev masası',
  'tableStatus': type == 'TABLE_CANCELLED'
      ? 'CANCELLED'
      : type == 'TABLE_EXPIRED'
      ? 'INACTIVE'
      : 'ACTIVE',
  'participantStatus': kind == 'PENDING_APPLICATION'
      ? 'PENDING'
      : kind == 'CHAT' || type == 'TABLE_CANCELLED' || type == 'TABLE_EXPIRED'
      ? 'ACCEPTED'
      : 'REJECTED',
  'subjectId': kind == 'PENDING_APPLICATION' ? applicant : recipient,
  'applicationId': cycleId,
  'sameApplication': true,
  'reason': reason,
  'read': false,
};

void main() {
  _TableNotificationTargetCases().register();
}

class _Inbox extends Fake implements NotificationRepository {
  List<AppNotification> items = [item(notificationId), item(siblingId)];
  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async => Result.success(Page(items: items, hasNext: false));
  @override
  Future<Result<int>> getUnreadCount() async =>
      Result.success(items.where((i) => !i.read).length);
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async =>
      'x.${base64Url.encode(utf8.encode(jsonEncode({'sub': recipient, 'userId': recipient, 'exp': 4102444800})))}.x';
}

class _Realtime extends NotificationRealtimeClient {
  @override
  Stream<AppNotification> get notificationStream => const Stream.empty();
  @override
  Stream<int> get badgeStream => const Stream.empty();
  @override
  Stream<void> get connectionStream => const Stream.empty();
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({required String userId, required String token}) async {}
  @override
  Future<void> disconnect() async {}
}

class _Tables extends Fake implements TableGroupRepository {
  _Tables(this.group);
  final TableGroup group;
  @override
  Future<Result<TableGroup>> getDetail(String id) async =>
      Result.success(group);
}

class _Games extends Fake implements TableGroupGameRepository {
  @override
  Future<Result<TableGroupMessage?>> getActiveGame({
    required String tableGroupId,
  }) async => const Result.success(null);
}

class _ChatRealtime extends TableGroupChatRealtimeClient {
  @override
  Stream<TableGroupMessage> get messageStream => const Stream.empty();
  @override
  Stream<void> get connectionStream => const Stream.empty();
  @override
  Stream<RealtimeClientError> get errorStream => const Stream.empty();
  @override
  bool get isConnected => true;
  @override
  String? get connectedTableGroupId => tableId;
  @override
  Future<void> connect({
    required String tableGroupId,
    required String token,
  }) async {}
  @override
  Future<void> disconnect() async {}
}

class _TableFeed extends Fake implements TableGroupRepository {
  _TableFeed(this.target, {this.unavailable});
  final Map<String, dynamic> Function() target;
  final bool Function()? unavailable;

  @override
  Future<Result<TableGroup>> getDetail(String id) async {
    if (unavailable?.call() == true) return const Result.failure(fail);
    final value = target();
    final owner =
        const {
          'JOIN_REQUEST_RECEIVED',
          'PARTICIPANT_LEFT',
        }.contains(value['event'])
        ? recipient
        : applicant;
    return Result.success(
      TableGroup(
        id: id,
        ownerId: owner,
        ownerUsername: 'Owner',
        ownerProfileImageUrl: null,
        venueId: null,
        venueName: null,
        description: 'Güncel görev masası',
        maxPersonCount: 6,
        genderPrefs: const [],
        ageMin: 18,
        ageMax: 99,
        meetingAt: DateTime.utc(2030),
        expiresAt: DateTime.utc(2030, 1, 2),
        status: value['tableStatus'] as String,
        participants: [
          TableGroupParticipant(
            userId: owner,
            status: TableGroupParticipantStatus.accepted,
            joinedAt: DateTime.utc(2026),
            joinNote: null,
            username: 'Owner',
            profilePictureUrl: null,
          ),
        ],
        city: const TableGroupLocation(id: 'city', name: 'City'),
        district: null,
        neighborhood: null,
      ),
    );
  }

  @override
  Future<Result<Page<TableGroup>>> listActiveTableGroups({
    required String? cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(Page(items: [], hasNext: false));
}

class _Locations extends Fake implements LocationRepository {
  @override
  Future<Result<List<City>>> getCities() async => const Result.success([]);
}

class _DmRepository extends Fake implements DmRepository {}

class _DmBadge extends DmBadgeCubit {
  _DmBadge() : super(_DmRepository(), _Tokens());

  @override
  Future<void> ensureStarted() async {}
}

class _Routes extends NavigatorObserver {
  final List<Route<dynamic>> stack = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stack.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = stack.indexOf(oldRoute!);
    if (index != -1 && newRoute != null) stack[index] = newRoute;
  }
}
