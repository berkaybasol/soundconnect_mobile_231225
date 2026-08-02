import '../../../core/error/result.dart';
import 'entities/studio_reservation.dart';
import 'entities/studio_page.dart';
import 'entities/studio_room.dart';

abstract class StudioRoomRepository {
  Future<Result<StudioPage<StudioRoom>>> listOwnerRooms({
    int page = 0,
    int size = 10,
  });

  Future<Result<StudioPage<StudioRoom>>> listPublicRooms(
    String studioProfileId, {
    int page = 0,
    int size = 10,
  });

  Future<Result<StudioRoom>> getOwnerRoom(String roomId);

  Future<Result<StudioRoom>> getPublicRoom(
    String studioProfileId,
    String roomId,
  );

  Future<Result<StudioRoom>> createRoom(
    StudioRoomDraft draft, {
    required String clientRequestId,
  });

  Future<Result<StudioRoom>> updateRoom(
    String roomId,
    StudioRoomDraft draft, {
    required int expectedVersion,
  });

  Future<Result<void>> archiveRoom(
    String roomId, {
    required int expectedVersion,
  });

  Future<Result<StudioRoomAvailability>> getPublicAvailability({
    required String studioProfileId,
    required String roomId,
    required DateTime from,
    required DateTime to,
  });

  Future<Result<StudioRoomSchedule>> getOwnerSchedule({
    required String roomId,
    required DateTime from,
    required DateTime to,
    int page = 0,
    int size = 100,
  });

  Future<Result<StudioReservation>> createReservation({
    required String roomId,
    required DateTime date,
    required int startHour,
    required int durationHours,
    required String contactPhone,
    required String clientRequestId,
  });

  Future<Result<StudioPage<StudioReservation>>>
  listCustomerReservationsForRoomDate({
    required String roomId,
    required DateTime date,
    int page = 0,
    int size = 100,
  });

  Future<Result<StudioReservation>> approveReservation({
    required String roomId,
    required String reservationId,
    required int expectedVersion,
  });

  Future<Result<StudioReservation>> rejectReservation({
    required String roomId,
    required String reservationId,
    required int expectedVersion,
  });

  Future<Result<StudioReservation>> cancelOwnerReservation({
    required String roomId,
    required String reservationId,
    required int expectedVersion,
  });

  Future<Result<StudioReservation>> cancelCustomerReservation({
    required String reservationId,
    required int expectedVersion,
  });

  Future<Result<StudioOccupancy>> createManualBlock({
    required String roomId,
    required DateTime date,
    required int startHour,
    required int durationHours,
    required String clientRequestId,
  });

  Future<Result<StudioOccupancy>> releaseManualBlock({
    required String roomId,
    required String blockId,
    required int expectedVersion,
    String? reason,
  });
}
