import '../../../../core/push/push_provider.dart';
import 'app_notification.dart';

class TableNotificationTarget {
  const TableNotificationTarget({
    required this.notification,
    required this.tableGroupId,
    required this.kind,
    required this.event,
    required this.occurredAt,
    required this.description,
    required this.tableStatus,
    required this.participantStatus,
    required this.subjectId,
    required this.applicationId,
    required this.sameApplication,
    required this.reason,
  });

  static const actions = <String, String>{
    'TABLE_JOIN_REQUEST_RECEIVED': 'JOIN_REQUEST_RECEIVED',
    'TABLE_JOIN_REQUEST_APPROVED': 'JOIN_REQUEST_APPROVED',
    'TABLE_JOIN_REQUEST_REJECTED': 'JOIN_REQUEST_REJECTED',
    'TABLE_PARTICIPANT_LEFT': 'PARTICIPANT_LEFT',
    'TABLE_REMOVED': 'PARTICIPANT_REMOVED',
    'TABLE_CANCELLED': 'CANCELLED',
    'TABLE_EXPIRED': 'EXPIRED',
  };
  final AppNotification notification;
  final String tableGroupId,
      kind,
      event,
      tableStatus,
      participantStatus,
      subjectId;
  final DateTime occurredAt;
  final String? description, applicationId, reason;
  final bool sameApplication;
  bool get pending => kind == 'PENDING_APPLICATION';
  bool get chat => kind == 'CHAT';
  bool get result => kind == 'RESULT';

  factory TableNotificationTarget.fromJson(
    Map<String, dynamic> json,
    AppNotification expected,
  ) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty || value.trim() != value) {
        throw FormatException('Invalid table target $key');
      }
      return value;
    }

    final id = text('notificationId'),
        recipient = text('recipientId'),
        type = text('type'),
        table = text('tableGroupId'),
        subject = text('subjectId'),
        kind = text('kind'),
        event = text('event'),
        tableStatus = text('tableStatus'),
        participantStatus = text('participantStatus');
    final application = json['applicationId'],
        reason = json['reason'],
        description = json['description'];
    final occurred = DateTime.tryParse(text('occurredAt'));
    final same = json['sameApplication'];
    if (id != expected.id ||
        recipient != expected.recipientId ||
        type != expected.type ||
        !actions.containsKey(type) ||
        actions[type] != event ||
        ![id, recipient, table, subject].every(PushTarget.isUuid) ||
        !const {'PENDING_APPLICATION', 'CHAT', 'RESULT'}.contains(kind) ||
        !const {'ACTIVE', 'CANCELLED', 'INACTIVE'}.contains(tableStatus) ||
        !const {
          'PENDING',
          'ACCEPTED',
          'REJECTED',
          'KICKED',
          'LEFT',
          'NOT_PRESENT',
        }.contains(participantStatus) ||
        same is! bool ||
        json['read'] is! bool ||
        occurred == null ||
        !occurred.isUtc ||
        (description != null && description is! String) ||
        (application != null && !PushTarget.isUuid(application)) ||
        (same && application == null) ||
        (type == 'TABLE_CANCELLED'
            ? !const {
                'OWNER_CANCELLED',
                'OWNER_JOINED_ANOTHER_TABLE',
              }.contains(reason)
            : reason != null) ||
        (kind != 'RESULT' && (!same || tableStatus != 'ACTIVE')) ||
        (kind == 'PENDING_APPLICATION' &&
            (type != 'TABLE_JOIN_REQUEST_RECEIVED' ||
                participantStatus != 'PENDING')) ||
        (kind == 'CHAT' &&
            (type != 'TABLE_JOIN_REQUEST_APPROVED' ||
                participantStatus != 'ACCEPTED' ||
                subject != recipient))) {
      throw const FormatException('Table notification scope mismatch');
    }
    return TableNotificationTarget(
      notification: AppNotification(
        id: id,
        recipientId: recipient,
        type: type,
        title: 'Masa bildirimi',
        message: '',
        createdAt: occurred,
        read: json['read'] as bool,
        payload: const {},
      ),
      tableGroupId: table,
      kind: kind,
      event: event,
      occurredAt: occurred,
      description: description as String?,
      tableStatus: tableStatus,
      participantStatus: participantStatus,
      subjectId: subject,
      applicationId: application as String?,
      sameApplication: same,
      reason: reason as String?,
    );
  }
}
