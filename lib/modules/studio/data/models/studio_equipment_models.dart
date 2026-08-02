import '../../domain/entities/studio_equipment.dart';
import 'studio_json.dart';

StudioEquipment studioEquipmentFromJson(Object? value) {
  final json = studioJsonObject(value, 'equipment');
  final photos =
      studioJsonList(json['photos'], 'equipment.photos')
          .map((item) {
            final photo = studioJsonObject(item, 'equipment.photo');
            return StudioEquipmentPhoto(
              mediaAssetId: studioJsonNullableString(photo, 'mediaAssetId'),
              url: studioJsonString(photo, 'url'),
              position: studioJsonInt(photo, 'position'),
            );
          })
          .toList(growable: false)
        ..sort((left, right) => left.position.compareTo(right.position));
  final features = studioJsonList(json['features'], 'equipment.features')
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
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
    totalQuantity: studioJsonInt(json, 'totalQuantity'),
    features: features,
    photos: photos,
    todayAvailability: studioEquipmentAvailabilityDayFromJson(
      json['todayAvailability'],
    ),
    version: json['version'] == null ? null : studioJsonInt(json, 'version'),
  );
}

StudioEquipmentAvailabilityDay studioEquipmentAvailabilityDayFromJson(
  Object? value,
) {
  final json = studioJsonObject(value, 'equipment availability day');
  return StudioEquipmentAvailabilityDay(
    date: studioJsonDate(json, 'date'),
    totalQuantity: studioJsonInt(json, 'totalQuantity'),
    availableQuantity: studioJsonInt(json, 'availableQuantity'),
    busyQuantity: studioJsonInt(json, 'busyQuantity'),
    maintenanceQuantity: studioJsonInt(json, 'maintenanceQuantity'),
    status: _availabilityStatus(studioJsonString(json, 'status')),
  );
}

StudioEquipmentAvailabilityRange studioEquipmentAvailabilityRangeFromJson(
  Object? value,
) {
  final json = studioJsonObject(value, 'equipment availability range');
  return StudioEquipmentAvailabilityRange(
    equipmentId: studioJsonString(json, 'equipmentId'),
    startDate: studioJsonDate(json, 'startDate'),
    endDate: studioJsonDate(json, 'endDate'),
    days: studioJsonList(
      json['days'],
      'equipment availability range.days',
    ).map(studioEquipmentAvailabilityDayFromJson).toList(growable: false),
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
    appliedAt: studioJsonDateTime(json, 'appliedAt'),
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
      _ => StudioEquipmentAvailabilityStatus.unknown,
    };
