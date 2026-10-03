import '../../../../core/push/push_provider.dart';
import 'app_notification.dart';

/// Current, authorized server projection; push/inbox snapshots never grant access.
class StudioReservationNotificationTarget {
  const StudioReservationNotificationTarget({
    required this.notificationId,
    required this.recipientId,
    required this.type,
    required this.reservationId,
    required this.roomId,
    required this.studioProfileId,
    required this.studioName,
    required this.roomName,
    required this.ownerMode,
    required this.status,
    required this.roomArchived,
    required this.completed,
    required this.startsAt,
    required this.endsAt,
    required this.zoneId,
    required this.localDate,
    required this.localEndDate,
    required this.localStartTime,
    required this.localEndTime,
  });

  final String notificationId, recipientId, type;
  final String reservationId, roomId, studioProfileId;
  final String studioName, roomName, status, zoneId;
  final String localDate, localEndDate, localStartTime, localEndTime;
  final bool ownerMode, roomArchived, completed;
  final DateTime startsAt, endsAt;

  static const statuses = {
    'PENDING_APPROVAL',
    'CONFIRMED',
    'REJECTED_BY_STUDIO',
    'CANCELLED_BY_CUSTOMER',
    'CANCELLED_BY_STUDIO',
    'EXPIRED',
  };
  static const ownerTypes = {
    'STUDIO_RESERVATION_CREATED',
    'STUDIO_RESERVATION_CONFLICTING_REQUESTS',
    'STUDIO_RESERVATION_CANCELLED_BY_CUSTOMER',
  };

  factory StudioReservationNotificationTarget.fromJson(
    Map<String, dynamic> json,
    PushTarget expected,
  ) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Invalid studio notification target');
      }
      return value.trim();
    }

    String uuid(String key) {
      final value = text(key);
      if (!PushTarget.isUuid(value)) {
        throw const FormatException('Invalid studio notification identifier');
      }
      return value.toLowerCase();
    }

    bool flag(String key) {
      final value = json[key];
      if (value is! bool) {
        throw const FormatException('Invalid studio notification state');
      }
      return value;
    }

    DateTime instant(String key) {
      final value = text(key);
      final parsed = DateTime.tryParse(value);
      if (parsed == null || !parsed.isUtc || !value.endsWith('Z')) {
        throw const FormatException('Invalid studio reservation instant');
      }
      return parsed;
    }

    String date(String key) {
      final value = text(key);
      final parsed = DateTime.tryParse(value);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
          parsed == null ||
          parsed.toIso8601String().substring(0, 10) != value) {
        throw const FormatException('Invalid studio reservation local date');
      }
      return value;
    }

    String time(String key) {
      final value = text(key);
      if (!RegExp(
        r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,9})?)?$',
      ).hasMatch(value)) {
        throw const FormatException('Invalid studio reservation local time');
      }
      return value;
    }

    final notificationId = uuid('notificationId');
    final recipientId = uuid('recipientId');
    final type = text('type');
    final status = text('status');
    final ownerMode = flag('ownerMode');
    final startsAt = instant('startsAt');
    final endsAt = instant('endsAt');
    if (!expected.isStudio ||
        notificationId != expected.notificationId.toLowerCase() ||
        recipientId != expected.recipientId.toLowerCase() ||
        type != expected.type ||
        !statuses.contains(status) ||
        ownerMode != ownerTypes.contains(type) ||
        !endsAt.isAfter(startsAt)) {
      throw const FormatException('Studio notification scope mismatch');
    }
    return StudioReservationNotificationTarget(
      notificationId: notificationId,
      recipientId: recipientId,
      type: type,
      reservationId: uuid('reservationId'),
      roomId: uuid('roomId'),
      studioProfileId: uuid('studioProfileId'),
      studioName: text('studioName'),
      roomName: text('roomName'),
      ownerMode: ownerMode,
      status: status,
      roomArchived: flag('roomArchived'),
      completed: flag('completed'),
      startsAt: startsAt,
      endsAt: endsAt,
      zoneId: text('zoneId'),
      localDate: date('localDate'),
      localEndDate: date('localEndDate'),
      localStartTime: time('localStartTime'),
      localEndTime: time('localEndTime'),
    );
  }

  /// This identity-only reference updates the loaded row by ID after server ACK.
  /// It does not replace the inbox's original notification content.
  AppNotification get notification => AppNotification(
    id: notificationId,
    recipientId: recipientId,
    type: type,
    title: '',
    message: '',
    read: false,
    createdAt: null,
    payload: {'module': 'STUDIO', 'reservationId': reservationId},
  );
}
