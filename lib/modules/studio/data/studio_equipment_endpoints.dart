class StudioEquipmentEndpoints {
  const StudioEquipmentEndpoints._();

  static const ownerEquipment = '/api/v1/user/studio-profiles/me/equipment';

  static String ownerEquipmentItem(String equipmentId) =>
      '$ownerEquipment/$equipmentId';

  static String ownerAvailability(String equipmentId) =>
      '${ownerEquipmentItem(equipmentId)}/availability';

  static String ownerAvailabilityCommands(String equipmentId) =>
      '${ownerAvailability(equipmentId)}/commands';

  static String publicEquipment(String studioProfileId) =>
      '/api/v1/public/studio-profiles/$studioProfileId/equipment';

  static String publicEquipmentItem(
    String studioProfileId,
    String equipmentId,
  ) => '${publicEquipment(studioProfileId)}/$equipmentId';

  static String publicAvailability(
    String studioProfileId,
    String equipmentId,
  ) => '${publicEquipmentItem(studioProfileId, equipmentId)}/availability';
}
