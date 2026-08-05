enum StudioRoomAvailabilityStatus {
  available,
  partiallyAvailable,
  fullyBooked;

  static StudioRoomAvailabilityStatus fromApi(Object? value) {
    return switch (value?.toString().trim().toUpperCase()) {
      'AVAILABLE' => StudioRoomAvailabilityStatus.available,
      'FULLY_BOOKED' => StudioRoomAvailabilityStatus.fullyBooked,
      'PARTIALLY_AVAILABLE' => StudioRoomAvailabilityStatus.partiallyAvailable,
      final unknown => throw FormatException(
        'Unknown room availability status: $unknown',
      ),
    };
  }
}

class StudioRoomPhoto {
  const StudioRoomPhoto({
    required this.url,
    required this.orderIndex,
    this.mediaAssetId,
  });

  final String? mediaAssetId;
  final String url;
  final int orderIndex;
}

class StudioRoom {
  const StudioRoom({
    required this.id,
    required this.studioProfileId,
    required this.slotIndex,
    required this.name,
    required this.shortDescription,
    required this.capacity,
    required this.hourlyPriceMinor,
    required this.currency,
    required this.reservationApprovalRequired,
    required this.features,
    required this.photos,
    required this.todayLocalDate,
    required this.todayReservationCount,
    required this.todayOccupiedHours,
    required this.todayAvailableHours,
    required this.todayAvailabilityStatus,
    required this.version,
    this.clientRequestId,
    this.minimumCapacity,
    this.pendingReservationApprovalRequired,
    this.reservationApprovalPolicyEffectiveAt,
  });

  final String id;
  final String studioProfileId;
  final String? clientRequestId;
  final int slotIndex;
  final String name;
  final String shortDescription;
  final int capacity;
  final int? minimumCapacity;
  final int? hourlyPriceMinor;
  final String? currency;
  final bool reservationApprovalRequired;
  final bool? pendingReservationApprovalRequired;
  final DateTime? reservationApprovalPolicyEffectiveAt;
  final List<String> features;
  final List<StudioRoomPhoto> photos;
  final DateTime todayLocalDate;
  final int todayReservationCount;
  final int todayOccupiedHours;
  final int todayAvailableHours;
  final StudioRoomAvailabilityStatus todayAvailabilityStatus;
  final int version;
}

class StudioRoomDraft {
  const StudioRoomDraft({
    required this.name,
    required this.shortDescription,
    required this.capacity,
    required this.hourlyPriceMinor,
    required this.currency,
    required this.reservationApprovalRequired,
    required this.features,
    required this.photoMediaIds,
    this.minimumCapacity,
  });

  final String name;
  final String? shortDescription;
  final int capacity;
  final int? minimumCapacity;
  final int? hourlyPriceMinor;
  final String? currency;
  final bool reservationApprovalRequired;
  final List<String> features;
  final List<String> photoMediaIds;
}
