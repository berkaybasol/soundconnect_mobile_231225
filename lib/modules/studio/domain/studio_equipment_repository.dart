import '../../../core/error/result.dart';
import 'entities/studio_equipment.dart';
import 'entities/studio_page.dart';

abstract class StudioEquipmentRepository {
  Future<Result<StudioPage<StudioEquipment>>> listOwnerEquipment({
    String? query,
    String? categoryId,
    StudioEquipmentAvailabilityBucket? availabilityBucket,
    required int page,
    required int size,
  });

  Future<Result<StudioPage<StudioEquipment>>> listPublicEquipment({
    required String studioProfileId,
    String? query,
    String? categoryId,
    StudioEquipmentAvailabilityBucket? availabilityBucket,
    required int page,
    required int size,
  });

  Future<Result<StudioEquipment>> getOwnerEquipment(String equipmentId);

  Future<Result<StudioEquipment>> getPublicEquipment({
    required String studioProfileId,
    required String equipmentId,
  });

  Future<Result<StudioEquipment>> createEquipment(
    CreateStudioEquipmentCommand command,
  );

  Future<Result<StudioEquipment>> updateEquipment({
    required String equipmentId,
    required UpdateStudioEquipmentCommand command,
  });

  Future<Result<void>> archiveEquipment({
    required String equipmentId,
    required int expectedVersion,
  });

  Future<Result<StudioEquipmentAvailabilityRange>> getOwnerAvailability({
    required String equipmentId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<Result<StudioEquipmentAvailabilityRange>> getPublicAvailability({
    required String studioProfileId,
    required String equipmentId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<Result<StudioEquipmentAvailabilityCommandResult>> moveAvailability({
    required String equipmentId,
    required MoveStudioEquipmentAvailabilityCommand command,
  });
}
