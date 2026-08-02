enum StudioEquipmentAvailabilityBucket {
  available('AVAILABLE'),
  busy('BUSY'),
  maintenance('MAINTENANCE');

  const StudioEquipmentAvailabilityBucket(this.apiValue);

  final String apiValue;
}

enum StudioEquipmentAvailabilityStatus {
  available,
  partiallyAvailable,
  busy,
  maintenance,
  mixedUnavailable,
  unknown,
}

class StudioEquipmentPhoto {
  final String? mediaAssetId;
  final String url;
  final int position;

  const StudioEquipmentPhoto({
    required this.mediaAssetId,
    required this.url,
    required this.position,
  });
}

class StudioEquipmentAvailabilityDay {
  final DateTime date;
  final int totalQuantity;
  final int availableQuantity;
  final int busyQuantity;
  final int maintenanceQuantity;
  final StudioEquipmentAvailabilityStatus status;

  const StudioEquipmentAvailabilityDay({
    required this.date,
    required this.totalQuantity,
    required this.availableQuantity,
    required this.busyQuantity,
    required this.maintenanceQuantity,
    required this.status,
  });

  int quantityIn(StudioEquipmentAvailabilityBucket bucket) => switch (bucket) {
    StudioEquipmentAvailabilityBucket.available => availableQuantity,
    StudioEquipmentAvailabilityBucket.busy => busyQuantity,
    StudioEquipmentAvailabilityBucket.maintenance => maintenanceQuantity,
  };
}

class StudioEquipment {
  final String id;
  final String categoryId;
  final String categoryCode;
  final String categoryName;
  final String subcategoryId;
  final String subcategoryCode;
  final String subcategoryName;
  final String categoryIconKey;
  final String name;
  final String? brand;
  final String? model;
  final String? description;
  final int totalQuantity;
  final List<String> features;
  final List<StudioEquipmentPhoto> photos;
  final StudioEquipmentAvailabilityDay todayAvailability;
  final int? version;

  const StudioEquipment({
    required this.id,
    required this.categoryId,
    required this.categoryCode,
    required this.categoryName,
    required this.subcategoryId,
    required this.subcategoryCode,
    required this.subcategoryName,
    required this.categoryIconKey,
    required this.name,
    required this.brand,
    required this.model,
    required this.description,
    required this.totalQuantity,
    required this.features,
    required this.photos,
    required this.todayAvailability,
    required this.version,
  });

  bool get isOwnerView => version != null;
}

class StudioEquipmentAvailabilityRange {
  final String equipmentId;
  final DateTime startDate;
  final DateTime endDate;
  final List<StudioEquipmentAvailabilityDay> days;

  const StudioEquipmentAvailabilityRange({
    required this.equipmentId,
    required this.startDate,
    required this.endDate,
    required this.days,
  });
}

class StudioEquipmentAvailabilityCommandResult {
  final String commandId;
  final String clientRequestId;
  final String equipmentId;
  final DateTime startDate;
  final DateTime endDate;
  final StudioEquipmentAvailabilityBucket sourceBucket;
  final StudioEquipmentAvailabilityBucket targetBucket;
  final int quantity;
  final DateTime appliedAt;
  final bool replayed;

  const StudioEquipmentAvailabilityCommandResult({
    required this.commandId,
    required this.clientRequestId,
    required this.equipmentId,
    required this.startDate,
    required this.endDate,
    required this.sourceBucket,
    required this.targetBucket,
    required this.quantity,
    required this.appliedAt,
    required this.replayed,
  });
}

class CreateStudioEquipmentCommand {
  final String clientRequestId;
  final String leafCategoryId;
  final String name;
  final String? brand;
  final String? model;
  final String? description;
  final int totalQuantity;
  final List<String> features;
  final List<String> photoMediaIds;

  const CreateStudioEquipmentCommand({
    required this.clientRequestId,
    required this.leafCategoryId,
    required this.name,
    required this.brand,
    required this.model,
    required this.description,
    required this.totalQuantity,
    required this.features,
    required this.photoMediaIds,
  });
}

class UpdateStudioEquipmentCommand {
  final int expectedVersion;
  final String leafCategoryId;
  final String name;
  final String? brand;
  final String? model;
  final String? description;
  final int totalQuantity;
  final List<String> features;
  final List<String> photoMediaIds;

  const UpdateStudioEquipmentCommand({
    required this.expectedVersion,
    required this.leafCategoryId,
    required this.name,
    required this.brand,
    required this.model,
    required this.description,
    required this.totalQuantity,
    required this.features,
    required this.photoMediaIds,
  });
}

class MoveStudioEquipmentAvailabilityCommand {
  final String clientRequestId;
  final DateTime startDate;
  final DateTime endDate;
  final StudioEquipmentAvailabilityBucket sourceBucket;
  final StudioEquipmentAvailabilityBucket targetBucket;
  final int quantity;

  const MoveStudioEquipmentAvailabilityCommand({
    required this.clientRequestId,
    required this.startDate,
    required this.endDate,
    required this.sourceBucket,
    required this.targetBucket,
    required this.quantity,
  });
}
