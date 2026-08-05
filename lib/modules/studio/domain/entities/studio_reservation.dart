import 'studio_room.dart';
import 'studio_page.dart';

enum StudioReservationStatus {
  pendingApproval,
  confirmed,
  rejectedByStudio,
  cancelledByCustomer,
  cancelledByStudio,
  expired;

  bool get isPending => this == StudioReservationStatus.pendingApproval;
  bool get isConfirmed => this == StudioReservationStatus.confirmed;
  bool get isTerminal => switch (this) {
    StudioReservationStatus.pendingApproval ||
    StudioReservationStatus.confirmed => false,
    _ => true,
  };

  static StudioReservationStatus fromApi(Object? value) {
    return switch (value?.toString().trim().toUpperCase()) {
      'CONFIRMED' => StudioReservationStatus.confirmed,
      'REJECTED_BY_STUDIO' => StudioReservationStatus.rejectedByStudio,
      'CANCELLED_BY_CUSTOMER' => StudioReservationStatus.cancelledByCustomer,
      'CANCELLED_BY_STUDIO' => StudioReservationStatus.cancelledByStudio,
      'EXPIRED' => StudioReservationStatus.expired,
      'PENDING_APPROVAL' => StudioReservationStatus.pendingApproval,
      final unknown => throw FormatException(
        'Unknown reservation status: $unknown',
      ),
    };
  }
}

enum StudioOccupancyType {
  reservation,
  manualBlock;

  static StudioOccupancyType fromApi(Object? value) => switch (value
      ?.toString()
      .trim()
      .toUpperCase()) {
    'MANUAL_BLOCK' => StudioOccupancyType.manualBlock,
    'RESERVATION' => StudioOccupancyType.reservation,
    final unknown => throw FormatException('Unknown occupancy type: $unknown'),
  };
}

class StudioReservation {
  const StudioReservation({
    required this.id,
    required this.clientRequestId,
    required this.roomId,
    required this.startsAt,
    required this.endsAt,
    required this.zoneId,
    required this.status,
    required this.completed,
    required this.approvalRequired,
    required this.hourlyPriceMinor,
    required this.totalPriceMinor,
    required this.currency,
    required this.version,
    this.studioProfileId,
    this.roomName,
    this.requesterId,
    this.requesterPublicCode,
    this.requesterPhone,
    this.requesterUsername,
    this.requesterAvatarUrl,
    this.localDate,
    this.localStartTime,
    this.localEndTime,
  });

  final String id;
  final String clientRequestId;
  final String roomId;
  final String? studioProfileId;
  final String? roomName;
  final String? requesterId;
  final String? requesterPublicCode;
  final String? requesterPhone;
  final String? requesterUsername;
  final String? requesterAvatarUrl;
  final DateTime startsAt;
  final DateTime endsAt;
  final String zoneId;
  final String? localDate;
  final String? localStartTime;
  final String? localEndTime;
  final StudioReservationStatus status;
  final bool completed;
  final bool approvalRequired;
  final int? hourlyPriceMinor;
  final int? totalPriceMinor;
  final String? currency;
  final int version;
}

class StudioOccupancy {
  const StudioOccupancy({
    required this.id,
    required this.roomId,
    required this.type,
    required this.startsAt,
    required this.endsAt,
    required this.active,
    required this.version,
    this.reservationId,
    this.clientRequestId,
    this.localDate,
    this.localStartTime,
    this.localEndTime,
  });

  final String id;
  final String roomId;
  final String? reservationId;
  final String? clientRequestId;
  final StudioOccupancyType type;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? localDate;
  final String? localStartTime;
  final String? localEndTime;
  final bool active;
  final int version;
}

class StudioUnavailableInterval {
  const StudioUnavailableInterval({
    required this.startsAt,
    required this.endsAt,
    this.localDate,
    this.localStartTime,
    this.localEndTime,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final String? localDate;
  final String? localStartTime;
  final String? localEndTime;
}

class StudioRoomAvailability {
  const StudioRoomAvailability({
    required this.studioProfileId,
    required this.roomId,
    required this.zoneId,
    required this.openingHour,
    required this.closingHour,
    required this.todayLocalDate,
    required this.currentLocalTime,
    required this.latestBookableLocalDateTime,
    required this.from,
    required this.to,
    required this.unavailable,
  });

  final String studioProfileId;
  final String roomId;
  final String zoneId;
  final int openingHour;
  final int closingHour;
  final DateTime todayLocalDate;
  final String currentLocalTime;
  final DateTime latestBookableLocalDateTime;
  final DateTime from;
  final DateTime to;
  final List<StudioUnavailableInterval> unavailable;
}

class StudioRoomSchedule {
  const StudioRoomSchedule({
    required this.room,
    required this.zoneId,
    required this.todayLocalDate,
    required this.currentLocalTime,
    required this.latestBookableLocalDateTime,
    required this.from,
    required this.to,
    required this.reservations,
    required this.occupancies,
  });

  final StudioRoom room;
  final String zoneId;
  final DateTime todayLocalDate;
  final String currentLocalTime;
  final DateTime latestBookableLocalDateTime;
  final DateTime from;
  final DateTime to;
  final StudioPage<StudioReservation> reservations;
  final List<StudioOccupancy> occupancies;
}
