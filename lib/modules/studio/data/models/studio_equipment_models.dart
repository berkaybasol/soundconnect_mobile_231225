import '../../domain/entities/studio_equipment.dart';
import '../../domain/studio_civil_date.dart';
import 'studio_json.dart';

StudioEquipmentInventorySummary studioEquipmentInventorySummaryFromJson(
  Object? value,
) {
  final json = studioJsonObject(value, 'equipment inventory summary');
  final total = studioJsonInt(json, 'totalQuantity');
  final available = studioJsonInt(json, 'availableQuantity');
  final busy = studioJsonInt(json, 'busyQuantity');
  final maintenance = studioJsonInt(json, 'maintenanceQuantity');
  if (total < 0 ||
      available < 0 ||
      busy < 0 ||
      maintenance < 0 ||
      available + busy + maintenance != total) {
    throw const FormatException('equipment inventory summary is invalid');
  }
  return StudioEquipmentInventorySummary(
    totalQuantity: total,
    availableQuantity: available,
    busyQuantity: busy,
    maintenanceQuantity: maintenance,
  );
}

StudioEquipment studioEquipmentFromJson(Object? value) {
  final json = studioJsonObject(value, 'equipment');
  final photos =
      studioJsonList(json['photos'], 'equipment.photos')
          .map((item) {
            final photo = studioJsonObject(item, 'equipment.photo');
            return StudioEquipmentPhoto(
              mediaAssetId: studioJsonNullableString(photo, 'mediaAssetId'),
              url: studioJsonHttpUrl(photo, 'url'),
              position: studioJsonInt(photo, 'position'),
            );
          })
          .toList(growable: false)
        ..sort((left, right) => left.position.compareTo(right.position));
  final features = studioJsonList(json['features'], 'equipment.features')
      .map((item) {
        if (item is! String || item.trim().isEmpty) {
          throw const FormatException(
            'equipment.features must contain only non-blank strings',
          );
        }
        return item.trim();
      })
      .toList(growable: false);
  final totalQuantity = studioJsonInt(json, 'totalQuantity');
  final todayAvailability = studioEquipmentAvailabilityDayFromJson(
    json['todayAvailability'],
  );
  if (totalQuantity < 1 || todayAvailability.totalQuantity != totalQuantity) {
    throw const FormatException(
      'equipment quantity and today availability disagree',
    );
  }
  return StudioEquipment(
    id: studioJsonString(json, 'id'),
    categoryId: studioJsonString(json, 'categoryId'),
    categoryCode: studioJsonString(json, 'categoryCode'),
    categoryName: studioJsonString(json, 'categoryName'),
    subcategoryId: studioJsonString(json, 'subcategoryId'),
    subcategoryCode: studioJsonString(json, 'subcategoryCode'),
    subcategoryName: studioJsonString(json, 'subcategoryName'),
    categoryIconKey: studioJsonNullableString(json, 'categoryIconKey') ?? '',
    name: studioJsonString(json, 'name'),
    brand: studioJsonNullableString(json, 'brand'),
    model: studioJsonNullableString(json, 'model'),
    description: studioJsonNullableString(json, 'description'),
    totalQuantity: totalQuantity,
    features: features,
    photos: photos,
    todayAvailability: todayAvailability,
    version: json['version'] == null ? null : studioJsonInt(json, 'version'),
  );
}

StudioEquipmentAvailabilityDay studioEquipmentAvailabilityDayFromJson(
  Object? value,
) {
  final json = studioJsonObject(value, 'equipment availability day');
  final totalQuantity = studioJsonInt(json, 'totalQuantity');
  final availableQuantity = studioJsonInt(json, 'availableQuantity');
  final busyQuantity = studioJsonInt(json, 'busyQuantity');
  final maintenanceQuantity = studioJsonInt(json, 'maintenanceQuantity');
  if (totalQuantity < 1 ||
      availableQuantity < 0 ||
      busyQuantity < 0 ||
      maintenanceQuantity < 0 ||
      availableQuantity + busyQuantity + maintenanceQuantity != totalQuantity) {
    throw const FormatException('equipment availability counts are invalid');
  }
  return StudioEquipmentAvailabilityDay(
    date: studioJsonDate(json, 'date'),
    totalQuantity: totalQuantity,
    availableQuantity: availableQuantity,
    busyQuantity: busyQuantity,
    maintenanceQuantity: maintenanceQuantity,
    status: _availabilityStatus(studioJsonString(json, 'status')),
  );
}

StudioEquipmentAvailabilityRange studioEquipmentAvailabilityRangeFromJson(
  Object? value,
) {
  final json = studioJsonObject(value, 'equipment availability range');
  final startDate = studioJsonDate(json, 'startDate');
  final endDate = studioJsonDate(json, 'endDate');
  final days = studioJsonList(
    json['days'],
    'equipment availability range.days',
  ).map(studioEquipmentAvailabilityDayFromJson).toList(growable: false);
  final inclusiveDays = studioCivilRangeLength(startDate, endDate);
  if (inclusiveDays < 1 ||
      inclusiveDays > 730 ||
      days.length != inclusiveDays) {
    throw const FormatException('equipment availability range is invalid');
  }
  for (var index = 0; index < days.length; index++) {
    if (days[index].date != studioAddCivilDays(startDate, index)) {
      throw const FormatException(
        'equipment availability days must be contiguous and ordered',
      );
    }
  }
  return StudioEquipmentAvailabilityRange(
    equipmentId: studioJsonString(json, 'equipmentId'),
    startDate: startDate,
    endDate: endDate,
    days: days,
  );
}

StudioEquipmentAvailabilityCommandResult
studioEquipmentAvailabilityCommandResultFromJson(Object? value) {
  final json = studioJsonObject(value, 'equipment availability command');
  return StudioEquipmentAvailabilityCommandResult(
    commandId: studioJsonString(json, 'commandId'),
    clientRequestId: studioJsonString(json, 'clientRequestId'),
    equipmentId: studioJsonString(json, 'equipmentId'),
    startDate: studioJsonDate(json, 'startDate'),
    endDate: studioJsonDate(json, 'endDate'),
    sourceBucket: _availabilityBucket(studioJsonString(json, 'sourceBucket')),
    targetBucket: _availabilityBucket(studioJsonString(json, 'targetBucket')),
    quantity: studioJsonInt(json, 'quantity'),
    appliedAt: studioJsonInstant(json, 'appliedAt'),
    replayed: studioJsonBool(json, 'replayed'),
  );
}

StudioEquipmentAvailabilityBucket _availabilityBucket(String value) =>
    switch (value) {
      'AVAILABLE' => StudioEquipmentAvailabilityBucket.available,
      'BUSY' => StudioEquipmentAvailabilityBucket.busy,
      'MAINTENANCE' => StudioEquipmentAvailabilityBucket.maintenance,
      _ => throw FormatException('Unknown availability bucket: $value'),
    };

StudioEquipmentAvailabilityStatus _availabilityStatus(String value) =>
    switch (value) {
      'AVAILABLE' => StudioEquipmentAvailabilityStatus.available,
      'PARTIALLY_AVAILABLE' =>
        StudioEquipmentAvailabilityStatus.partiallyAvailable,
      'BUSY' => StudioEquipmentAvailabilityStatus.busy,
      'MAINTENANCE' => StudioEquipmentAvailabilityStatus.maintenance,
      'MIXED_UNAVAILABLE' => StudioEquipmentAvailabilityStatus.mixedUnavailable,
      _ => throw FormatException('Unknown availability status: $value'),
    };
