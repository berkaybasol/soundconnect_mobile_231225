import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/venue_event_detail.dart';
import '../domain/entities/venue_event_item.dart';
import '../domain/venue_event_repository.dart';

class VenueEventRepositoryImpl implements VenueEventRepository {
  final ApiClient _apiClient;

  VenueEventRepositoryImpl(this._apiClient);

  @override
  Future<Result<List<VenueOwnerEventItem>>> listByVenue(String venueId) async {
    try {
      final response = await _apiClient.get<List<VenueOwnerEventItem>>(
        '/api/v1/venue-owner/events/venue/$venueId',
        decoder: (json) {
          final list = json is List ? json : const [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(VenueOwnerEventItem.fromJson)
              .toList();
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'venue_events_list_unknown',
        message: 'Etkinlikler alinamadi',
      ));
    }
  }

  @override
  Future<Result<void>> create({
    required String venueId,
    required VenueEventDraft draft,
  }) async {
    try {
      await _apiClient.post<Object?>(
        '/api/v1/venue-owner/events',
        body: {
          'title': draft.title,
          'description': draft.description.isEmpty ? null : draft.description,
          'eventDate': formatVenueApiDate(draft.eventDate),
          'startTime': formatVenueApiTime(draft.startTime),
          'endTime': draft.endTime == null
              ? null
              : formatVenueApiTime(draft.endTime!),
          'posterImage': draft.posterImage,
          'venueId': venueId,
          'musicianProfileId': draft.musicianProfileId,
          'bandId': null,
          'manualPerformerName': draft.manualPerformerName,
        },
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'venue_event_create_unknown',
        message: 'Etkinlik eklenemedi',
      ));
    }
  }

  @override
  Future<Result<void>> delete(String eventId) async {
    try {
      await _apiClient.delete<Object?>(
        '/api/v1/venue-owner/events/$eventId',
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'venue_event_delete_unknown',
        message: 'Etkinlik silinemedi',
      ));
    }
  }

  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) async {
    try {
      final response = await _apiClient.get<VenueEventDetail>(
        '/api/v1/events/$eventId',
        decoder: (json) {
          final map =
              (json as Map<Object?, Object?>?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
          return VenueEventDetail(
            id: eventId,
            shareUrl: map['shareUrl']?.toString(),
            posterImage: map['posterImage']?.toString(),
            performerName: map['performerName']?.toString(),
            musicianProfileId: map['musicianProfileId']?.toString(),
          );
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'venue_event_detail_unknown',
        message: 'Etkinlik detayi alinamadi',
      ));
    }
  }
}
