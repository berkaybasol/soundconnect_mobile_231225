import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/discovery_event.dart';
import '../domain/entities/discovery_event_page.dart';
import '../domain/event_discovery_date_policy.dart';
import '../domain/event_discovery_search_repository.dart';
import 'models/discovery_event_model.dart';

class EventDiscoverySearchRepositoryImpl
    implements EventDiscoverySearchRepository {
  EventDiscoverySearchRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<DiscoveryEventPage>> search({
    required DateTime date,
    required String cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async {
    final city = cityId.trim();
    final district = _nonBlank(districtId);
    final neighborhood = _nonBlank(neighborhoodId);
    if (city.isEmpty ||
        (neighborhood != null && district == null) ||
        page < 0 ||
        page > 1000 ||
        size < 1 ||
        size > 50 ||
        date.year < 1 ||
        date.year > 9999) {
      return const Result.failure(
        AppError(
          code: 'event_discovery_invalid_query',
          message: 'Arama bilgilerini kontrol edip yeniden dene.',
        ),
      );
    }
    final requestedDate = EventDiscoveryDatePolicy.apiDate(date);
    try {
      final response = await _apiClient.get<DiscoveryEventPage>(
        '/api/v1/events/discovery',
        query: <String, dynamic>{
          'date': requestedDate,
          'cityId': city,
          if (district != null) 'districtId': district,
          if (neighborhood != null) 'neighborhoodId': neighborhood,
          'page': page,
          'size': size,
        },
        decoder: (json) => _decodePage(
          json,
          requestedDate: requestedDate,
          requestedPage: page,
          requestedSize: size,
        ),
      );
      return Result.success(response);
    } on ApiException catch (error) {
      if (error.error.code == 'network') {
        return Result.failure(
          AppError(
            code: error.error.code,
            message:
                'Etkinlikler yüklenemedi. '
                'İnternet bağlantını kontrol edip yeniden dene.',
            details: error.error.details,
          ),
        );
      }
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'event_discovery_malformed_response',
          message: 'Etkinlik bilgileri alınamadı. Lütfen yeniden dene.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'event_discovery_failed',
          message: 'Etkinlikler yüklenemedi. Lütfen yeniden dene.',
        ),
      );
    }
  }

  static String? _nonBlank(String? raw) {
    final value = raw?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static DiscoveryEventPage _decodePage(
    Object? raw, {
    required String requestedDate,
    required int requestedPage,
    required int requestedSize,
  }) {
    if (raw is! Map<String, dynamic>) _malformed();
    final content = raw['content'];
    final number = raw['number'];
    final size = raw['size'];
    final totalElements = raw['totalElements'];
    final totalPages = raw['totalPages'];
    final last = raw['last'];
    if (content is! List ||
        number is! int ||
        number != requestedPage ||
        size is! int ||
        size != requestedSize ||
        totalElements is! int ||
        totalElements < 0 ||
        totalPages is! int ||
        totalPages != (totalElements / size).ceil() ||
        last is! bool ||
        last != (number + 1 >= totalPages) ||
        content.length != (totalElements - number * size).clamp(0, size)) {
      _malformed();
    }
    final ids = <String>{};
    final events = <DiscoveryEvent>[];
    for (final item in content) {
      if (item is! Map<String, dynamic>) _malformed();
      for (final key in const ['id', 'title', 'venueId', 'venueName']) {
        if (item[key] is! String || (item[key] as String).trim().isEmpty) {
          _malformed();
        }
      }
      if (!ids.add((item['id'] as String).trim())) _malformed();
      if (item['eventDate'] != requestedDate) _malformed();
      for (final key in const [
        'performerName',
        'performerType',
        'musicianProfileId',
        'bandId',
        'performerImageUrl',
        'performerProfileImage',
        'performerProfilePicture',
        'musicianProfilePicture',
        'artistProfilePicture',
        'venueImageUrl',
        'venueProfilePicture',
        'venueProfileImage',
        'venueProfilePictureUrl',
        'venueCity',
        'venueDistrict',
        'venueNeighborhood',
        'posterImage',
        'posterImageUrl',
        'imageUrl',
        'description',
      ]) {
        if (item[key] != null && item[key] is! String) _malformed();
      }
      final members = item['bandMembers'];
      if (members != null &&
          (members is! List || members.any((member) => member is! String))) {
        _malformed();
      }
      _validateTime(item['startTime'], required: true);
      _validateTime(item['endTime']);
      events.add(DiscoveryEventModel.fromJson(item));
    }
    return DiscoveryEventPage(
      content: List<DiscoveryEvent>.unmodifiable(events),
      number: number,
      size: size,
      totalElements: totalElements,
      totalPages: totalPages,
      last: last,
    );
  }

  static void _validateTime(Object? raw, {bool required = false}) {
    if (raw == null && !required) return;
    if (raw is! String ||
        !RegExp(
          r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,9})?)?$',
        ).hasMatch(raw)) {
      _malformed();
    }
  }

  static Never _malformed() =>
      throw const FormatException('Invalid event discovery response');
}
